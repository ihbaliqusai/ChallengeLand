"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { questionKey } = require("../src/question_identity");
const { createQuestionHistoryService, pathFor } = require("../src/question_history");
const { makeBoard } = require("../src/original_stake_board");

const q = (text, extra = {}) => ({ text, category: "جغرافيا", level: "0", answers: ["a", "b", "c", "d"], ...extra });
const bank = Array.from({ length: 300 }, (_, i) => q(`السؤال ${i}`, { level: String(i % 4) }));

test("canonical and deployed banks retain identical content identities including media and career paths", () => {
  const source = require("../../assets/questions.json");
  assert.equal(new Set(source.map(questionKey)).size, source.length);
  const visible = source.filter(item => !["دقة ملاحظة", "دقه ملاحظه"].includes(item.Category?.trim()));
  const server = require("../src/original_stake_questions.json");
  assert.deepEqual(new Set(visible.map(questionKey)), new Set(server.map(questionKey)));
});
function setup() {
  const db = new MemoryFirestore();
  db.seed("rooms/room", { players: { alice: {}, bob: {}, bot_1: {} }, hostId: "alice" });
  const realtime = { ref: path => ({ get: async () => ({ val: () => path === "Games/game"
    ? { alice: { current: 0 }, bob: { answer: 0 }, meta: { ownerId: "alice" }, questions: {}, board: {} } : null }) }) };
  const service = createQuestionHistoryService({ db, realtime, questionBank: bank });
  const call = (uid, data) => service.execute(uid, data);
  const prepare = (uid, keys = [], extra = {}) => call(uid, { action: "prepare", keys, ...extra });
  const reserve = (uid, keys, operationId, extra = {}) => call(uid, { action: "reserve", keys, operationId, ...extra });
  return { db, call, prepare, reserve };
}

test("identity survives bank reorder, category/level/answer edits and Arabic spelling/format variants", () => {
  assert.equal(questionKey(q("مَا عَاصِمَةُ إِيطَالْيَا؟")), questionKey(q("ما عاصمة ايطاليا", { category: "دول", level: "8", answers: ["x"] })));
  assert.equal(questionKey({ Q: "ما نتيجة ٢ + ٣؟" }), questionKey(q("ما نتيجة 2 + 3")));
  assert.notEqual(questionKey(q("ما نتيجة -2؟")), questionKey(q("ما نتيجة 2؟")));
  assert.notEqual(questionKey(q("ما قيمة 3.6؟")), questionKey(q("ما قيمة 36؟")));
  assert.notEqual(questionKey(q("خمن الفيلم: 🐼 + 🥋")), questionKey(q("خمن الفيلم: ❄️ + 🦣")));
});

test("media and career template questions retain distinct content identities", () => {
  assert.notEqual(questionKey(q("من اللاعب؟", { img: "one.png" })), questionKey(q("من اللاعب؟", { img: "two.png" })));
  assert.notEqual(questionKey(q("من اللاعب؟", { clubPath: ["ريال مدريد", "روما"] })), questionKey(q("من اللاعب؟", { clubPath: ["روما", "ريال مدريد"] })));
  assert.equal(questionKey({ Q: "من اللاعب؟", Img: "one.png", ClubPath: ["روما"] }),
    questionKey(q("من اللاعب؟", { img: "one.png", clubPath: ["روما"] })));
});

test("durable history merges offline batches without deletion and isolates accounts", async () => {
  const x = setup(), a = questionKey(bank[0]), b = questionKey(bank[1]);
  await x.prepare("alice", [a]); await x.prepare("alice", [b]); await x.prepare("alice", []);
  assert.deepEqual(new Set((await x.prepare("alice")).ownKeys), new Set([a, b]));
  assert.deepEqual((await x.prepare("bob")).keys, []);
  const restarted = createQuestionHistoryService({ db: x.db });
  assert.deepEqual(new Set((await restarted.execute("alice", { action: "prepare" })).keys), new Set([a, b]));
});

test("peer exclusions include both histories, while offline uploads only modify their owner", async () => {
  const x = setup(), a = questionKey(bank[0]), b = questionKey(bank[1]);
  await x.prepare("bob", [b]);
  const prepared = await x.prepare("alice", [a], { roomId: "room" });
  assert.deepEqual(new Set(prepared.keys), new Set([a, b]));
  assert.deepEqual(prepared.ownKeys, [a]);
  assert.deepEqual((await x.prepare("bob")).ownKeys, [b]);
});

test("concurrent devices cannot reserve the same question; same operation retries are idempotent", async () => {
  const x = setup(), key = questionKey(bank[0]);
  const result = await Promise.allSettled([x.reserve("alice", [key], "one"), x.reserve("alice", [key], "two")]);
  assert.equal(result.filter(r => r.status === "fulfilled").length, 1);
  assert.equal(result.find(r => r.status === "rejected").reason.code, "aborted");
  await x.reserve("alice", [key], "one");
  await assert.rejects(x.reserve("alice", [questionKey(bank[1])], "one"), { code: "already-exists" });
});

test("multiplayer reservations are atomic for every human, across room and realtime modes", async () => {
  const x = setup(), keys = bank.slice(0, 12).map(questionKey);
  await x.reserve("alice", keys, "board", { roomId: "room" });
  assert.deepEqual(new Set((await x.prepare("bob")).keys), new Set(keys));
  await assert.rejects(x.reserve("bob", [keys[0]], "next_mode", { gameId: "game" }), { code: "aborted" });
  await assert.rejects(x.reserve("alice", [questionKey(bank[15]), keys[0]], "partial", { roomId: "room" }), { code: "aborted" });
  assert.equal((await x.prepare("alice")).keys.includes(questionKey(bank[15])), false);
});

test("foreign accounts, forged contexts and malformed payloads cannot access or erase history", async () => {
  const x = setup();
  await assert.rejects(x.prepare("mallory", [], { roomId: "room" }), { code: "permission-denied" });
  await assert.rejects(x.prepare("mallory", [], { gameId: "game" }), { code: "permission-denied" });
  for (const input of [{ action: "prepare", members: ["bob"] }, { action: "prepare", roomId: "../users" },
    { action: "prepare", keys: ["bad"] }, { action: "reserve", keys: [], operationId: "op" },
    { action: "reserve", keys: [questionKey(bank[0]), questionKey(bank[0])], operationId: "op" }])
    await assert.rejects(x.call("alice", input), { code: "invalid-argument" });
});

test("all fallback categories honor lifetime exclusions and content duplicates within a board", () => {
  const first = makeBoard(bank, ["جغرافيا", "جغرافيا"], "first");
  const previous = new Set(Object.values(first.cells).map(c => questionKey(c.question)));
  const next = makeBoard([...bank, ...bank.map(item => ({ ...item, id: `duplicate-${item.text}`, level: "8" }))],
    ["جغرافيا", "جغرافيا"], "second", previous);
  const keys = Object.values(next.cells).map(c => questionKey(c.question));
  assert.equal(new Set(keys).size, 12);
  assert.ok(keys.every(key => !previous.has(key)));
  assert.throws(() => makeBoard(bank, ["جغرافيا", "جغرافيا"], "exhausted", new Set(bank.map(questionKey))), { code: "resource-exhausted" });
});

test("shared classic allocations survive response loss and service restart without selecting a new batch", async () => {
  const x = setup();
  await x.prepare("bob", [questionKey(bank[0])]);
  for (const uid of ["alice", "bob"]) await x.call(uid, { action: "ready", roomId: "room" });
  const input = { action: "allocate", roomId: "room", operationId: "round_one" };
  const first = await x.call("alice", input);
  const retry = await x.call("bob", input);
  assert.deepEqual(first, retry);
  assert.equal(first.questions.length, 80);
  assert.ok(first.questions.every(item => questionKey(item) !== questionKey(bank[0])));
  const next = await x.call("alice", { ...input, operationId: "round_two" });
  const old = new Set(first.questions.map(questionKey));
  assert.ok(next.questions.every(item => !old.has(questionKey(item))));
  assert.equal(x.db.read(pathFor("bot_1", "a")), undefined);
});

test("automatic room starts wait for every human to upload offline history before allocation", async () => {
  const x = setup(), input = { action: "allocate", roomId: "room", operationId: "auto_start" };
  await x.call("alice", { action: "ready", roomId: "room" });
  assert.deepEqual(await x.call("alice", input), { waiting: true });
  assert.equal(x.db.read("question_history_rooms/room"), undefined);
  const offlineKeys = bank.slice(0, 20).map(questionKey);
  await x.prepare("bob", offlineKeys);
  await x.call("bob", { action: "ready", roomId: "room" });
  const allocated = await x.call("alice", input);
  assert.equal(allocated.questions.length, 80);
  assert.ok(allocated.questions.every(q => !offlineKeys.includes(questionKey(q))));
});

test("late joins reserve unseen room questions and reject history conflicts before display", async () => {
  const x = setup(), keys = bank.slice(0, 12).map(questionKey);
  await x.reserve("alice", keys, "board", { roomId: "room" });
  const room = x.db.read("rooms/room"); room.players.charlie = {}; room.players.dana = {};
  x.db.seed("rooms/room", room);
  await x.prepare("dana", [keys[0]]);
  await x.call("charlie", { action: "admit", roomId: "room" });
  assert.deepEqual(new Set((await x.prepare("charlie")).keys), new Set(keys));
  await x.call("charlie", { action: "admit", roomId: "room" });
  await assert.rejects(x.call("dana", { action: "admit", roomId: "room" }), { code: "failed-precondition" });
});
