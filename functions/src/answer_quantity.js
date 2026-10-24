"use strict";

// Keep the parser in AnswerQuantity.java equivalent. Vocabulary is shared through
// answer_quantity_words.json and tools/sync_answer_quantity_vocabulary.cjs.
const vocabulary = require("./answer_quantity_words.json");
const foldWord = word => word.replace(/[\u064b-\u0652\u0670\u0640]/g, "").replace(/[أإآٱ]/g, "ا")
  .replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/ؤ/g, "و").replace(/ئ/g, "ي");
const expansions = Object.fromEntries(Object.entries(vocabulary.expand).map(([word, expanded]) => [foldWord(word), foldWord(expanded)]));
const mapWords = groups => new Map(Object.entries(groups).flatMap(([value, words]) => words.split(" ").map(word => [foldWord(word), value])));
const small = mapWords(vocabulary.small), hundreds = mapWords(vocabulary.hundreds), scales = mapWords(vocabulary.scales);
const units = mapWords(vocabulary.units), qualifiers = new Set(foldWord(vocabulary.qualifiers).split(" "));
const numericWord = word => small.has(word) || hundreds.has(word) || scales.has(word) || expansions[word] != null;
const withoutArticle = word => word.startsWith("ال") && (numericWord(word.slice(2)) || units.has(word.slice(2))) ? word.slice(2) : word;

function numberToken(word) {
  if (/^\d+(?:\.\d+)?$/.test(word)) return { value: Number(word), kind: "digit" };
  for (const [kind, words] of [["small", small], ["hundred", hundreds], ["scale", scales]]) {
    if (words.has(word)) return { value: Number(words.get(word)), kind, teen: word === "عشر" || word === "عشره" };
  }
  if (word === "و" || word === "and") return { kind: "and" };
  return null;
}

function underHundred(parts) {
  if (parts.length === 1 && ["digit", "small"].includes(parts[0].kind)) return parts[0].value;
  let joined = false;
  if (parts.length === 3 && parts[1].kind === "and") { joined = true; parts = [parts[0], parts[2]]; }
  if (parts.length !== 2 || parts.some(t => !["small", "digit"].includes(t.kind))) return null;
  const [a, b] = parts;
  if (a.kind === "digit" && b.kind === "digit") return null;
  if (!Number.isInteger(a.value) || !Number.isInteger(b.value)) return null;
  if (a.value >= 20 && a.value <= 90 && a.value % 10 === 0 && b.value >= 1 && b.value <= 9) return a.value + b.value;
  if (a.value >= 1 && a.value <= 9 && (b.teen && !joined || joined && b.value >= 20 && b.value <= 90 && b.value % 10 === 0)) return a.value + b.value;
  return null;
}

function underThousand(parts) {
  const index = parts.findIndex(t => t.kind === "hundred");
  if (index < 0) return underHundred(parts);
  let head = parts[index].value;
  if (index === 1 && head === 100 && parts[0].value >= 1 && parts[0].value <= 9) head *= parts[0].value;
  else if (index !== 0) return null;
  let tail = parts.slice(index + 1);
  if (tail[0]?.kind === "and") {
    if (tail.length === 1) return null;
    tail = tail.slice(1);
  }
  if (!tail.length) return head;
  const rest = underHundred(tail);
  return rest != null && rest < 100 ? head + rest : null;
}

function numericValue(parts) {
  let total = 0, start = 0, previousScale = Infinity;
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].kind !== "scale") continue;
    const scale = parts[i].value;
    if (scale >= previousScale) return null;
    const group = parts.slice(start, i);
    const coefficient = group.length ? underThousand(group) : start === 0 ? 1 : null;
    if (coefficient == null || coefficient <= 0 || coefficient >= scale) return null;
    total += coefficient * scale;
    previousScale = scale;
    start = i + 1;
    if (parts[start]?.kind === "and") start++;
  }
  if (start < parts.length) {
    const tail = underThousand(parts.slice(start));
    if (tail == null || tail >= previousScale) return null;
    total += tail;
  } else if (start === 0 || parts[parts.length - 1].kind === "and") return null;
  return Number.isFinite(total) && Math.abs(total) <= Number.MAX_SAFE_INTEGER ? total : null;
}

function parseQuantity(value) {
  if (value == null) return null;
  let text = String(value).trim().toLowerCase().replace(/(?:^|\s)(?:ال)?عُشْ?ر(?=\s|$)/g, " 0.1")
    .replace(/[\u064b-\u0652\u0670\u0640]/g, "")
    .replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 0x660)).replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 0x6f0))
    .replace(/[أإآٱ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/ؤ/g, "و").replace(/ئ/g, "ي")
    .replace(/٬/g, "").replace(/(?<=\d),(?=\d{3}(?:\D|$))/g, "").replace(/(?<=\d)[٫,](?=\d)/g, ".")
    .replace(/[−–]/g, "-").replace(/(?<=[a-z])-(?=[a-z])/g, " ")
    .replace(/\$/g, " usd ").replace(/€/g, " eur ").replace(/£/g, " gbp ").replace(/[%٪]/g, " percent ")
    .replace(/°c/g, " celsius ").replace(/°f/g, " fahrenheit ").replace(/°/g, " degree ")
    .replace(/(?<=\d)(?=[a-zء-ي])|(?<=[a-zء-ي])(?=\d)/g, " ").replace(/\s+/g, " ").trim()
    .replace(/[.!?؟،,؛;]+$/, "").trim();
  for (const [phrase, unit] of Object.entries(vocabulary.unitPhrases)) text = text.split(foldWord(phrase)).join(unit);
  // Do not discard operators, fractions, dates, or unknown punctuation.
  if (!text || /[^a-zء-ي0-9 .+\-]/.test(text)) return null;
  const words = text.trim().split(/ +/).flatMap(raw => {
    let word = withoutArticle(raw);
    const joined = !numericWord(word) && word.startsWith("و") && numericWord(withoutArticle(word.slice(1)));
    if (joined) word = withoutArticle(word.slice(1));
    return [...(joined ? ["و"] : []), ...(expansions[word]?.split(" ") ?? [word])];
  });
  let sign = 1;
  if (["-", "سالب", "ناقص", "negative", "minus", "+", "موجب", "positive", "plus"].includes(words[0])) {
    if (["-", "سالب", "ناقص", "negative", "minus"].includes(words[0])) sign = -1;
    words.shift();
  } else if (/^[+-]\d/.test(words[0] || "")) {
    if (words[0][0] === "-") sign = -1;
    words[0] = words[0].slice(1);
  }
  let unit = null, ended = false;
  const parts = [];
  for (const word of words) {
    let token = numberToken(word);
    if (token && units.has(word) && parts.length && numericValue([...parts, token]) == null) token = null;
    if (token) {
      if (ended) return null;
      parts.push(token);
    } else {
      const nextUnit = units.get(word);
      if (nextUnit) {
        if (unit && nextUnit !== unit) {
          if (unit === "year" && ["ce", "ah"].includes(nextUnit)) unit = nextUnit;
          else if (!(nextUnit === "year" && ["ce", "ah"].includes(unit))) return null;
        } else unit = nextUnit;
      } else if (!qualifiers.has(word)) return null;
      if (parts.length) ended = true;
    }
  }
  if (!parts.length) return null;
  const amount = numericValue(parts);
  return amount == null ? null : { value: sign * amount, unit };
}

// A null result leaves ordinary names and mathematical expressions to the text
// matcher. A recognized quantity never falls through to fuzzy word matching.
const compatibleUnits = (a, b) => !a || !b || a === b || a === "year" && ["ce", "ah"].includes(b) || b === "year" && ["ce", "ah"].includes(a);
function matchQuantity(typed, right, wrongs, questionText = "") {
  const expected = parseQuantity(right);
  if (!expected) return null;
  // Number words may themselves be a name (Eleven), or a unit (ثانية).
  if (!expected.unit && !/[0-9٠-٩۰-۹]/.test(right) && /وحده|ما (?:هو )?اسم|ما هي اسم|unit|\bname\b/.test(foldWord(String(questionText).toLowerCase()))) return null;
  const actual = parseQuantity(typed);
  if (!actual || actual.value !== expected.value || !compatibleUnits(actual.unit, expected.unit)) return false;
  // A bare number is ambiguous when an option differs only in currency/unit.
  return !wrongs.some(wrong => {
    const option = parseQuantity(wrong);
    return option && option.value === actual.value && compatibleUnits(option.unit, actual.unit);
  });
}

module.exports = { parseQuantity, matchQuantity };
