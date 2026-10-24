"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createDuelNotifications, validateInvite } = require("../src/duel_notifications");
const { MemoryFirestore } = require("./memory-firestore");
class PushFirestore extends MemoryFirestore {
  doc(path) {
    return { path, get: async () => this.snapshot(path),
      set: async (data, options) => this.seed(path, options?.merge ? { ...this.read(path), ...data } : data),
      delete: async () => this.documents.delete(path) };
  }
  collection(path) { return { ...super.collection(path), doc: id => this.doc(`${path}/${id}`) }; }
  snapshot(path) { return { ...super.snapshot(path), ref: this.doc(path) }; }
}
const clock = 1800000000000;
const uid = "sender-account-1234";
const data = { targetId: "recipient-account", searchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" };
const pending = () => ({ ...data, userId: uid, status: "waiting", createdAt: clock });
function harness() {
  const db = new PushFirestore(), sent = [], requests = new Map([[uid, pending()]]);
  let failures = [];
  const realtime = { ref: path => ({ get: async () => ({ val: () => path.startsWith("DuelRequestsV2/")
    ? requests.get(path.slice("DuelRequestsV2/".length)) : { Name: "صديقك" } }) }) };
  const messaging = { sendEachForMulticast: async message => {
    sent.push(message);
    return { successCount: message.tokens.length - failures.length,
      responses: message.tokens.map((token, index) => failures[index]
        ? { success: false, error: { code: failures[index] } } : { success: true }) };
  } };
  const service = createDuelNotifications({ db, realtime, messaging, now: () => clock });
  return { db, sent, requests, service, fail: codes => { failures = codes; } };
}
test("rejects spoofed, self, expired, accepted and cancelled invitations", () => {
  assert.throws(() => validateInvite(uid, { ...data, targetId: uid }, pending(), clock), { code: "invalid-argument" });
  for (const override of [{ userId: "other" }, { searchId: "old-search" }, { status: "matched" },
    { status: "cancelled" }, { createdAt: clock - 120001 }, { targetId: "other" }]) {
    assert.throws(() => validateInvite(uid, data, { ...pending(), ...override }, clock), { code: "failed-precondition" });
  }
});
test("notifies only recipient devices and carries the correct friend code and expiry", async () => {
  const h = harness();
  await h.service.register(data.targetId, { token: "recipient-device-token-1", enabled: true });
  await h.service.register("other-user", { token: "other-user-device-token", enabled: true });
  assert.equal((await h.service.send(uid, data)).status, "sent");
  assert.deepEqual(h.sent[0].tokens, ["recipient-device-token-1"]);
  assert.equal(h.sent[0].data.friendCode, "SENDERACCO");
  assert.equal(h.sent[0].data.recipientUid, data.targetId);
  assert.equal(h.sent[0].data.expiresAt, String(clock + 120000));
});
test("concurrent polling requests produce a single push", async () => {
  const h = harness();
  await h.service.register(data.targetId, { token: "recipient-device-token-1", enabled: true });
  await Promise.all(Array.from({ length: 8 }, () => h.service.send(uid, data)));
  assert.equal(h.sent.length, 1);
});
test("disabled devices receive no notifications", async () => {
  const h = harness();
  await h.service.register(data.targetId, { token: "recipient-device-token-1", enabled: false });
  assert.equal((await h.service.send(uid, data)).status, "no_devices");
  assert.equal(h.sent.length, 0);
});
test("switching accounts moves the token instead of leaking the prior account's invitations", async () => {
  const h = harness();
  const token = "recipient-device-token-1";
  await h.service.register(data.targetId, { token, enabled: true });
  await h.service.register("new-account", { token, enabled: true });
  assert.equal((await h.service.send(uid, data)).status, "no_devices");
});
test("dead tokens are removed after delivery", async () => {
  const h = harness();
  await h.service.register(data.targetId, { token: "recipient-device-token-1", enabled: true });
  h.fail(["messaging/registration-token-not-registered"]);
  await h.service.send(uid, data);
  assert.equal((await h.db.collection("duel_push_devices").get()).size, 0);
});
test("temporary FCM failure permits retry without creating a new invitation", async () => {
  const h = harness();
  await h.service.register(data.targetId, { token: "recipient-device-token-1", enabled: true });
  h.fail(["messaging/server-unavailable"]);
  await assert.rejects(h.service.send(uid, data), { code: "unavailable" });
  h.fail([]);
  assert.equal((await h.service.send(uid, data)).status, "sent");
});
test("rate limit blocks bursts of new searches but permits deduplicated polling", async () => {
  const h = harness();
  for (let index = 0; index < 5; index++) {
    const invite = { ...data, searchId: `search-number-${index}-abcdefgh` };
    h.requests.set(uid, { ...pending(), searchId: invite.searchId });
    await h.service.send(uid, invite);
  }
  const invite = { ...data, searchId: "search-number-6-abcdefgh" };
  h.requests.set(uid, { ...pending(), searchId: invite.searchId });
  await assert.rejects(h.service.send(uid, invite), { code: "resource-exhausted" });
});
