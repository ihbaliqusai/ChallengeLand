"use strict";
const { createHash } = require("node:crypto");

const hash = value => createHash("sha256").update(value).digest("hex");
const uidValid = uid => typeof uid === "string" && /^[A-Za-z0-9_-]{4,128}$/.test(uid);
class InviteError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

function validateInvite(uid, data, request, now) {
  if (!uidValid(data?.targetId) || data.targetId === uid || typeof data.searchId !== "string"
      || !/^[A-Za-z0-9-]{16,128}$/.test(data.searchId)) {
    throw new InviteError("invalid-argument", "Invalid invite.");
  }
  if (!request || request.userId !== uid || request.status !== "waiting"
      || request.targetId !== data.targetId || request.searchId !== data.searchId
      || !Number.isFinite(request.createdAt) || now - request.createdAt >= 120000) {
    throw new InviteError("failed-precondition", "The invitation is no longer pending.");
  }
}

function createDuelNotifications({ db, realtime, messaging, now = Date.now }) {
  async function register(uid, data) {
    if (typeof data?.token !== "string" || data.token.length < 20 || data.token.length > 4096
        || typeof data.enabled !== "boolean") throw new InviteError("invalid-argument", "Invalid device.");
    // Token documents are server-only; re-registration moves a device to its current account.
    await db.collection("duel_push_devices").doc(hash(data.token)).set({
      uid, token: data.token, enabled: data.enabled, updatedAt: now(),
    });
    return { registered: true };
  }

  async function send(uid, data) {
    const request = (await realtime.ref(`DuelRequestsV2/${uid}`).get()).val();
    validateInvite(uid, data, request, now());
    const inviteId = hash(`${uid}|${data.searchId}|${data.targetId}`);
    const delivery = db.collection("duel_push_deliveries").doc(inviteId);
    const rate = db.collection("duel_push_rates").doc(uid);
    const claimed = await db.runTransaction(async tx => {
      const [existing, limit] = await Promise.all([tx.get(delivery), tx.get(rate)]);
      const previous = existing.data();
      if (previous?.finished || previous?.claimedAt > now() - 30000) return false;
      const old = limit.data();
      const count = old?.windowAt > now() - 60000 ? old.count : 0;
      if (!existing.exists && count >= 5) throw new InviteError("resource-exhausted", "Please wait before sending another invitation.");
      tx.set(delivery, { claimedAt: now(), finished: false });
      if (!existing.exists) tx.set(rate, { count: count + 1, windowAt: count ? old.windowAt : now() });
      return true;
    });
    if (!claimed) return { status: "already_processed" };
    try {
      // Recheck after claiming to avoid sending an invitation already accepted or cancelled.
      const live = (await realtime.ref(`DuelRequestsV2/${uid}`).get()).val();
      try { validateInvite(uid, data, live, now()); } catch (error) {
        if (!(error instanceof InviteError)) throw error;
        await delivery.set({ finished: true, status: "expired" }, { merge: true });
        return { status: "expired" };
      }
      const devices = await db.collection("duel_push_devices").where("uid", "==", data.targetId).get();
      const active = devices.docs.filter(doc => doc.data().enabled && doc.data().updatedAt > now() - 90 * 86400000);
      const profile = (await realtime.ref(`Users/Registered/${uid}`).get()).val() || {};
      const senderName = String(profile.Name || profile.name || "لاعب").replace(/[\r\n]/g, " ").slice(0, 60);
      let sent = 0;
      for (let index = 0; index < active.length; index += 500) {
        const batch = active.slice(index, index + 500);
        const response = await messaging.sendEachForMulticast({
          tokens: batch.map(doc => doc.data().token),
          data: { type: "duel_invite", inviteId, recipientUid: data.targetId, senderName,
            friendCode: uid.replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 10),
            expiresAt: String(Math.min(now() + 120000, live.createdAt + 120000)) },
          android: { priority: "high", ttl: 120000, collapseKey: inviteId },
        });
        sent += response.successCount;
        let temporaryFailure = false;
        await Promise.all(response.responses.map(async (result, i) => {
          if (result.success) return;
          if (["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(result.error?.code)) {
            await batch[i].ref.delete();
          } else temporaryFailure = true;
        }));
        if (temporaryFailure) throw new InviteError("unavailable", "Notification delivery temporarily unavailable.");
      }
      await delivery.set({ finished: true, status: sent ? "sent" : "no_devices", sent }, { merge: true });
      return { status: sent ? "sent" : "no_devices" };
    } catch (error) {
      await delivery.set({ claimedAt: 0 }, { merge: true });
      throw error;
    }
  }
  return { register, send };
}
module.exports = { createDuelNotifications, validateInvite, InviteError };
