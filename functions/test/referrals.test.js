"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { createReferralService, NEW_ACCOUNT_WINDOW } = require("../src/referrals");
const { createEconomyService } = require("../src/economy");

function setup() {
  const db = new MemoryFirestore();
  const at = Date.UTC(2026, 9, 25, 12);
  const ages = new Map([["inviter", 30 * 86400000]]);
  let serial = 0;
  const service = createReferralService({ db, now: () => at,
    lookupAccount: async uid => ({ createdAtMillis: at - (ages.get(uid) || 0), disabled: uid === "disabled" }),
    makeCode: () => `CL-${(++serial).toString(16).toUpperCase().padStart(12, "0")}` });
  function user(uid, wallet = {}) { db.seed(`users/${uid}`, { username: uid, coins: 100, gems: 2, ...wallet }); }
  user("inviter");
  const install = uid => `installation_id_for_${uid}`;
  const call = (uid, input = {}) => service.execute(uid, { installId: install(uid), ...input });
  const state = uid => call(uid, { action: "state" });
  const accept = (uid, code, extra = {}) => call(uid, { action: "accept", code, ...extra });
  return { db, ages, user, service, call, state, accept, install, at };
}

test("codes are stable, unpredictable server-owned values and old accounts can invite", async () => {
  const x = setup();
  const first = await x.state("inviter");
  assert.match(first.state.code, /^CL-[A-F0-9]{12}$/);
  assert.equal((await x.state("inviter")).state.code, first.state.code);
  assert.equal(first.state.canAccept, false);
  assert.deepEqual(first.state.inviterReward, { coins: 1000, gems: 10 });
  assert.deepEqual(first.state.inviteeReward, { coins: 500, gems: 5 });
  assert.deepEqual(first.currency, { coins: 100, gems: 2 });
});

test("acceptance credits both actual wallets and advances separate protected revisions", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  const accepted = await x.accept("friend", code.toLowerCase(), { grants: { coins: 9999999, gems: 9999999 } });
  assert.equal(accepted.newlyAccepted, true);
  assert.deepEqual(accepted.grants, { coins: 500, gems: 5 });
  assert.deepEqual(accepted.currency, { coins: 600, gems: 7 });
  assert.equal(accepted.referralRevision, 1);
  assert.equal(accepted.state.acceptedCode, code);
  assert.equal(accepted.state.canAccept, false);
  const inviter = await x.state("inviter");
  assert.deepEqual(inviter.currency, { coins: 1100, gems: 12 });
  assert.equal(inviter.referralRevision, 1);
  assert.equal(inviter.state.qualifiedCount, 1);
  assert.equal(inviter.state.totalCoins, 1000);
  assert.equal(inviter.state.recent[0].name, "friend");
  assert.equal(x.db.read("users/inviter").username, "inviter");
});

test("concurrent acceptance, retry and new operation IDs deliver only once", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  const results = await Promise.all([x.accept("friend", code), x.accept("friend", code)]);
  assert.equal(results.filter(result => result.newlyAccepted).length, 1);
  x.db.seed("users/friend", { ...x.db.read("users/friend"), coins: 25, gems: 1 });
  const retry = await x.accept("friend", code, { operationId: "different" });
  assert.equal(retry.newlyAccepted, false);
  assert.deepEqual(retry.grants, { coins: 0, gems: 0 });
  assert.deepEqual(retry.currency, { coins: 25, gems: 1 });
  assert.equal((await x.state("inviter")).state.qualifiedCount, 1);
});

test("each milestone credits once even for simultaneous friends", async () => {
  const x = setup();
  const code = (await x.state("inviter")).state.code;
  await Promise.all(Array.from({ length: 10 }, (_, i) => {
    const uid = `friend_${i}`; x.user(uid); return x.accept(uid, code);
  }));
  const inviter = await x.state("inviter");
  assert.equal(inviter.state.qualifiedCount, 10);
  assert.equal(inviter.state.totalCoins, 10000 + 1000 + 2500 + 5000);
  assert.equal(inviter.state.totalGems, 100 + 10 + 25 + 50);
  assert.equal(inviter.currency.coins, 18600);
  assert.equal(inviter.currency.gems, 187);
  assert.deepEqual(inviter.state.milestones.map(item => item.claimed), [true, true, true]);
  await x.accept("friend_9", code);
  assert.equal((await x.state("inviter")).currency.coins, 18600);
  assert.equal(inviter.referralRevision, 10);
});

test("self invitation, unknown and malformed codes never grant", async () => {
  const x = setup(); x.user("friend");
  const self = (await x.state("friend")).state.code;
  await assert.rejects(x.accept("friend", self), { code: "invalid-argument" });
  await assert.rejects(x.accept("friend", "CL-ABCDEFABCDEF"), { code: "not-found" });
  await assert.rejects(x.accept("friend", "../../users/other"), { code: "invalid-argument" });
  assert.equal(x.db.read("users/friend").coins, 100);
});

test("Firebase Auth age controls eligibility and client dates cannot make an old account new", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  x.ages.set("friend", NEW_ACCOUNT_WINDOW + 1);
  assert.equal((await x.state("friend")).state.canAccept, false);
  await assert.rejects(x.accept("friend", code, { createdAtMillis: x.at, installedAtMillis: x.at }), { code: "failed-precondition" });
  x.ages.set("friend", NEW_ACCOUNT_WINDOW);
  assert.equal((await x.accept("friend", code)).newlyAccepted, true);
});

test("a device already seen for another account cannot qualify after account switching or reinstall", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  const state = await x.call("friend", { action: "state", installId: x.install("inviter") });
  assert.equal(state.state.canAccept, false);
  await assert.rejects(x.accept("friend", code, { installId: x.install("inviter") }), { code: "already-exists" });
  await x.accept("friend", code);
  x.user("replacement");
  await assert.rejects(x.accept("replacement", code, { installId: x.install("friend") }), { code: "already-exists" });
  assert.equal((await x.state("inviter")).state.qualifiedCount, 1);
});

test("acceptance remains locked to its original inviter", async () => {
  const x = setup(); x.user("friend"); x.user("other_inviter");
  const original = (await x.state("inviter")).state.code;
  const other = (await x.state("other_inviter")).state.code;
  await x.accept("friend", original);
  await assert.rejects(x.accept("friend", other), { code: "already-exists" });
  assert.equal((await x.state("other_inviter")).state.qualifiedCount, 0);
});

test("code allocation recovers a collision without transferring a code", async () => {
  const x = setup(); x.user("friend");
  x.db.seed("referral_codes/CL-000000000001", { uid: "someone_else" });
  const first = await x.state("inviter");
  assert.equal(first.state.code, "CL-000000000002");
  assert.equal(x.db.read("referral_codes/CL-000000000001").uid, "someone_else");
});

test("missing installation or profile, disabled account and cross-account request fail", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  await assert.rejects(x.service.execute("friend", { action: "accept", code }), { code: "failed-precondition" });
  await assert.rejects(x.accept("uninitialized", code), { code: "failed-precondition" });
  await assert.rejects(x.state("disabled"), { code: "unauthenticated" });
  await assert.rejects(x.accept("friend", code, { expectedUid: "other" }), { code: "permission-denied" });
  await assert.rejects(x.call("friend", { action: "claim", grants: { coins: 50000 } }), { code: "invalid-argument" });
  assert.equal((await x.state("inviter")).state.qualifiedCount, 0);
});

test("credits keep both wallets within signed integer range and report only real credited amounts", async () => {
  const x = setup(); x.user("inviter", { coins: 2147483646, gems: 2147483646 });
  x.user("friend", { coins: 2147483646, gems: 2147483646 });
  const code = (await x.state("inviter")).state.code;
  const accepted = await x.accept("friend", code);
  assert.deepEqual(accepted.currency, { coins: 2147483647, gems: 2147483647 });
  assert.deepEqual(accepted.grants, { coins: 1, gems: 1 });
  assert.equal((await x.state("inviter")).state.totalCoins, 1);
});

test("economy currency responses and old receipt replays report the current referral revision", async () => {
  const x = setup(); x.user("friend");
  const code = (await x.state("inviter")).state.code;
  const economy = createEconomyService({ db: x.db, now: () => x.at, randomInt: () => 2 });
  const before = await economy.execute("inviter", { action: "spinWheel", operationId: "spin_before_referral" });
  assert.equal(before.referralRevision, 0);
  await x.accept("friend", code);
  const replay = await economy.execute("inviter", { action: "spinWheel", operationId: "spin_before_referral" });
  assert.equal(replay.referralRevision, 1);
  assert.equal(replay.currency.coins, 1600);
  assert.equal((await economy.execute("inviter", { action: "state" })).referralRevision, 1);
});
