"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { createFriendStakesService, AMOUNTS } = require("../src/friend_stakes");
const { createEconomyService } = require("../src/economy");

const bank = ["جغرافيا", "حيوانات"].flatMap(category => [0, 4, 3].map(level => ({
  category, text: `${category} ${level}`, level, answers: ["صحيح", "خطأ 1", "خطأ 2", "خطأ 3"],
})));

function setup(initialCoins = 3000) {
  const db = new MemoryFirestore();
  let at = 1800000000000;
  let serial = 0;
  // Production rejects new legacy invitations. This fixture preserves coverage
  // for the protocol that was already deployed and may still have held coins.
  const service = createFriendStakesService({ db, now: () => at, draw: () => 0, questionBank: bank, legacyInvitesEnabled: true });
  for (const uid of ["a", "b", "c"]) {
    db.seed(`users/${uid}`, { coins: initialCoins, gems: 20 });
    db.seed(`player_presence/${uid}`, { state: "available", heartbeatAt: at });
  }
  const call = (uid, input) => service.execute(uid, input.action === "sync" ? input : { operationId: `op_${++serial}`, ...input });
  const invite = (amount = 50, owner = "a", peer = "b") => call(owner, { action: "invite", peerUid: peer, stakeCoins: amount });
  const accept = async (amount = 50) => {
    const invitation = await invite(amount);
    const accepted = await call("b", { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: amount });
    return accepted.matchId;
  };
  const start = async matchId => {
    await call("a", { action: "start", matchId });
    await call("b", { action: "start", matchId });
  };
  const sync = (uid, matchId) => call(uid, { action: "sync", matchId });
  return { db, service, call, invite, accept, start, sync, advance: ms => { at += ms; }, now: () => at };
}

async function play(x, matchId, correct = uid => uid === "a") {
  const cells = ["0_0", "1_0", "0_1", "1_1", "0_2", "1_2"];
  let result;
  for (let turn = 0; turn < 6; turn++) {
    const uid = turn % 2 === 0 ? "a" : "b";
    const [col, row] = cells[turn].split("_").map(Number);
    const claimed = await x.call(uid, { action: "claim", matchId, turn, col, row });
    assert.ok(claimed.question);
    const q = x.db.read(`friend_stake_matches/${matchId}`).cells[cells[turn]].question;
    result = await x.call(uid, { action: "answer", matchId, turn, optionIndex: correct(uid) ? q.correctOption : (q.correctOption + 1) % 4 });
  }
  return result;
}

test("all seven tiers atomically hold both contributions, never consume a key, and preserve invitation consent", async () => {
  assert.deepEqual(AMOUNTS, [50, 100, 250, 500, 1000, 2500, 5000]);
  for (const amount of AMOUNTS) {
    const x = setup(20000);
    const matchId = await x.accept(amount);
    assert.equal(x.db.read("users/a").coins, 20000 - amount);
    assert.equal(x.db.read("users/b").coins, 20000 - amount);
    assert.equal(x.db.read("users/a").friendStakeRevision, 1);
    assert.equal(x.db.read("users/a").friendStakeMatchId, matchId);
    assert.equal(x.db.read("economy_accounts/a"), undefined);
    const challenge = x.db.read("social_challenges/a:b");
    assert.equal(challenge.stakeCoins, amount);
    assert.equal(challenge.prizeCoins, amount * 2);
    assert.deepEqual(x.db.read("social_reservations/a").acceptedAt, challenge.acceptedAt);
    assert.deepEqual(x.db.read("social_reservations/b").acceptedAt, challenge.acceptedAt);
    assert.equal(x.db.read(`friend_stake_views/${matchId}`).status, "waiting");
  }
});

test("concurrent accepts and response retries debit once, and operation IDs are payload-bound", async () => {
  const x = setup();
  const { challengeId } = await x.invite(100);
  const input = { action: "respond", challengeId, status: "accepted", expectedAmount: 100, operationId: "same_accept" };
  const results = await Promise.all([x.call("b", input), x.call("b", input), x.call("b", input)]);
  assert.equal(new Set(results.map(r => r.matchId)).size, 1);
  assert.equal(x.db.read("users/a").coins, 2900);
  assert.equal(x.db.read("users/b").coins, 2900);
  await assert.rejects(x.call("b", { ...input, status: "declined" }), { code: "already-exists" });
  await assert.rejects(x.call("b", { ...input, operationId: "different_accept" }), { code: "failed-precondition" });
  assert.equal(x.db.read("users/b").friendStakeRevision, 1);
});

test("insufficient funds and changed amount consent never create partial escrow", async () => {
  const x = setup();
  const invitation = await x.invite(1000);
  const input = { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: 1000 };
  await assert.rejects(x.call("b", { ...input, expectedAmount: 50 }), { code: "failed-precondition" });
  x.db.seed("users/b", { coins: 999, gems: 20 });
  await assert.rejects(x.call("b", input), { code: "resource-exhausted" });
  assert.equal(x.db.read("users/a").coins, 3000);
  assert.equal(x.db.read("users/b").coins, 999);
  assert.equal(x.db.read(`friend_stake_matches/${invitation.matchId}`), undefined);
  assert.equal(x.db.read("social_challenges/a:b").status, "pending");
  assert.equal(x.db.read("friend_stake_locks/a"), undefined);
});

test("a competing challenge cannot reserve either player twice", async () => {
  const x = setup();
  const first = await x.invite(50);
  const second = await x.invite(50, "c", "b");
  const result = await Promise.allSettled([
    x.call("b", { action: "respond", challengeId: first.challengeId, status: "accepted", expectedAmount: 50 }),
    x.call("b", { action: "respond", challengeId: second.challengeId, status: "accepted", expectedAmount: 50 }),
  ]);
  assert.equal(result.filter(r => r.status === "fulfilled").length, 1);
  assert.equal(result.filter(r => r.status === "rejected" && r.reason.code === "failed-precondition").length, 1);
  assert.equal(x.db.read("users/b").coins, 2950);
  assert.equal(x.db.read("users/a").coins + x.db.read("users/c").coins, 5950);
});

test("foreign players, invalid tiers, caller scores, caller refunds, stale turns and foreign claims are rejected", async () => {
  const x = setup();
  await assert.rejects(x.invite(25), { code: "invalid-argument" });
  await assert.rejects(x.call("a", { action: "invite", peerUid: "a", stakeCoins: 50 }), { code: "invalid-argument" });
  const matchId = await x.accept();
  await x.start(matchId);
  for (const input of [
    { action: "refund", matchId },
    { action: "answer", matchId, turn: 0, optionIndex: 0, correct: true },
    { action: "sync", matchId, winnerId: "a", points: 100000 },
  ]) await assert.rejects(x.call("a", input), { code: "invalid-argument" });
  await assert.rejects(x.sync("c", matchId), { code: "permission-denied" });
  await assert.rejects(x.call("c", { action: "forfeit", matchId }), { code: "permission-denied" });
  await assert.rejects(x.call("b", { action: "claim", matchId, turn: 0, col: 0, row: 0 }), { code: "failed-precondition" });
  await assert.rejects(x.call("a", { action: "claim", matchId, turn: 1, col: 0, row: 0 }), { code: "failed-precondition" });
  await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, optionIndex: 0 }), { code: "failed-precondition" });
});

test("question answers stay private, only the picker can retrieve current options, and completed answers are immutable", async () => {
  const x = setup();
  const matchId = await x.accept();
  await x.start(matchId);
  const input = { action: "claim", matchId, turn: 0, col: 0, row: 0 };
  const claimed = await x.call("a", input);
  const again = await x.call("a", input);
  assert.deepEqual(again.question, claimed.question);
  assert.equal((await x.sync("b", matchId)).question, undefined);
  assert.deepEqual((await x.sync("a", matchId)).question, claimed.question);
  const visible = JSON.stringify(x.db.read(`friend_stake_views/${matchId}`));
  assert.equal(visible.includes("correctOption"), false);
  assert.equal(visible.includes("options"), false);
  assert.equal(visible.includes("صحيح"), false);
  const q = x.db.read(`friend_stake_matches/${matchId}`).cells["0_0"].question;
  const answer = { action: "answer", matchId, turn: 0, optionIndex: q.correctOption, operationId: "one_answer" };
  await Promise.all([x.call("a", answer), x.call("a", answer)]);
  await x.call("a", { ...answer, operationId: "another_id_same_answer" });
  const state = (await x.sync("a", matchId)).match;
  assert.equal(state.scores.a, 200);
  assert.equal(state.currentTurn, 1);
  assert.equal(JSON.stringify(state).includes("optionIndex"), false);
  await assert.rejects(x.call("a", { ...answer, optionIndex: (q.correctOption + 1) % 4, operationId: "changed_answer" }), { code: "already-exists" });
});

test("server-computed winner receives the full pot exactly once including sync and scheduled recovery retries", async () => {
  const x = setup();
  const matchId = await x.accept(250);
  await x.start(matchId);
  const result = await play(x, matchId);
  assert.equal(result.match.winnerId, "a");
  assert.equal(result.match.finishReason, "completed");
  assert.equal(result.match.settlement.payoutCoins, 500);
  assert.equal(x.db.read("users/a").coins, 3250);
  assert.equal(x.db.read("users/b").coins, 2750);
  assert.equal(x.db.read("users/a").friendStakeRevision, 2);
  assert.equal(x.db.read("users/a").friendStakeMatchId, "");
  assert.equal(x.db.read("friend_stake_locks/a").active, false);
  assert.equal(x.db.read("social_reservations/a").settled, true);
  await Promise.all([x.sync("a", matchId), x.sync("b", matchId), x.service.recoverExpired()]);
  await x.call("a", { action: "forfeit", matchId });
  assert.equal(x.db.read("users/a").coins, 3250);
  assert.equal(x.db.read("users/b").coins, 2750);
});

test("a tie returns each contribution, with no winner and no extra credit", async () => {
  const x = setup();
  const matchId = await x.accept(1000);
  await x.start(matchId);
  const result = await play(x, matchId, () => true);
  assert.equal(result.match.finishReason, "draw");
  assert.equal(result.match.winnerId, "");
  assert.equal(result.match.settlement.status, "refunded");
  assert.equal(result.match.settlement.refundCoins, 1000);
  assert.equal(x.db.read("users/a").coins, 3000);
  assert.equal(x.db.read("users/b").coins, 3000);
});

test("pre-start cancellation refunds, but a voluntary leave after both ready forfeits", async () => {
  for (const started of [false, true]) {
    const x = setup();
    const matchId = await x.accept(50);
    if (started) await x.start(matchId);
    else await x.call("a", { action: "start", matchId });
    const result = await x.call("a", { action: "forfeit", matchId });
    assert.equal(result.match.finishReason, started ? "forfeit" : "cancelled_before_start");
    assert.equal(x.db.read("users/a").coins, started ? 2950 : 3000);
    assert.equal(x.db.read("users/b").coins, started ? 3050 : 3000);
    assert.equal(result.currency.coins, started ? 2950 : 3000);
  }
});

test("server deadlines skip late answers without accepting late correctness, and continue the match", async () => {
  const x = setup();
  const matchId = await x.accept();
  await x.start(matchId);
  await x.call("a", { action: "claim", matchId, turn: 0, col: 0, row: 0 });
  const q = x.db.read(`friend_stake_matches/${matchId}`).cells["0_0"].question;
  x.advance(30000);
  const result = await x.call("a", { action: "answer", matchId, turn: 0, optionIndex: q.correctOption });
  assert.equal(result.match.turns.t0.skipped, true);
  assert.equal(result.match.scores.a, 0);
  assert.equal(result.match.currentTurn, 1);
  assert.equal(result.match.phase, "selecting");
  assert.equal(x.db.read("users/a").coins, 2950);
  x.advance(45000);
  await x.service.recoverExpired();
  assert.equal((await x.sync("a", matchId)).match.currentTurn, 2);
});

test("expiry before start, server hard expiry, and corrupt private state recover held coins exactly once", async () => {
  for (const reason of ["not_started", "system_expired", "system_error"]) {
    const x = setup();
    const matchId = await x.accept(500);
    if (reason !== "not_started") await x.start(matchId);
    if (reason === "system_error") {
      const m = x.db.read(`friend_stake_matches/${matchId}`);
      delete m.cells["0_0"];
      x.db.seed(`friend_stake_matches/${matchId}`, m);
    } else x.advance(reason === "not_started" ? 120000 : 15 * 60000);
    const result = await x.sync("a", matchId);
    assert.equal(result.match.finishReason, reason);
    assert.equal(result.match.settlement.status, "refunded");
    await x.service.recoverExpired();
    await x.sync("b", matchId);
    assert.equal(x.db.read("users/a").coins, 3000);
    assert.equal(x.db.read("users/b").coins, 3000);
    assert.equal(x.db.read("users/a").friendStakeRevision, 2);
  }
});

test("expired invites, social blocks and absent presence never hold coins", async () => {
  const x = setup();
  const invitation = await x.invite();
  x.advance(30000);
  await assert.rejects(x.call("b", { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: 50 }), { code: "failed-precondition" });
  x.db.seed("social_blocks/a:c", { ownerUid: "a", targetUid: "c" });
  await assert.rejects(x.invite(50, "a", "c"), { code: "permission-denied" });
  x.db.seed("player_presence/b", { state: "away", heartbeatAt: x.now() });
  await assert.rejects(x.invite(), { code: "failed-precondition" });
  assert.equal(x.db.read("users/a").coins, 3000);
  assert.equal(x.db.read("users/b").coins, 3000);
});

test("voluntary withdrawal at a turn deadline still forfeits the active match", async () => {
  const x = setup();
  const matchId = await x.accept(100);
  await x.start(matchId);
  x.advance(45000);
  const result = await x.call("a", { action: "forfeit", matchId });
  assert.equal(result.match.finishReason, "forfeit");
  assert.equal(result.match.winnerId, "b");
  assert.equal(x.db.read("users/a").coins, 2900);
  assert.equal(x.db.read("users/b").coins, 3100);
});

test("damaged gameplay maps or financial headers refund using the independent escrow receipt", async () => {
  const damages = [
    m => { delete m.turns; },
    m => { delete m.ready; },
    m => { m.phase = "bad_phase"; },
    m => { m.cells["0_0"] = null; },
    m => { m.deadlineAtMillis = "invalid"; },
    m => { m.stakeCoins = 1000000; },
    m => { m.members = ["c"]; m.ownerId = "c"; },
  ];
  for (const damage of damages) {
    const x = setup();
    const matchId = await x.accept(250);
    await x.start(matchId);
    const m = x.db.read(`friend_stake_matches/${matchId}`);
    damage(m);
    x.db.seed(`friend_stake_matches/${matchId}`, m);
    const result = await x.sync("a", matchId);
    assert.equal(result.match.finishReason, "system_error");
    assert.equal(result.match.settlement.refundCoins, 250);
    assert.equal(x.db.read("users/a").coins, 3000);
    assert.equal(x.db.read("users/b").coins, 3000);
    assert.equal(x.db.read("users/c").coins, 3000);
  }
});

test("a damaged settled game cannot replay its payout or change the escrow's winner", async () => {
  const x = setup();
  const matchId = await x.accept(100);
  await x.start(matchId);
  await play(x, matchId);
  const m = x.db.read(`friend_stake_matches/${matchId}`);
  delete m.settlement;
  m.winnerId = "b";
  m.status = "active";
  x.db.seed(`friend_stake_matches/${matchId}`, m);
  const result = await x.sync("b", matchId);
  assert.equal(result.match.winnerId, "a");
  assert.equal(result.match.settlement.payoutCoins, 200);
  assert.equal(x.db.read("users/a").coins, 3100);
  assert.equal(x.db.read("users/b").coins, 2900);
});

test("server spending concurrent with settlement preserves both the store debit and the full pot", async () => {
  const x = setup();
  const matchId = await x.accept(100);
  await x.start(matchId);
  const economy = createEconomyService({ db: x.db, now: x.now });
  await Promise.all([
    economy.execute("a", { action: "buy", operationId: "concurrent_store", offerId: "keys_1", currency: "coins" }),
    x.call("b", { action: "forfeit", matchId }),
  ]);
  assert.equal(x.db.read("users/a").coins, 2400);
  assert.equal(x.db.read("users/b").coins, 2900);
  assert.equal(x.db.read("economy_accounts/a").keys, 1);
});

test("admission reserves payout headroom and maximum supported balances are never truncated", async () => {
  for (const headroom of [0, 100]) {
    const x = setup();
    const coins = 2147483647 - headroom;
    x.db.seed("users/a", { coins, gems: 20 });
    const invite = await x.invite(100);
    const accept = x.call("b", { action: "respond", challengeId: invite.challengeId, status: "accepted", expectedAmount: 100 });
    if (!headroom) {
      await assert.rejects(accept, { code: "failed-precondition" });
      assert.equal(x.db.read("users/a").coins, coins);
      assert.equal(x.db.read("users/b").coins, 3000);
    } else {
      const { matchId } = await accept;
      await x.start(matchId);
      await x.call("b", { action: "forfeit", matchId });
      assert.equal(x.db.read("users/a").coins, 2147483647);
      assert.equal((await x.sync("a", matchId)).currency.coins, 2147483647);
    }
  }
});

test("scheduled recovery follows escrow when a private game disappears or its participant header is damaged", async () => {
  for (const missing of [false, true]) {
    const x = setup();
    const matchId = await x.accept(500);
    if (missing) x.db.documents.delete(`friend_stake_matches/${matchId}`);
    else {
      const m = x.db.read(`friend_stake_matches/${matchId}`);
      m.ownerId = "c";
      m.deadlineAtMillis = 0;
      x.db.seed(`friend_stake_matches/${matchId}`, m);
    }
    await x.service.recoverExpired();
    assert.equal(x.db.read("users/a").coins, 3000);
    assert.equal(x.db.read("users/b").coins, 3000);
    assert.equal(x.db.read(`friend_stake_escrows/${matchId}`).status, "settled");
  }
});
