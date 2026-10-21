"use strict";

const { randomInt } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");
const { CommerceError, sha256 } = require("./domain");
const { refresh: refreshEconomy, normalize: categoryKey, canonical, free } = require("./economy");
const originalBoard = require("./original_stake_board");
const { tierForLevel } = require("./question_tiers");

const AMOUNTS = Object.freeze([50, 100, 250, 500, 1000, 2500, 5000]);
const INVITE_MS = 30000;
const READY_MS = 120000;
const SELECT_MS = 45000;
const ANSWER_MS = 30000;
const MATCH_MS = 15 * 60000;
const ORIGINAL_MATCH_MS = 35 * 60000;
const ID = /^[A-Za-z0-9_-]{1,128}$/;
const OP = /^[A-Za-z0-9_-]{1,160}$/;
const millis = value => typeof value?.toMillis === "function" ? value.toMillis()
  : value && Number.isFinite(value._seconds) ? value._seconds * 1000 + Math.floor((value._nanoseconds || 0) / 1000000) : Number(value);
const money = value => Number.isSafeInteger(value) && value >= 0 && value <= 2147483647 ? value : 0;
const fail = (code, message) => { throw new CommerceError(code, message); };
const pairId = (a, b) => [a, b].sort().join(":");

function shuffled(values, draw) {
  const result = [...values];
  for (let i = result.length - 1; i > 0; i--) {
    const j = draw(i + 1);
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Answers and unselected questions never enter a client-readable document.
function makeBoard(bank, draw) {
  const pools = new Map();
  for (const q of bank) {
    if (typeof q.category !== "string" || typeof q.text !== "string" || !q.text.trim()
        || !Array.isArray(q.answers) || q.answers.length !== 4
        || q.answers.some(a => typeof a !== "string" || !a.trim()) || new Set(q.answers).size !== 4) continue;
    if (!pools.has(q.category)) pools.set(q.category, []);
    pools.get(q.category).push(q);
  }
  const categories = shuffled([...pools.keys()].filter(c => pools.get(c).length >= 3), draw).slice(0, 2);
  if (categories.length !== 2) fail("unavailable", "بنك أسئلة التحدي غير متاح الآن.");
  const cells = {};
  for (let col = 0; col < 2; col++) {
    const pool = shuffled(pools.get(categories[col]), draw);
    const used = new Set();
    for (let row = 0; row < 3; row++) {
      // Prefer the existing bank's difficulty bands, then safely fill a sparse band.
      const q = pool.find(q => !used.has(q.text) && tierForLevel(q.level) === row)
        || pool.find(q => !used.has(q.text));
      if (!q) fail("unavailable", "بنك أسئلة التحدي غير مكتمل.");
      used.add(q.text);
      const order = shuffled([0, 1, 2, 3], draw);
      cells[`${col}_${row}`] = { category: categories[col], points: [200, 400, 600][row],
        question: { id: sha256(q.text).slice(0, 24), text: q.text, options: order.map(i => q.answers[i]), correctOption: order.indexOf(0) } };
    }
  }
  return { categories, cells };
}

function projection(m, at) {
  const object = value => value && typeof value === "object" && !Array.isArray(value) ? value : {};
  const result = { protocolVersion: 1, matchId: m.matchId, ownerId: m.ownerId, joinerId: m.joinerId,
    members: m.members, stakeCoins: m.stakeCoins, prizeCoins: m.stakeCoins * 2,
    status: m.status, ready: object(m.ready), rows: 3, categories: Array.isArray(m.categories) ? m.categories : [],
    cells: Object.fromEntries(Object.entries(object(m.cells)).map(([key, c]) => [key, { category: c?.category || "", points: money(c?.points) }])),
    currentTurn: Number.isInteger(m.currentTurn) ? m.currentTurn : 0, phase: m.phase, consumed: object(m.consumed),
    turns: Object.fromEntries(Object.entries(object(m.turns)).map(([key, value]) => {
      const t = object(value);
      const { optionIndex, ...visible } = t;
      return [key, visible];
    })),
    scores: { [m.ownerId]: money(m.scores?.[m.ownerId]), [m.joinerId]: money(m.scores?.[m.joinerId]) }, winnerId: m.winnerId || "", finishReason: m.finishReason || "",
    deadlineAtMillis: m.deadlineAtMillis, serverTimeMillis: at,
    settlement: m.settlement || null };
  return m.protocolVersion === 2 ? { ...result, ...originalBoard.projection(m) } : result;
}

function currentQuestion(m, uid) {
  const turn = m.turns?.[`t${m.currentTurn}`];
  if (m.protocolVersion === 2) return m.status === "active" && ["answering", "observing"].includes(m.phase)
    ? originalBoard.visibleQuestion(m, turn) : undefined;
  if (m.status !== "active" || m.phase !== "answering" || turn?.playerId !== uid || turn.done) return undefined;
  const q = m.cells?.[`${turn.col}_${turn.row}`]?.question;
  if (!q) return undefined;
  return { id: q.id, text: q.text, options: q.options };
}

function completeTurn(m, at, { optionIndex = -1, skipped = false } = {}) {
  const key = `t${m.currentTurn}`;
  const playerId = m.currentTurn % 2 === 0 ? m.ownerId : m.joinerId;
  const turn = m.turns[key] || { playerId };
  const cell = m.cells[`${turn.col}_${turn.row}`];
  const correct = !skipped && optionIndex >= 0 && cell?.question.correctOption === optionIndex;
  Object.assign(turn, { done: true, correct, points: correct ? cell.points : 0, optionIndex,
    ...(skipped ? { skipped: true, skipReason: "timeout" } : {}) });
  m.turns[key] = turn;
  m.scores[playerId] += turn.points;
  m.currentTurn++;
  if (m.currentTurn >= 6) {
    const a = m.scores[m.ownerId], b = m.scores[m.joinerId];
    finish(m, a === b ? "draw" : "completed", a === b ? "" : a > b ? m.ownerId : m.joinerId);
  } else {
    m.phase = "selecting";
    m.deadlineAtMillis = at + SELECT_MS;
  }
}

function finish(m, reason, winner = "") {
  m.status = "settled";
  m.phase = "finished";
  m.winnerId = winner;
  m.finishReason = reason;
  m.deadlineAtMillis = 0;
}

function healthy(m) {
  const map = value => value !== null && typeof value === "object" && !Array.isArray(value);
  if (m.protocolVersion === 2) return AMOUNTS.includes(m.stakeCoins) && Array.isArray(m.members) && m.members.length === 2
    && m.members.includes(m.ownerId) && m.members.includes(m.joinerId) && m.ownerId !== m.joinerId
    && ID.test(m.ownerId) && ID.test(m.joinerId) && map(m.ready) && map(m.turns) && map(m.consumed) && map(m.cells) && map(m.scores)
    && Array.isArray(m.categories) && m.categories.every(c => typeof c === "string")
    && Number.isSafeInteger(m.deadlineAtMillis) && m.deadlineAtMillis > 0 && Number.isSafeInteger(m.expiresAtMillis) && m.expiresAtMillis > 0
    && Number.isSafeInteger(m.scores[m.ownerId]) && m.scores[m.ownerId] >= 0
    && Number.isSafeInteger(m.scores[m.joinerId]) && m.scores[m.joinerId] >= 0 && originalBoard.healthy(m);
  const cells = ["0_0", "0_1", "0_2", "1_0", "1_1", "1_2"];
  return AMOUNTS.includes(m.stakeCoins) && Array.isArray(m.members) && m.members.length === 2
    && m.members.includes(m.ownerId) && m.members.includes(m.joinerId) && m.ownerId !== m.joinerId
    && ID.test(m.ownerId) && ID.test(m.joinerId)
    && map(m.ready) && map(m.turns) && map(m.consumed) && map(m.cells) && map(m.scores)
    && Array.isArray(m.categories) && m.categories.length === 2 && m.categories.every(c => typeof c === "string")
    && ["waiting", "active"].includes(m.status) && ["selecting", "answering"].includes(m.phase)
    && Number.isSafeInteger(m.deadlineAtMillis) && m.deadlineAtMillis > 0
    && Number.isSafeInteger(m.expiresAtMillis) && m.expiresAtMillis > 0
    && Number.isInteger(m.currentTurn) && m.currentTurn >= 0 && m.currentTurn < 6
    && Object.keys(m.cells).length === 6 && cells.every(key => {
      const c = m.cells[key];
      return map(c) && c.points === [200, 400, 600][Number(key[2])]
        && typeof c.question?.text === "string" && Array.isArray(c.question.options) && c.question.options.length === 4
        && c.question.options.every(a => typeof a === "string")
        && Number.isInteger(c.question.correctOption) && c.question.correctOption >= 0 && c.question.correctOption <= 3;
    })
    && Number.isSafeInteger(m.scores[m.ownerId]) && m.scores[m.ownerId] >= 0
    && Number.isSafeInteger(m.scores[m.joinerId]) && m.scores[m.joinerId] >= 0
    && (m.phase !== "answering" || map(m.turns[`t${m.currentTurn}`])
      && m.turns[`t${m.currentTurn}`].playerId === (m.currentTurn % 2 === 0 ? m.ownerId : m.joinerId)
      && cells.includes(`${m.turns[`t${m.currentTurn}`].col}_${m.turns[`t${m.currentTurn}`].row}`));
}

function reconcile(m, at) {
  if (m.status === "settled") return;
  if (!healthy(m)) return finish(m, "system_error");
  if (at >= m.expiresAtMillis) return finish(m, m.status === "waiting" ? "not_started" : "system_expired");
  if (m.status === "active" && at >= m.deadlineAtMillis) {
    if (m.protocolVersion === 2) originalBoard.reconcile(m, at, finish);
    else completeTurn(m, at, { skipped: true });
  }
}

function createFriendStakesService({ db, now = Date.now, draw = randomInt, questionBank, legacyInvitesEnabled = false }) {
  const bank = () => questionBank || require("./stake_questions.json");
  const classicBank = () => questionBank || require("./original_stake_questions.json");
  const ref = path => db.doc(path);
  const read = async (tx, path) => (await tx.get(ref(path))).data();
  const save = (tx, path, value) => tx.set(ref(path), value);

  function validate(uid, input) {
    if (!ID.test(uid)) fail("unauthenticated", "سجّل الدخول للعب على قطع.");
    if (!input || typeof input !== "object" || Array.isArray(input)) fail("invalid-argument", "طلب غير صالح.");
    const allowed = {
      invite: ["action", "peerUid", "stakeCoins", "operationId", "gameplayVersion"],
      respond: ["action", "challengeId", "status", "expectedAmount", "operationId", "gameplayVersion"],
      sync: ["action", "matchId"],
      start: ["action", "matchId", "operationId"],
      claim: ["action", "matchId", "turn", "col", "row", "operationId"],
      answer: ["action", "matchId", "turn", "optionIndex", "answerText", "operationId"],
      pickCategory: ["action", "matchId", "category", "operationId"],
      beginAnswer: ["action", "matchId", "turn", "operationId"],
      reveal: ["action", "matchId", "turn", "count", "operationId"],
      forfeit: ["action", "matchId", "operationId"],
    }[input.action];
    if (!allowed || Object.keys(input).some(k => !allowed.includes(k))) fail("invalid-argument", "طلب التحدي غير صالح.");
    if (input.gameplayVersion !== undefined && input.gameplayVersion !== 2) fail("invalid-argument", "إصدار اللعب غير متاح.");
    if (input.action !== "sync" && !OP.test(input.operationId || "")) fail("invalid-argument", "معرّف العملية غير صالح.");
    if (input.action === "invite" && (!ID.test(input.peerUid || "") || input.peerUid === uid || !AMOUNTS.includes(input.stakeCoins)))
      fail("invalid-argument", "اختر صديقًا ومبلغًا صالحًا للتحدي.");
    if (input.action === "respond" && (typeof input.challengeId !== "string" || !/^[A-Za-z0-9_-]{1,128}:[A-Za-z0-9_-]{1,128}$/.test(input.challengeId)
        || !["accepted", "declined", "cancelled"].includes(input.status))) fail("invalid-argument", "الدعوة غير صالحة.");
    if (!["invite", "respond"].includes(input.action) && !/^[a-f0-9]{48}$/.test(input.matchId || "")) fail("invalid-argument", "معرّف المباراة غير صالح.");
    if (["claim", "answer", "beginAnswer", "reveal"].includes(input.action) && (!Number.isInteger(input.turn) || input.turn < 0 || input.turn > 11)) fail("invalid-argument", "الدور غير صالح.");
    if (input.action === "claim" && (!Number.isInteger(input.col) || input.col < 0 || input.col > 1 || !Number.isInteger(input.row) || input.row < 0 || input.row > 5))
      fail("invalid-argument", "الخانة غير صالحة.");
    if (input.action === "answer" && (Object.hasOwn(input, "answerText") === Object.hasOwn(input, "optionIndex")
        || (Object.hasOwn(input, "answerText") ? typeof input.answerText !== "string" || !input.answerText.trim() || input.answerText.length > 512
          : !Number.isInteger(input.optionIndex) || input.optionIndex < -1 || input.optionIndex > 3))) fail("invalid-argument", "الإجابة غير صالحة.");
    if (input.action === "pickCategory" && (typeof input.category !== "string" || input.category.length > 100 || !canonical(input.category)))
      fail("invalid-argument", "التصنيف غير متاح.");
    if (input.action === "reveal" && ![1, 2].includes(input.count)) fail("invalid-argument", "طلب كشف الخيارات غير صالح.");
  }

  async function policy(tx, a, b, at) {
    const paths = [`social_blocks/${a}:${b}`, `social_blocks/${b}:${a}`, `social_settings/${b}`,
      `social_links/${pairId(a, b)}`, `player_presence/${a}`, `player_presence/${b}`,
      `social_reservations/${a}`, `social_reservations/${b}`, `friend_stake_locks/${a}`, `friend_stake_locks/${b}`];
    const [blockA, blockB, settings, link, presenceA, presenceB, reservationA, reservationB, lockA, lockB] = await Promise.all(paths.map(p => read(tx, p)));
    if (blockA || blockB || settings?.allowChallenges === "none"
        || settings?.allowChallenges === "friends" && link?.status !== "accepted") fail("permission-denied", "لا يمكن إرسال هذا التحدي الآن.");
    for (const p of [presenceA, presenceB]) {
      if (p?.state !== "available" || millis(p.heartbeatAt) <= at - 75000 || millis(p.heartbeatAt) > at + 10000)
        fail("failed-precondition", "يجب أن يكون اللاعبان متاحين لقبول التحدي.");
    }
    for (const lock of [lockA, lockB]) {
      // An expired paid lock still needs recovery before another match may use its coins.
      if (lock?.active === true) fail("failed-precondition", "هناك تحدٍّ على قطع لم تتم تسويته بعد.");
    }
    for (const r of [reservationA, reservationB]) {
      if (r && millis(r.expiresAt) > at) fail("failed-precondition", "أحد اللاعبين مشغول بمباراة أخرى.");
    }
  }

  async function execute(uid, input) {
    validate(uid, input);
    const at = now();
    if (input.action === "invite" && input.gameplayVersion !== 2 && !legacyInvitesEnabled)
      fail("failed-precondition", "حدّث التطبيق لبدء تحدي القطع بنظام اللعب الأصلي.");
    // Entropy is generated once outside Firestore's retry callback.
    const prepared = input.action === "respond" && input.status === "accepted" && input.gameplayVersion !== 2 ? makeBoard(bank(), draw) : null;
    const originalSeed = input.action === "pickCategory" ? draw(2147483647) : 0;
    const receiptPath = `friend_stake_operations/${uid}/items/${sha256(input.operationId || "sync")}`;
    const signature = sha256(JSON.stringify(Object.fromEntries(Object.entries(input).filter(([k]) => k !== "operationId").sort(([a], [b]) => a.localeCompare(b)))));
    return db.runTransaction(async tx => {
      const receipt = input.action === "sync" ? undefined : await read(tx, receiptPath);
      if (receipt) {
        if (receipt.signature !== signature) fail("already-exists", "معرّف العملية مستخدم لطلب آخر.");
        const user = await read(tx, `users/${uid}`);
        return { ...receipt.result, currency: { coins: money(user?.coins), gems: money(user?.gems) } };
      }
      let result;
      if (input.action === "invite") {
        const id = pairId(uid, input.peerUid);
        const [old, limit, user] = await Promise.all([read(tx, `social_challenges/${id}`), read(tx, `social_limits/${uid}`), read(tx, `users/${uid}`)]);
        await policy(tx, uid, input.peerUid, at);
        if (old?.status === "pending" && millis(old.expiresAt) > at) fail("already-exists", "توجد دعوة معلّقة بينكما.");
        if (millis(limit?.challengeSentAt) > at - 10000) fail("resource-exhausted", "انتظر قليلًا قبل إرسال تحدٍّ آخر.");
        if (money(user?.coins) < input.stakeCoins) fail("resource-exhausted", "رصيدك من القطع غير كافٍ.");
        const matchId = sha256(`${uid}|${input.operationId}`).slice(0, 48);
        const data = { members: [uid, input.peerUid], fromUid: uid, toUid: input.peerUid, mode: "duel", status: "pending",
          createdAt: Timestamp.fromMillis(at), updatedAt: Timestamp.fromMillis(at), expiresAt: Timestamp.fromMillis(at + INVITE_MS),
          stakeCoins: input.stakeCoins, prizeCoins: input.stakeCoins * 2, stakeMatchId: matchId, serverStake: true,
          ...(input.gameplayVersion === 2 ? { gameplayVersion: 2 } : {}) };
        save(tx, `social_challenges/${id}`, data);
        tx.set(ref(`social_limits/${uid}`), { challengeSentAt: Timestamp.fromMillis(at) }, { merge: true });
        result = { challengeId: id, matchId, stakeCoins: input.stakeCoins, prizeCoins: input.stakeCoins * 2,
          currency: { coins: money(user?.coins), gems: money(user?.gems) } };
      } else if (input.action === "respond") {
        const challenge = await read(tx, `social_challenges/${input.challengeId}`);
        if (!challenge?.serverStake || !challenge.members.includes(uid)) fail("permission-denied", "الدعوة غير متاحة لك.");
        if (input.status === "cancelled" ? uid !== challenge.fromUid : uid !== challenge.toUid) fail("permission-denied", "لا يمكنك تنفيذ هذا الإجراء.");
        if (challenge.status !== "pending" || millis(challenge.expiresAt) <= at) fail("failed-precondition", "انتهت صلاحية الدعوة.");
        const user = await read(tx, `users/${uid}`);
        if (input.status === "accepted") {
          const original = challenge.gameplayVersion === 2;
          if (original !== (input.gameplayVersion === 2) || !original && !legacyInvitesEnabled)
            fail("failed-precondition", "حدّثا التطبيق ثم أرسلا دعوة جديدة لتحدي القطع بنظام اللعب الأصلي.");
          if (input.expectedAmount !== challenge.stakeCoins) fail("failed-precondition", "تغيّر مبلغ الدعوة. راجعها مجددًا.");
          const a = challenge.fromUid, b = challenge.toUid;
          await policy(tx, a, b, at);
          const other = await read(tx, `users/${a}`);
          const amount = challenge.stakeCoins;
          if (!AMOUNTS.includes(amount) || money(user?.coins) < amount || money(other?.coins) < amount)
            fail("resource-exhausted", "رصيد أحد اللاعبين غير كافٍ لقبول التحدي.");
          if (money(user?.coins) + amount > 2147483647 || money(other?.coins) + amount > 2147483647)
            fail("failed-precondition", "وصل رصيد أحد اللاعبين إلى الحد الأقصى.");
          const matchId = challenge.stakeMatchId;
          if (await read(tx, `friend_stake_matches/${matchId}`)) fail("already-exists", "تم قبول هذا التحدي مسبقًا.");
          const m = { matchId, challengeId: input.challengeId, members: [a, b], ownerId: a, joinerId: b,
            stakeCoins: amount, status: "waiting", ready: {},
            ...(original ? { protocolVersion: 2, picks: {}, categories: [], cells: {}, rows: 6 } : { ...prepared, rows: 3 }), currentTurn: 0,
            phase: original ? "category_select" : "selecting", consumed: {}, turns: {}, scores: { [a]: 0, [b]: 0 },
            createdAtMillis: at, expiresAtMillis: at + READY_MS, deadlineAtMillis: at + READY_MS };
          for (const [player, data] of [[a, other], [b, user]]) {
            tx.set(ref(`users/${player}`), { coins: money(data?.coins) - amount,
              friendStakeRevision: money(data?.friendStakeRevision) + 1, friendStakeMatchId: matchId }, { merge: true });
            save(tx, `friend_stake_locks/${player}`, { active: true, matchId, expiresAtMillis: at + READY_MS + (original ? ORIGINAL_MATCH_MS : MATCH_MS) });
            save(tx, `social_reservations/${player}`, { challengeId: input.challengeId, stakeMatchId: matchId,
              serverStake: true, acceptedAt: Timestamp.fromMillis(at), expiresAt: Timestamp.fromMillis(at + READY_MS + (original ? ORIGINAL_MATCH_MS : MATCH_MS)) });
          }
          save(tx, `friend_stake_matches/${matchId}`, m);
          save(tx, `friend_stake_escrows/${matchId}`, { matchId, challengeId: input.challengeId,
            ownerId: a, joinerId: b, members: [a, b], stakeCoins: amount, status: "held", heldAtMillis: at,
            ...(original ? { protocolVersion: 2, categoryAdmissions: {} } : {}) });
          save(tx, `friend_stake_views/${matchId}`, projection(m, at));
          result = { challengeId: input.challengeId, matchId, stakeCoins: amount, prizeCoins: amount * 2,
            match: projection(m, at), currency: { coins: money(user?.coins) - amount, gems: money(user?.gems) } };
        } else {
          result = { challengeId: input.challengeId, matchId: challenge.stakeMatchId,
            currency: { coins: money(user?.coins), gems: money(user?.gems) } };
        }
        save(tx, `social_challenges/${input.challengeId}`, { ...challenge, status: input.status,
          updatedAt: Timestamp.fromMillis(at), ...(input.status === "accepted" ? { acceptedAt: Timestamp.fromMillis(at) } : {}) });
      } else {
        const [state, escrow] = await Promise.all([
          read(tx, `friend_stake_matches/${input.matchId}`), read(tx, `friend_stake_escrows/${input.matchId}`),
        ]);
        if (!escrow?.members?.includes(uid)) fail("permission-denied", "المباراة غير متاحة لك.");
        const m = state || {};
        const before = JSON.stringify(m);
        // Preserve a separate financial receipt so damaged gameplay state can
        // never invent a refund amount, change participants, or replay a payout.
        const brokenHeader = m.matchId !== escrow.matchId || m.ownerId !== escrow.ownerId
          || m.joinerId !== escrow.joinerId || m.stakeCoins !== escrow.stakeCoins
          || JSON.stringify(m.members) !== JSON.stringify(escrow.members)
          || (m.protocolVersion === 2) !== (escrow.protocolVersion === 2);
        Object.assign(m, { matchId: escrow.matchId, challengeId: escrow.challengeId, ownerId: escrow.ownerId,
          joinerId: escrow.joinerId, members: escrow.members, stakeCoins: escrow.stakeCoins });
        const users = await Promise.all(m.members.map(player => read(tx, `users/${player}`)));
        // Read both reservations before any writes; a newer free reservation is never cleared.
        const reservations = await Promise.all(m.members.map(player => read(tx, `social_reservations/${player}`)));
        // All possible category/refund reads precede transaction writes, including
        // recovery when the private gameplay document has been damaged.
        const economies = escrow.protocolVersion === 2
          ? await Promise.all(m.members.map(player => read(tx, `economy_accounts/${player}`))) : [];
        const categoryEntitlement = input.action === "pickCategory" && escrow.protocolVersion === 2
          ? await read(tx, `commerce_accounts/${uid}/entitlements/current`) : undefined;
        if (escrow.status === "settled") {
          m.settlement = escrow.settlement;
          finish(m, escrow.finishReason, escrow.settlement.winnerId);
        } else if (brokenHeader || m.status === "settled") {
          delete m.settlement;
          finish(m, "system_error");
        } else reconcile(m, at);
        const timedOut = before !== JSON.stringify(m);
        if (m.status !== "settled" && (!timedOut || input.action === "forfeit")) {
          if (input.action === "start") {
            if (m.status === "waiting") {
              m.ready[uid] = true;
              if (m.protocolVersion !== 2 && m.members.every(player => m.ready[player])) {
                m.status = "active";
                m.startedAtMillis = at;
                m.expiresAtMillis = at + MATCH_MS;
                m.deadlineAtMillis = at + SELECT_MS;
              }
            }
          } else if (input.action === "forfeit") {
            finish(m, m.status === "waiting" ? "cancelled_before_start" : "forfeit",
              m.status === "waiting" ? "" : m.members.find(player => player !== uid));
          } else if (input.action === "pickCategory") {
            if (m.protocolVersion !== 2) fail("failed-precondition", "حدّث التطبيق وأرسل دعوة جديدة.");
            const existing = m.picks?.[uid]?.category;
            const category = originalBoard.resolveCategory(classicBank(), input.category);
            if (!category) fail("invalid-argument", "التصنيف غير متاح.");
            if (existing) {
              if (existing !== category) fail("already-exists", "تم تثبيت اختيار فئتك.");
            } else {
              if (m.status !== "waiting" || m.phase !== "category_select") fail("failed-precondition", "بدأت المباراة بالفعل.");
              const i = m.members.indexOf(uid), u = users[i] || {}, e = categoryEntitlement || {};
              const s = refreshEconomy(economies[i], at), key = categoryKey(category);
              const member = e.allCategories === true || e.isVip === true && e.expiresAtMillis > at;
              const owned = s.owned.some(c => categoryKey(c) === key)
                || (u.unlockedCategories || []).some(c => categoryKey(c) === key);
              const rented = Number(s.rentals[key] || 0) > at
                || Object.entries(u.categoryRentals || {}).some(([c, expiry]) => categoryKey(c) === key && Number(expiry) > at);
              const needed = !free(category) && !member && !owned && !rented;
              const ad = needed && !!s.adPermits[key];
              const ticketCost = needed && !ad ? 1 : 0;
              if (s.tickets < ticketCost) fail("resource-exhausted", "تحتاج تذكرة لفتح هذا التصنيف.");
              s.tickets -= ticketCost;
              if (ad) delete s.adPermits[key];
              s.revision = money(s.revision) + 1;
              m.picks[uid] = { category };
              m.ready[uid] = true;
              escrow.categoryAdmissions = { ...(escrow.categoryAdmissions || {}), [uid]: { category, ticketCost, ad, day: s.day } };
              if (m.members.every(player => m.picks[player]?.category)) {
                Object.assign(m, originalBoard.makeBoard(classicBank(), m.members.map(player => m.picks[player].category), originalSeed));
                m.status = "active";
                m.phase = "selecting";
                m.startedAtMillis = at;
                m.availableAtMillis = at;
                m.expiresAtMillis = at + ORIGINAL_MATCH_MS;
                m.deadlineAtMillis = at + originalBoard.SELECT_MS;
              }
              save(tx, `economy_accounts/${uid}`, s);
              save(tx, `friend_stake_escrows/${m.matchId}`, escrow);
            }
          } else if (["claim", "answer", "beginAnswer", "reveal"].includes(input.action)) {
            if (m.status !== "active") fail("failed-precondition", "لم تبدأ المباراة بعد.");
            if (m.protocolVersion === 2) originalBoard.apply(m, uid, input, at, finish);
            else {
            if (!["claim", "answer"].includes(input.action) || input.turn > 5 || input.row > 2
                || input.action === "answer" && typeof input.answerText === "string") fail("invalid-argument", "طلب التحدي غير صالح.");
            const key = `t${input.turn}`;
            const turn = m.turns[key];
            if (input.action === "claim" && turn?.playerId === uid && turn.col === input.col && turn.row === input.row && !turn.done) {
              // A repeated claim after a lost response returns the same question.
            } else if (input.action === "answer" && turn?.done && turn.playerId === uid) {
              if (turn.optionIndex !== input.optionIndex) fail("already-exists", "تم تثبيت إجابة هذا الدور.");
            } else {
              if (input.turn !== m.currentTurn || uid !== (m.currentTurn % 2 === 0 ? m.ownerId : m.joinerId))
                fail("failed-precondition", "انتظر دورك الحالي.");
              if (input.action === "claim") {
                const cell = `${input.col}_${input.row}`;
                if (m.phase !== "selecting" || Object.hasOwn(m.consumed, cell)) fail("failed-precondition", "الخانة غير متاحة.");
                m.turns[key] = { playerId: uid, col: input.col, row: input.row };
                m.consumed[cell] = m.currentTurn;
                m.phase = "answering";
                m.deadlineAtMillis = at + ANSWER_MS;
              } else {
                if (m.phase !== "answering" || turn?.playerId !== uid) fail("failed-precondition", "اختر سؤالًا أولًا.");
                completeTurn(m, at, { optionIndex: input.optionIndex });
              }
            }
            }
          }
        }
        if (m.status === "settled" && escrow.status === "held") {
          const paid = !!m.winnerId;
          m.settlement = { status: paid ? "paid" : "refunded", winnerId: m.winnerId || "",
            payoutCoins: paid ? m.stakeCoins * 2 : 0, refundCoins: paid ? 0 : m.stakeCoins, settledAtMillis: at };
          save(tx, `friend_stake_escrows/${m.matchId}`, { ...escrow, status: "settled",
            settlement: m.settlement, finishReason: m.finishReason });
          for (let i = 0; i < m.members.length; i++) {
            const player = m.members[i], user = users[i] || {};
            const credit = paid ? player === m.winnerId ? m.stakeCoins * 2 : 0 : m.stakeCoins;
            // Admission reserves headroom for the entire possible net win.
            tx.set(ref(`users/${player}`), { coins: money(user.coins) + credit,
              friendStakeRevision: money(user.friendStakeRevision) + 1, friendStakeMatchId: "" }, { merge: true });
            save(tx, `friend_stake_locks/${player}`, { active: false, matchId: m.matchId, settledAtMillis: at });
            if (reservations[i]?.stakeMatchId === m.matchId) save(tx, `social_reservations/${player}`, {
              ...reservations[i], expiresAt: Timestamp.fromMillis(at), settled: true });
            users[i] = { ...user, coins: money(user.coins) + credit };
            const admission = escrow.categoryAdmissions?.[player];
            if (!paid && m.finishReason !== "draw" && admission) {
              const s = refreshEconomy(economies[i], at);
              s.tickets = Math.min(2147483647, money(s.tickets) + money(admission.ticketCost));
              if (admission.ad) s.adPermits[categoryKey(admission.category)] = 1;
              s.revision = money(s.revision) + 1;
              save(tx, `economy_accounts/${player}`, s);
            }
          }
        }
        if (before !== JSON.stringify(m)) {
          save(tx, `friend_stake_matches/${m.matchId}`, m);
          save(tx, `friend_stake_views/${m.matchId}`, projection(m, at));
        }
        const mine = users[m.members.indexOf(uid)] || {};
        result = { matchId: m.matchId, match: projection(m, at), currency: { coins: money(mine.coins), gems: money(mine.gems) } };
        const question = currentQuestion(m, uid);
        if (question) result.question = question;
      }
      if (input.action !== "sync") save(tx, receiptPath, { signature, result, createdAtMillis: at });
      return result;
    });
  }

  async function recoverExpired() {
    let recovered = 0;
    let cursor;
    for (;;) {
      // Scan financial holds, so a missing/corrupt game document cannot strand
      // coins merely by disappearing from a gameplay status query.
      let query = db.collection("friend_stake_escrows").where("status", "==", "held").limit(100);
      if (cursor) query = query.startAfter(cursor);
      const batch = await query.get();
      for (const doc of batch.docs) {
        const escrow = doc.data();
        const m = (await ref(`friend_stake_matches/${doc.id}`).get()).data();
        if (m && healthy(m) && m.expiresAtMillis > now() && m.deadlineAtMillis > now()) continue;
        await execute(escrow.ownerId, { action: "sync", matchId: doc.id });
        recovered++;
      }
      if (batch.docs.length < 100) break;
      cursor = batch.docs.at(-1);
    }
    return { recovered };
  }

  return { execute, recoverExpired };
}

module.exports = { createFriendStakesService, AMOUNTS, makeBoard, projection };
