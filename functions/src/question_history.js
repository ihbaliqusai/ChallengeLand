"use strict";

const { CommerceError, sha256 } = require("./domain");
const { questionKey } = require("./question_identity");
const SHARDS = Array.from("0123456789abcdef");
const KEY = /^[a-f0-9]{64}$/;
const pathFor = (uid, shard) => `question_history/${uid}/shards/${shard}`;
const fail = (code, message) => { throw new CommerceError(code, message); };

async function readHistory(tx, db, members) {
  const snapshots = await Promise.all(members.flatMap(uid => SHARDS.map(shard => tx.get(db.doc(pathFor(uid, shard))))));
  const histories = new Map();
  members.forEach((uid, index) => histories.set(uid, new Set(snapshots.slice(index * 16, index * 16 + 16)
    .flatMap(s => (s.data()?.keys || []).filter(k => typeof k === "string" && KEY.test(k))))));
  return histories;
}

function writeHistory(tx, db, histories, keys) {
  for (const [uid, previous] of histories) {
    const additions = [...new Set(keys)].filter(k => !previous.has(k));
    for (const shard of new Set(additions.map(k => k[0]))) {
      const merged = [...previous].filter(k => k[0] === shard).concat(additions.filter(k => k[0] === shard)).sort();
      tx.set(db.doc(pathFor(uid, shard)), { version: 1, keys: merged });
    }
  }
}

// No history is client-readable. A verified participant can obtain exclusions
// for their current game; arbitrary account IDs are never accepted from clients.
function createQuestionHistoryService({ db, realtime, questionBank }) {
  async function membersFor(uid, input) {
    if (input.roomId) {
      const room = (await db.doc(`rooms/${input.roomId}`).get()).data();
      if (!room?.players?.[uid]) fail("permission-denied", "الغرفة غير متاحة لك.");
      return Object.keys(room.players).filter(id => !id.startsWith("bot_"));
    }
    if (input.gameId) {
      const snapshot = await realtime.ref(`Games/${input.gameId}`).get();
      const game = snapshot.val();
      if (!game?.[uid]) fail("permission-denied", "المباراة غير متاحة لك.");
      return Object.entries(game).filter(([id, value]) => !id.startsWith("bot_") && value
        && typeof value === "object" && (Object.hasOwn(value, "current") || Object.hasOwn(value, "answer")))
        .map(([id]) => id);
    }
    return [uid];
  }

  async function execute(uid, input) {
    if (typeof uid !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) fail("unauthenticated", "سجل الدخول أولًا.");
    if (!input || !["prepare", "reserve", "allocate", "admit", "ready"].includes(input.action)
        || Object.keys(input).some(k => !["action", "keys", "gameId", "roomId", "operationId"].includes(k))
        || [input.gameId, input.roomId].some(id => id !== undefined && (typeof id !== "string" || !/^[A-Za-z0-9_|-]{1,200}$/.test(id)))
        || input.gameId && input.roomId) fail("invalid-argument", "طلب الأسئلة غير صالح.");
    const keys = input.keys ?? [];
    if (!Array.isArray(keys) || keys.length > 1000 || keys.some(k => typeof k !== "string" || !KEY.test(k)))
      fail("invalid-argument", "سجل الأسئلة غير صالح.");
    if (input.action === "reserve" && (!keys.length || new Set(keys).size !== keys.length
        || typeof input.operationId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.operationId)))
      fail("invalid-argument", "حجز الأسئلة غير صالح.");
    if (input.action === "allocate" && (!(input.roomId || input.gameId) || keys.length
        || typeof input.operationId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.operationId)))
      fail("invalid-argument", "طلب أسئلة المباراة غير صالح.");
    if (["admit", "ready"].includes(input.action) && (!input.roomId || keys.length || input.operationId))
      fail("invalid-argument", "طلب انضمام الأسئلة غير صالح.");
    const members = await membersFor(uid, input);
    if (!members.includes(uid) || members.length > 8) fail("permission-denied", "المباراة غير متاحة لك.");
    return db.runTransaction(async tx => {
      const roomRef = input.roomId ? db.doc(`question_history_rooms/${input.roomId}`) : null;
      const readyRef = input.roomId ? db.doc(`question_history_ready/${input.roomId}`) : null;
      if (input.action === "ready") {
        tx.set(readyRef, { [uid]: true }, { merge: true });
        return { ready: true };
      }
      if (input.action === "admit") {
        const active = (await tx.get(roomRef)).data();
        if (!active) fail("failed-precondition", "انتظر تجهيز أسئلة الغرفة.");
        if (active.members.includes(uid)) return { admitted: true };
        const history = await readHistory(tx, db, [uid]);
        if (active.keys.some(k => history.get(uid).has(k)))
          fail("failed-precondition", "تحتوي المباراة الجارية على أسئلة سبق لك رؤيتها. انضم إلى مباراة جديدة.");
        writeHistory(tx, db, history, active.keys);
        tx.set(roomRef, { ...active, members: [...active.members, uid] });
        return { admitted: true };
      }
      const receipt = input.action !== "prepare" ? db.doc(`question_history_sessions/${sha256(JSON.stringify([
        input.action, input.action === "allocate" ? "shared" : uid,
        input.roomId ? ["room", input.roomId] : input.gameId ? ["game", input.gameId] : ["local"], input.operationId,
      ]))}`) : null;
      const saved = receipt ? (await tx.get(receipt)).data() : null;
      if (saved) {
        if (input.action === "allocate") return { questions: saved.questions };
        if (JSON.stringify(saved.keys) !== JSON.stringify(keys)) fail("already-exists", "تم تثبيت أسئلة هذه المحاولة.");
        return { reserved: true };
      }
      if (input.action === "allocate" && readyRef) {
        const ready = (await tx.get(readyRef)).data() || {};
        if (!members.every(member => ready[member] === true)) return { waiting: true };
      }
      const histories = await readHistory(tx, db, members);
      if (input.action === "prepare") {
        // Uploaded offline history belongs only to the authenticated account.
        writeHistory(tx, db, new Map([[uid, histories.get(uid)]]), keys);
        return { keys: [...new Set([...histories.values()].flatMap(s => [...s]).concat(keys))],
          ownKeys: [...new Set([...histories.get(uid), ...keys])] };
      }
      if (input.action === "allocate") {
        const excluded = new Set([...histories.values()].flatMap(s => [...s]));
        const pool = (questionBank || require("./original_stake_questions.json"))
          .map(q => ({ q, key: questionKey(q) })).filter(item => !excluded.has(item.key))
          .map(item => ({ ...item, rank: sha256(`${input.operationId}|${item.key}`) }))
          .sort((a, b) => a.rank.localeCompare(b.rank)).map(item => item.q);
        const selected = [], seen = new Set();
        const take = (candidates, count) => {
          let taken = 0;
          for (const q of candidates) if (taken < count && !seen.has(questionKey(q))) {
            seen.add(questionKey(q)); selected.push(q); taken++;
          }
        };
        if (input.roomId) take(pool, 80);
        else for (const [level, count] of [["0", 3], ["1", 3], ["2", 5], ["3", 39]])
          take(pool.filter(q => String(q.level) === level), count);
        if (selected.length < (input.roomId ? 80 : 50))
          fail("resource-exhausted", "لا توجد أسئلة جديدة كافية للمباراة. انتظر إضافة أسئلة جديدة.");
        writeHistory(tx, db, histories, [...seen]);
        tx.set(receipt, { keys: [...seen], questions: selected, members });
        if (roomRef) tx.set(roomRef, { keys: [...seen], members });
        return { questions: selected };
      }
      if (keys.some(k => [...histories.values()].some(h => h.has(k))))
        fail("aborted", "تغير سجل الأسئلة. أعد المحاولة لاختيار أسئلة جديدة.");
      writeHistory(tx, db, histories, keys);
      tx.set(receipt, { keys, members });
      if (roomRef) tx.set(roomRef, { keys, members });
      return { reserved: true };
    });
  }
  return { execute };
}

module.exports = { createQuestionHistoryService, readHistory, writeHistory, pathFor };
