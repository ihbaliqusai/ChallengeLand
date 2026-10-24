"use strict";

const { CommerceError, sha256 } = require("./domain");
const { normalize: categoryKey } = require("./economy");
const { isCorrect } = require("./board_answer_matcher");
const { tierForLevel: tier } = require("./question_tiers");
const { questionKey } = require("./question_identity");

const ROWS = 6, TURNS = 12, SELECT_MS = 30000, ANSWER_MS = 45000, PREPARE_MS = 60000, REVEAL_MS = 5000;
const VALUES = [200, 400, 600];
const fail = (code, message) => { throw new CommerceError(code, message); };
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const picker = m => m.currentTurn % 2 === 0 ? m.ownerId : m.joinerId;

function prepareQuestion(q) {
  if (!q || typeof q.category !== "string" || typeof q.text !== "string" || !q.text.trim()
      || !Array.isArray(q.answers) || q.answers.length !== 4 || q.answers.some(a => typeof a !== "string" || !a.trim())) return null;
  return { ...q, id: questionKey(q).slice(0, 24),
    level: String(q.level ?? "0"), img: typeof q.img === "string" ? q.img : "" };
}

function resolveCategory(bank, value) {
  return bank.find(q => categoryKey(q.category) === categoryKey(value))?.category;
}

// Exactly the classic board's tier order, six rows per category and no repeated
// question, including when both friends select the same category.
function makeBoard(bank, categories, seed, excluded = new Set()) {
  const all = bank.map(prepareQuestion).filter(Boolean).filter(q => !excluded.has(questionKey(q)));
  const used = new Set(), cells = {};
  const choose = candidates => candidates.filter(q => !used.has(questionKey(q)))
    .sort((a, b) => sha256(`${seed}|${a.id}`).localeCompare(sha256(`${seed}|${b.id}`)))[0];
  for (let col = 0; col < categories.length; col++) for (let row = 0; row < ROWS; row++) {
    const target = row % 3, own = all.filter(q => categoryKey(q.category) === categoryKey(categories[col]));
    const tiers = [target];
    for (let d = 1; d < 3; d++) for (const t of [target - d, target + d]) if (t >= 0 && t < 3) tiers.push(t);
    let q;
    for (const t of tiers) { q = choose(own.filter(q => tier(q.level) === t)); if (q) break; }
    const fallback = all.filter(q => categoryKey(q.category) === categoryKey("منوعات"));
    if (!q) q = choose(fallback.filter(q => tier(q.level) === target));
    if (!q) for (let t = 0; t < 3; t++) { q = choose(fallback.filter(q => tier(q.level) === t)); if (q) break; }
    if (!q) q = choose(all);
    if (!q) fail("resource-exhausted", "لا توجد أسئلة جديدة كافية. اختر تصنيفات أخرى أو انتظر إضافة أسئلة جديدة.");
    used.add(questionKey(q));
    const order = [0, 1, 2, 3].sort((a, b) => sha256(`${seed}|${q.id}|${a}`).localeCompare(sha256(`${seed}|${q.id}|${b}`)));
    cells[`${col}_${row}`] = { category: categories[col], points: VALUES[target], question: {
      id: q.id, text: q.text, category: q.category, level: q.level, img: q.img, clubPath: q.clubPath || [],
      answers: q.answers, options: order.map(i => q.answers[i]), correctOption: order.indexOf(0),
    } };
  }
  return { categories, cells };
}

function visibleQuestion(m, turn) {
  if (!turn) return undefined;
  const q = m.cells?.[`${turn.col}_${turn.row}`]?.question;
  if (!q) return undefined;
  const result = { id: q.id, text: q.text, category: q.category, level: q.level, img: q.img, clubPath: q.clubPath || [] };
  if (turn.revealCount > 0 || turn.done) result.options = q.options.map((text, index) => ({ index, text }));
  if (turn.revealCount > 1) result.hiddenIndices = turn.hiddenIndices || [];
  if (turn.done) Object.assign(result, { rightAnswer: q.answers[0], correctOptionIndex: q.correctOption });
  return result;
}

function projection(m) {
  const turns = Object.fromEntries(Object.entries(m.turns || {}).map(([key, t]) => {
    const { optionIndex, answerText, answerSignature, hiddenIndices, ...visible } = object(t) ? t : {};
    const question = visibleQuestion(m, object(t) ? t : undefined);
    return [key, { ...visible, ...(question ? { question } : {}) }];
  }));
  return { protocolVersion: 2, rows: ROWS, totalTurns: TURNS, picks: m.picks || {}, turns,
    availableAtMillis: m.availableAtMillis || 0,
    cells: Object.fromEntries(Object.entries(m.cells || {}).map(([key, c]) => [key, { category: c?.category || "", points: c?.points || 0 }])),
  };
}

function healthy(m) {
  if (!object(m.picks) || Object.keys(m.picks).some(uid => !m.members.includes(uid))
      || Object.values(m.picks).some(p => !object(p) || typeof p.category !== "string" || !p.category)) return false;
  if (!Number.isInteger(m.currentTurn) || m.currentTurn < 0 || m.currentTurn >= TURNS) return false;
  if (m.status === "waiting") return m.phase === "category_select" && m.currentTurn === 0
    && m.categories.length === 0 && Object.keys(m.cells).length === 0 && Object.keys(m.turns).length === 0;
  if (m.status !== "active" || !["selecting", "observing", "answering"].includes(m.phase)
      || m.categories.length !== 2 || Object.keys(m.cells).length !== TURNS) return false;
  for (let col = 0; col < 2; col++) for (let row = 0; row < ROWS; row++) {
    const c = m.cells[`${col}_${row}`], q = c?.question;
    if (!object(c) || c.points !== VALUES[row % 3] || !object(q) || typeof q.text !== "string"
        || !Array.isArray(q.answers) || q.answers.length !== 4 || q.answers.some(a => typeof a !== "string")
        || !Array.isArray(q.options) || q.options.length !== 4 || q.options.some(a => typeof a !== "string")
        || !Number.isInteger(q.correctOption) || q.correctOption < 0 || q.correctOption > 3
        || q.options[q.correctOption] !== q.answers[0]) return false;
  }
  if (m.phase !== "selecting") {
    const t = m.turns[`t${m.currentTurn}`];
    if (!object(t) || t.playerId !== picker(m) || t.done || !m.cells[`${t.col}_${t.row}`]
        || !Number.isInteger(t.revealCount) || t.revealCount < 0 || t.revealCount > 2) return false;
  }
  return true;
}

function claim(m, col, row, at) {
  const cell = `${col}_${row}`;
  if (m.phase !== "selecting" || Object.hasOwn(m.consumed, cell) || !m.cells[cell]) fail("failed-precondition", "الخانة غير متاحة.");
  if (at < (m.availableAtMillis || 0)) fail("failed-precondition", "انتظر ظهور نتيجة السؤال.");
  m.turns[`t${m.currentTurn}`] = { playerId: picker(m), col, row, revealCount: 0, claimedAtMillis: at };
  m.consumed[cell] = m.currentTurn;
  m.phase = "observing";
  m.deadlineAtMillis = at + PREPARE_MS;
}

function completeTurn(m, at, input, finish) {
  const key = `t${m.currentTurn}`, turn = m.turns[key];
  const q = turn && m.cells[`${turn.col}_${turn.row}`]?.question;
  if (!q) return finish(m, "system_error");
  const skipped = input.skipped === true;
  const correct = !skipped && (typeof input.answerText === "string"
    ? turn.revealCount === 0 && isCorrect(input.answerText, q)
    : turn.revealCount > 0 && !turn.hiddenIndices?.includes(input.optionIndex) && input.optionIndex === q.correctOption);
  const points = correct ? Math.floor(m.cells[`${turn.col}_${turn.row}`].points / (2 ** turn.revealCount)) : 0;
  Object.assign(turn, { done: true, correct, points, completedAtMillis: at,
    ...(skipped ? { skipped: true, skipReason: input.skipReason || "timeout" } : {
      answerSignature: sha256(JSON.stringify(typeof input.answerText === "string" ? { answerText: input.answerText } : { optionIndex: input.optionIndex })),
    }) });
  m.scores[turn.playerId] += points;
  m.currentTurn++;
  if (m.currentTurn >= TURNS) {
    const a = m.scores[m.ownerId], b = m.scores[m.joinerId];
    finish(m, a === b ? "draw" : "completed", a === b ? "" : a > b ? m.ownerId : m.joinerId);
  } else {
    m.phase = "selecting";
    m.availableAtMillis = at + REVEAL_MS;
    m.deadlineAtMillis = m.availableAtMillis + SELECT_MS;
  }
}

function reconcile(m, at, finish) {
  if (m.phase === "selecting") {
    const unused = Object.keys(m.cells).filter(cell => !Object.hasOwn(m.consumed, cell));
    const cell = unused.sort((a, b) => sha256(`${m.matchId}|${m.currentTurn}|${a}`).localeCompare(sha256(`${m.matchId}|${m.currentTurn}|${b}`)))[0];
    if (!cell) return finish(m, "system_error");
    const [col, row] = cell.split("_").map(Number);
    claim(m, col, row, at);
  } else completeTurn(m, at, { skipped: true }, finish);
}

function apply(m, uid, input, at, finish) {
  const turn = m.turns[`t${input.turn ?? m.currentTurn}`];
  // An explicit unanswered turn must work for both typed and revealed options.
  // Retrying after a lost response must never close the following turn.
  if (input.action === "skipAnswer" && turn?.done && turn.playerId === uid) {
    if (turn.skipReason !== "background") fail("already-exists", "تم تثبيت إجابة هذا الدور.");
    return;
  }
  if (input.action === "answer" && turn?.done && turn.playerId === uid) {
    const sig = sha256(JSON.stringify(typeof input.answerText === "string" ? { answerText: input.answerText } : { optionIndex: input.optionIndex }));
    if (turn.answerSignature !== sig) fail("already-exists", "تم تثبيت إجابة هذا الدور.");
    return;
  }
  if (input.turn !== m.currentTurn || uid !== picker(m)) fail("failed-precondition", "انتظر دورك الحالي.");
  if (input.action === "claim") {
    if (turn?.playerId === uid && turn.col === input.col && turn.row === input.row && !turn.done) return;
    return claim(m, input.col, input.row, at);
  }
  if (!turn || turn.playerId !== uid || turn.done) fail("failed-precondition", "اختر سؤالاً أولاً.");
  if (input.action === "beginAnswer") {
    if (m.phase === "observing") { m.phase = "answering"; turn.answerStartedAtMillis = at; m.deadlineAtMillis = at + ANSWER_MS; }
    else if (m.phase !== "answering") fail("failed-precondition", "السؤال غير متاح.");
  } else if (input.action === "reveal") {
    if (m.phase !== "answering") fail("failed-precondition", "لم يبدأ وقت الإجابة بعد.");
    if (input.count < turn.revealCount || input.count > turn.revealCount + 1) fail("failed-precondition", "طلب كشف الخيارات غير صالح.");
    if (input.count === 2 && !turn.hiddenIndices) {
      const q = m.cells[`${turn.col}_${turn.row}`].question;
      turn.hiddenIndices = [0, 1, 2, 3].filter(i => i !== q.correctOption).slice(0, 2);
    }
    turn.revealCount = input.count;
  } else if (input.action === "skipAnswer") {
    if (m.phase !== "answering") fail("failed-precondition", "لم يبدأ وقت الإجابة بعد.");
    completeTurn(m, at, { skipped: true, skipReason: "background" }, finish);
  } else if (input.action === "answer") {
    if (m.phase !== "answering") fail("failed-precondition", "لم يبدأ وقت الإجابة بعد.");
    if (typeof input.answerText === "string" ? turn.revealCount !== 0 : turn.revealCount === 0)
      fail("failed-precondition", "طريقة الإجابة غير متاحة في هذا السؤال.");
    if (turn.hiddenIndices?.includes(input.optionIndex)) fail("invalid-argument", "هذا الخيار محذوف.");
    completeTurn(m, at, input, finish);
  }
}

module.exports = { ROWS, TURNS, SELECT_MS, ANSWER_MS, makeBoard, resolveCategory, projection, healthy,
  visibleQuestion, reconcile, apply };
