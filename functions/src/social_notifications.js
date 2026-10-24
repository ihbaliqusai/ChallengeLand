"use strict";
const { createHash } = require("node:crypto");
const millis = stamp => typeof stamp?.toMillis === "function" ? stamp.toMillis() : Number(stamp);

// Invoked from trusted Firestore events, never from a caller-supplied recipient.
function createSocialNotifications({ db, messaging, now = Date.now }) {
  return async function notify(collection, id, before, after) {
    if (!["social_links", "social_challenges"].includes(collection) || after?.status !== "pending"
        || (before?.status === "pending" && millis(before.createdAt) === millis(after.createdAt))) return;
    const createdAt = millis(after.createdAt);
    if (!Number.isFinite(createdAt) || millis(after.expiresAt) <= now()) return;
    const live = (await db.collection(collection).doc(id).get()).data();
    if (live?.status !== "pending" || millis(live.createdAt) !== createdAt || millis(live.expiresAt) <= now()) return;
    const [a, b] = await Promise.all([
      db.collection("social_blocks").doc(`${live.fromUid}:${live.toUid}`).get(),
      db.collection("social_blocks").doc(`${live.toUid}:${live.fromUid}`).get(),
    ]);
    if (a.exists || b.exists) return;
    const inviteId = createHash("sha256").update(`${collection}|${id}|${createdAt}`).digest("hex");
    const delivery = db.collection("duel_push_deliveries").doc(inviteId);
    const claimed = await db.runTransaction(async tx => {
      const previous = (await tx.get(delivery)).data();
      if (previous?.finished) return false;
      if (previous?.claimedAt > now() - 30000) throw new Error("Notification delivery is already in progress");
      tx.set(delivery, { claimedAt: now(), finished: false });
      return true;
    });
    if (!claimed) return;
    try {
      const profile = (await db.collection("public_profiles").doc(live.fromUid).get()).data() || {};
      const devices = await db.collection("duel_push_devices").where("uid", "==", live.toUid).get();
      const active = devices.docs.filter(d => d.data().enabled && d.data().updatedAt > now() - 90 * 86400000);
      const senderName = String(profile.username || "لاعب").replace(/[\r\n]/g, " ").slice(0, 60);
      const challenge = collection === "social_challenges";
      let sent = 0;
      for (let start = 0; start < active.length; start += 500) {
        const batch = active.slice(start, start + 500);
        const ttl = Math.min(millis(live.expiresAt) - now(), challenge ? 30000 : 86400000);
        if (ttl <= 0) break;
        const result = await messaging.sendEachForMulticast({
          tokens: batch.map(d => d.data().token),
          data: { type: challenge ? "social_invite" : "friend_request", inviteId,
            recipientUid: live.toUid, senderName, expiresAt: String(millis(live.expiresAt)) },
          android: { priority: "high", ttl, collapseKey: inviteId },
        });
        sent += result.successCount;
        let retry = false;
        await Promise.all(result.responses.map(async (response, index) => {
          if (response.success) return;
          if (["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(response.error?.code)) {
            await batch[index].ref.delete();
          } else retry = true;
        }));
        if (retry) throw new Error("Notification delivery temporarily unavailable");
      }
      await delivery.set({ finished: true, sent }, { merge: true });
    } catch (error) {
      await delivery.set({ claimedAt: 0 }, { merge: true });
      throw error;
    }
  };
}
module.exports = { createSocialNotifications };
