"use strict";

// Server port of BoardAnswerMatcher.java. Paid and free boards use the same
// Arabic normalization, spelling tolerance and wrong-option disambiguation.
const STOPWORDS = new Set(["و", "من", "في", "على", "عن", "الى", "ابن", "بن", "ابو", "ام", "ال", "the", "of", "a", "an", "el", "le", "la"]);
const NUMBER_WORDS = new Map();
for (const [digits, words] of Object.entries({
  0: ["صفر"], 1: ["واحد", "واحده", "احد", "احدي"], 2: ["اثنان", "اثنين", "اثنتان", "اثنتين", "اتنين"],
  3: ["ثلاثه", "ثلاث", "تلاته"], 4: ["اربعه", "اربع"], 5: ["خمسه", "خمس"], 6: ["سته", "ست"],
  7: ["سبعه", "سبع"], 8: ["ثمانيه", "ثماني", "ثمان", "تمانيه"], 9: ["تسعه", "تسع"],
  10: ["عشره", "عشر"], 20: ["عشرون", "عشرين"], 30: ["ثلاثون", "ثلاثين"], 40: ["اربعون", "اربعين"],
  50: ["خمسون", "خمسين"], 60: ["ستون", "ستين"], 70: ["سبعون", "سبعين"], 80: ["ثمانون", "ثمانين"],
  90: ["تسعون", "تسعين"], 100: ["مايه", "ميه"], 1000: ["الف"], 1000000: ["مليون"], 1000000000: ["مليار"],
})) for (const word of words) NUMBER_WORDS.set(word, digits);

function normalize(value) {
  if (value == null) return "";
  return String(value).trim().toLowerCase().replace(/[\u064b-\u0652\u0670\u0640]/g, "")
    .replace(/[\u0660-\u0669]/g, c => String(c.charCodeAt(0) - 0x660))
    .replace(/[\u06f0-\u06f9]/g, c => String(c.charCodeAt(0) - 0x6f0))
    .replace(/[أإآٱ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/ؤ/g, "و").replace(/ئ/g, "ي")
    .replace(/[^0-9a-zء-ي]/g, " ").trim().split(/ +/).filter(Boolean)
    .map(word => NUMBER_WORDS.get(word) ?? word).join(" ");
}

function levenshtein(a, b) {
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i), cur = new Array(b.length + 1);
  for (let i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (let j = 1; j <= b.length; j++) cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    [prev, cur] = [cur, prev];
  }
  return prev[b.length];
}
const tokens = value => value.split(" ").filter(Boolean);
const distinctive = value => { const all = tokens(value), found = all.filter(t => t.length >= 2 && !STOPWORDS.has(t)); return found.length ? found : all; };
const similarity = (a, b) => !a.length && !b.length ? 1 : 1 - levenshtein(a, b) / Math.max(a.length, b.length);
const fuzzy = (a, b) => a === b || levenshtein(a, b) <= (Math.max(a.length, b.length) <= 4 ? 1 : 2);
const appears = (token, text, parts) => text.includes(token) || parts.some(part => fuzzy(part, token));
const covered = (text, parts, target) => target.filter(token => appears(token, text, parts)).length;

function isCorrect(typed, question) {
  if (!question) return false;
  const nt = normalize(typed), right = normalize(question.answers?.[0] ?? question.R);
  if (!nt || !right) return false;
  const wrongs = (question.answers?.slice(1) ?? [question.W1, question.W2, question.W3]).map(normalize).filter(Boolean);
  if (nt === right) return true;
  const budget = right.length <= 4 ? 1 : right.length <= 8 ? 2 : Math.max(2, Math.round(right.length * 0.22));
  if (levenshtein(nt, right) <= budget && similarity(nt, right) > Math.max(0, ...wrongs.map(w => similarity(nt, w)))) return true;
  const rTokens = distinctive(right), ntTokens = tokens(nt);
  for (const tok of rTokens) {
    if (tok.length < 3 || !appears(tok, nt, ntTokens)) continue;
    if (wrongs.some(w => w.includes(tok) || tokens(w).some(t => fuzzy(t, tok)))) continue;
    if (rTokens.length === 1 || tok.length >= 4) return true;
  }
  const candidates = [nt, ...ntTokens].filter(c => c.length >= 4);
  if (candidates.length) for (const tok of rTokens) {
    if (tok.length < 4) continue;
    const bestRight = Math.max(...candidates.map(c => similarity(c, tok)));
    if (bestRight < 0.5) continue;
    const bestWrong = Math.max(0, ...wrongs.flatMap(w => distinctive(w).filter(t => t.length >= 3).flatMap(t => candidates.map(c => similarity(c, t)))));
    if (bestRight >= bestWrong + 0.1) return true;
  }
  if (rTokens.length < 2) return false;
  const count = covered(nt, ntTokens, rTokens);
  return count >= Math.ceil(rTokens.length / 2) && wrongs.every(w => covered(nt, ntTokens, distinctive(w)) < count);
}

module.exports = { normalize, isCorrect };
