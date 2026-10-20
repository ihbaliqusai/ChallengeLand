"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { createFriendStakesService } = require("../src/friend_stakes");
const { fresh, normalize } = require("../src/economy");

const bank = ["جغرافيا", "حيوانات", "أفلام عربية"].flatMap(category => Array.from({ length: 12 }, (_, i) => ({
  category, text: `${category}: سؤال أصلي ${i}`, level: [0, 2, 3, 1, 4, 6][i % 6],
  answers: ["لندن", "باريس", "دمشق", "بيروت"], img: i === 0 ? "https://example.test/original.jpg" : "",
})));

function setup() {
  const db = new MemoryFirestore();
  let at = 1800000000000, serial = 0;
  const service = createFriendStakesService({ db, now: () => at, draw: () => 0, questionBank: bank });
  for (const uid of ["a", "b", "c"]) {
    db.seed(`users/${uid}`, { coins: 3000, gems: 20 });
    db.seed(`player_presence/${uid}`, { state: "available", heartbeatAt: at });
  }
  const call = (uid, input) => service.execute(uid, input.action === "sync" ? input : { operationId: `op_${++serial}`, ...input });
  const invite = () => call("a", { action: "invite", peerUid: "b", stakeCoins: 100, gameplayVersion: 2 });
  const accept = async () => {
    const invitation = await invite();
    return (await call("b", { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: 100, gameplayVersion: 2 })).matchId;
  };
  const pick = (uid, matchId, category) => call(uid, { action: "pickCategory", matchId, category });
  const start = async (matchId, a = "جغرافيا", b = "حيوانات") => { await pick("a", matchId, a); return pick("b", matchId, b); };
  const sync = (uid, matchId) => call(uid, { action: "sync", matchId });
  const advance = ms => { at += ms; };
  const begin = async (matchId, turn, col, row) => {
    const uid = turn % 2 === 0 ? "a" : "b";
    const claim = await call(uid, { action: "claim", matchId, turn, col, row });
    const begun = await call(uid, { action: "beginAnswer", matchId, turn });
    return { uid, claim, begun, question: db.read(`friend_stake_matches/${matchId}`).cells[`${col}_${row}`].question };
  };
  return { db, service, call, invite, accept, pick, start, sync, advance, begin, now: () => at };
}

test("new invites require original-game consent on both clients before any escrow, with no automatic category selection", async () => {
  const x = setup();
  await assert.rejects(x.call("a", { action: "invite", peerUid: "b", stakeCoins: 100 }), { code: "failed-precondition" });
  const invitation = await x.invite();
  assert.equal(x.db.read("social_challenges/a:b").gameplayVersion, 2);
  await assert.rejects(x.call("b", { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: 100 }), { code: "failed-precondition" });
  assert.equal(x.db.read("users/a").coins, 3000);
  const accepted = await x.call("b", { action: "respond", challengeId: invitation.challengeId, status: "accepted", expectedAmount: 100, gameplayVersion: 2 });
  assert.equal(accepted.match.protocolVersion, 2);
  assert.equal(accepted.match.rows, 6);
  assert.equal(accepted.match.phase, "category_select");
  assert.deepEqual(accepted.match.categories, []);
  assert.deepEqual(accepted.match.cells, {});
  assert.equal(x.db.read("users/a").coins, 2900);
  assert.equal(x.db.read("economy_accounts/a"), undefined);
});

test("each friend picks their original category, twelve distinct cells preserve non-range tiers even for a shared category", async () => {
  const x = setup(), matchId = await x.accept();
  await x.pick("a", matchId, "جغرافيا");
  const first = await x.sync("a", matchId);
  assert.equal(first.match.status, "waiting");
  assert.equal(first.match.picks.a.category, "جغرافيا");
  await assert.rejects(x.pick("a", matchId, "حيوانات"), { code: "already-exists" });
  const result = await x.pick("b", matchId, "جغرافيا");
  assert.equal(result.match.status, "active");
  assert.deepEqual(result.match.categories, ["جغرافيا", "جغرافيا"]);
  assert.equal(result.match.deadlineAtMillis - x.now(), 30000);
  const state = x.db.read(`friend_stake_matches/${matchId}`);
  assert.equal(Object.keys(state.cells).length, 12);
  assert.equal(new Set(Object.values(state.cells).map(c => c.question.id)).size, 12);
  for (const [key, cell] of Object.entries(state.cells)) {
    const row = Number(key.split("_")[1]);
    assert.equal(cell.points, [200, 400, 600][row % 3]);
    assert.ok([[0, 1], [2, 4, 5], [3, 6, 7, 8]][row % 3].includes(Number(cell.question.level)));
  }
  assert.equal(x.db.read("economy_accounts/a").dailyKeys, 3);
  assert.equal(x.db.read("economy_accounts/b").dailyKeys, 3);
});

test("premium category entry respects original ticket, owned, rental, VIP and ad rights and only charges its picker", async () => {
  for (const access of ["ticket", "owned", "rented", "vip", "ad", "none"]) {
    const x = setup(), account = fresh(x.now());
    account.tickets = access === "ticket" ? 1 : 0;
    if (access === "owned") account.owned = ["أفلام عربية"];
    if (access === "rented") account.rentals[normalize("أفلام عربية")] = x.now() + 60000;
    if (access === "ad") account.adPermits[normalize("أفلام عربية")] = 1;
    if (access === "vip") x.db.seed("commerce_accounts/a/entitlements/current", { isVip: true, expiresAtMillis: x.now() + 60000 });
    x.db.seed("economy_accounts/a", account);
    const matchId = await x.accept();
    const result = x.pick("a", matchId, "أفلام عربية");
    if (access === "none") { await assert.rejects(result, { code: "resource-exhausted" }); continue; }
    await result;
    await x.pick("b", matchId, "حيوانات");
    const a = x.db.read("economy_accounts/a"), b = x.db.read("economy_accounts/b");
    assert.equal(a.tickets, 0);
    assert.equal(b.tickets, 3);
    assert.equal(a.dailyKeys, 3);
    assert.equal(b.dailyKeys, 3);
    if (access === "ad") assert.equal(a.adPermits[normalize("أفلام عربية")], undefined);
    await x.pick("a", matchId, "أفلام عربية");
    assert.equal(x.db.read("economy_accounts/a").tickets, 0);
  }
});

test("typed answers are graded on the server, current answers stay hidden, and the native question/media transport is intact", async () => {
  const x = setup(), matchId = await x.accept();
  await x.start(matchId);
  const { claim, begun, question } = await x.begin(matchId, 0, 0, 0);
  assert.equal(claim.match.phase, "observing");
  assert.equal(begun.match.phase, "answering");
  assert.equal(begun.match.deadlineAtMillis - x.now(), 45000);
  assert.equal(begun.question.text, question.text);
  assert.equal(begun.question.img, question.img);
  assert.equal(begun.question.options, undefined);
  assert.equal(begun.question.rightAnswer, undefined);
  assert.equal(begun.match.turns.t0.question.options, undefined);
  assert.deepEqual((await x.sync("b", matchId)).question, begun.question);
  await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, optionIndex: question.correctOption }), { code: "failed-precondition" });
  await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, answerText: "باريس", correct: true }), { code: "invalid-argument" });
  const result = await x.call("a", { action: "answer", matchId, turn: 0, answerText: "لُندن" });
  assert.equal(result.match.scores.a, 200);
  assert.equal(result.match.turns.t0.correct, true);
  assert.equal(result.match.turns.t0.question.rightAnswer, "لندن");
  assert.equal(result.match.turns.t0.question.correctOptionIndex, question.correctOption);
  assert.equal(result.match.turns.t0.answerSignature, undefined);
  assert.equal(result.match.turns.t0.answerText, undefined);
  await x.call("a", { action: "answer", matchId, turn: 0, answerText: "لُندن" });
  await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, answerText: "باريس" }), { code: "already-exists" });
});

test("option reveal halves points, removing two choices quarters them, and neither can be bypassed by a typed submission", async () => {
  for (const count of [1, 2]) {
    const x = setup(), matchId = await x.accept();
    await x.start(matchId);
    const { question } = await x.begin(matchId, 0, 0, 2);
    const deadline = (await x.sync("a", matchId)).match.deadlineAtMillis;
    let result = await x.call("a", { action: "reveal", matchId, turn: 0, count: 1 });
    assert.equal(result.question.options.length, 4);
    assert.equal(result.question.rightAnswer, undefined);
    if (count === 2) {
      result = await x.call("a", { action: "reveal", matchId, turn: 0, count: 2 });
      assert.equal(result.question.hiddenIndices.length, 2);
      assert.equal(result.question.hiddenIndices.includes(question.correctOption), false);
      await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, optionIndex: result.question.hiddenIndices[0] }), { code: "invalid-argument" });
    }
    assert.equal(result.match.deadlineAtMillis, deadline);
    await assert.rejects(x.call("a", { action: "answer", matchId, turn: 0, answerText: "لندن" }), { code: "failed-precondition" });
    result = await x.call("a", { action: "answer", matchId, turn: 0, optionIndex: question.correctOption });
    assert.equal(result.match.turns.t0.points, 600 / (2 ** count));
  }
});

test("native selection timeout automatically picks a cell; answer timer starts after observation and rejects late correctness", async () => {
  const x = setup(), matchId = await x.accept();
  await x.start(matchId);
  x.advance(30000);
  let result = await x.sync("a", matchId);
  assert.equal(result.match.currentTurn, 0);
  assert.equal(result.match.phase, "observing");
  assert.ok(result.question);
  x.advance(10000);
  result = await x.call("a", { action: "beginAnswer", matchId, turn: 0 });
  assert.equal(result.match.deadlineAtMillis, x.now() + 45000);
  x.advance(45000);
  result = await x.call("a", { action: "answer", matchId, turn: 0, answerText: "لندن" });
  assert.equal(result.match.turns.t0.skipped, true);
  assert.equal(result.match.scores.a, 0);
  assert.equal(result.match.currentTurn, 1);
  await assert.rejects(x.call("b", { action: "claim", matchId, turn: 1, col: 1, row: 0 }), { code: "failed-precondition" });
  x.advance(5000);
  const next = await x.begin(matchId, 1, 1, 0);
  assert.equal(next.begun.match.phase, "answering");
});

async function play(x, matchId, both = false) {
  let result;
  for (let turn = 0; turn < 12; turn++) {
    const { uid } = await x.begin(matchId, turn, turn % 2, Math.floor(turn / 2));
    result = await x.call(uid, { action: "answer", matchId, turn, answerText: uid === "a" || both ? "لندن" : "باريس" });
    if (turn < 11) x.advance(5000);
  }
  return result;
}

test("all twelve original turns determine the winner and settle the entire pot once; a draw returns both contributions", async () => {
  for (const draw of [false, true]) {
    const x = setup(), matchId = await x.accept();
    await x.start(matchId);
    const result = await play(x, matchId, draw);
    assert.equal(result.match.currentTurn, 12);
    assert.equal(result.match.status, "settled");
    assert.equal(result.match.turns.t11.done, true);
    assert.equal(result.match.scores.a, 2400);
    assert.equal(result.match.scores.b, draw ? 2400 : 0);
    assert.equal(result.match.settlement.status, draw ? "refunded" : "paid");
    await Promise.all([x.sync("a", matchId), x.sync("b", matchId), x.service.recoverExpired()]);
    await x.call("a", { action: "forfeit", matchId });
    assert.equal(x.db.read("users/a").coins, draw ? 3000 : 3100);
    assert.equal(x.db.read("users/b").coins, draw ? 3000 : 2900);
  }
});

test("pre-start cancellation and system recovery return held coins and category tickets; started withdrawal awards the opponent", async () => {
  for (const ending of ["cancelled", "missing", "expired", "forfeit"]) {
    const x = setup(), matchId = await x.accept();
    await x.pick("a", matchId, "أفلام عربية");
    assert.equal(x.db.read("economy_accounts/a").tickets, 2);
    if (ending === "forfeit") await x.pick("b", matchId, "حيوانات");
    if (ending === "missing") x.db.documents.delete(`friend_stake_matches/${matchId}`);
    if (ending === "expired") x.advance(120000);
    const result = ending === "cancelled" || ending === "forfeit"
      ? await x.call("a", { action: "forfeit", matchId }) : await x.sync("a", matchId);
    assert.equal(result.match.settlement.status, ending === "forfeit" ? "paid" : "refunded");
    assert.equal(x.db.read("users/a").coins, ending === "forfeit" ? 2900 : 3000);
    assert.equal(x.db.read("users/b").coins, ending === "forfeit" ? 3100 : 3000);
    assert.equal(x.db.read("economy_accounts/a").tickets, ending === "forfeit" ? 2 : 3);
    await x.service.recoverExpired();
    await x.sync("a", matchId);
    assert.equal(x.db.read("economy_accounts/a").tickets, ending === "forfeit" ? 2 : 3);
  }
});

test("damaged original state and altered protocol headers recover from independent financial receipts", async () => {
  for (const damage of [m => { m.turns.t0 = null; }, m => { m.protocolVersion = 1; }, m => { m.cells["0_0"] = null; }]) {
    const x = setup(), matchId = await x.accept();
    await x.start(matchId, "أفلام عربية", "حيوانات");
    await x.begin(matchId, 0, 0, 0);
    const m = x.db.read(`friend_stake_matches/${matchId}`);
    damage(m);
    x.db.seed(`friend_stake_matches/${matchId}`, m);
    const result = await x.sync("a", matchId);
    assert.equal(result.match.finishReason, "system_error");
    assert.equal(x.db.read("users/a").coins, 3000);
    assert.equal(x.db.read("economy_accounts/a").tickets, 3);
  }
});
