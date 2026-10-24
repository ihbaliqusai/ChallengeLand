"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createSocialNotifications } = require("../src/social_notifications");
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
const pending = { fromUid: "alice", toUid: "bob", status: "pending", createdAt: clock, expiresAt: clock + 604800000 };
function harness(collection = "social_links") {
  const db = new PushFirestore(), messages = [];
  let fail = false;
  db.seed(`${collection}/alice:bob`, pending);
  db.seed("public_profiles/alice", { username: "أحمد" });
  db.seed("duel_push_devices/bob", { uid: "bob", token: "bob-device", enabled: true, updatedAt: clock });
  db.seed("duel_push_devices/alice", { uid: "alice", token: "alice-device", enabled: true, updatedAt: clock });
  const notify = createSocialNotifications({ db, now: () => clock,
    messaging: { sendEachForMulticast: async message => {
      if (fail) throw new Error("network");
      messages.push(message);
      return { successCount: message.tokens.length, responses: message.tokens.map(() => ({ success: true })) };
    } } });
  return { db, messages, notify, fail: value => { fail = value; } };
}
test("friend request push targets only recipient and retries cannot duplicate delivery", async () => {
  const h = harness();
  await h.notify("social_links", "alice:bob", undefined, pending);
  await h.notify("social_links", "alice:bob", undefined, pending);
  assert.equal(h.messages.length, 1);
  assert.deepEqual(h.messages[0].tokens, ["bob-device"]);
  assert.equal(h.messages[0].data.type, "friend_request");
  assert.equal(h.messages[0].data.senderName, "أحمد");
  assert.equal(h.messages[0].data.recipientUid, "bob");
});
test("accepted, expired, unchanged pending and blocked requests never notify", async () => {
  for (const scenario of ["accepted", "expired", "unchanged", "blocked"]) {
    const h = harness();
    if (scenario === "accepted") h.db.seed("social_links/alice:bob", { ...pending, status: "accepted" });
    if (scenario === "expired") h.db.seed("social_links/alice:bob", { ...pending, expiresAt: clock - 1 });
    if (scenario === "blocked") h.db.seed("social_blocks/bob:alice", { ownerUid: "bob" });
    await h.notify("social_links", "alice:bob", scenario === "unchanged" ? pending : undefined, pending);
    assert.equal(h.messages.length, 0, scenario);
  }
});
test("device preferences and signed-out or stale devices are respected", async () => {
  for (const changes of [{ enabled: false }, { uid: "carol" }, { updatedAt: clock - 91 * 86400000 }]) {
    const h = harness();
    h.db.seed("duel_push_devices/bob", { uid: "bob", token: "bob-device", enabled: true, updatedAt: clock, ...changes });
    await h.notify("social_links", "alice:bob", undefined, pending);
    assert.equal(h.messages.length, 0);
  }
});
test("temporary FCM failures remain retryable", async () => {
  const h = harness();
  h.fail(true);
  await assert.rejects(h.notify("social_links", "alice:bob", undefined, pending));
  h.fail(false);
  await h.notify("social_links", "alice:bob", undefined, pending);
  assert.equal(h.messages.length, 1);
});
test("online invitations notify without starting a match or accepting it", async () => {
  const h = harness("social_challenges");
  const invite = { ...pending, mode: "duel", expiresAt: clock + 30000 };
  h.db.seed("social_challenges/alice:bob", invite);
  await h.notify("social_challenges", "alice:bob", undefined, invite);
  assert.equal(h.messages[0].data.type, "social_invite");
  assert.equal(h.messages[0].android.ttl, 30000);
  assert.equal(h.db.read("social_challenges/alice:bob").status, "pending");
});
