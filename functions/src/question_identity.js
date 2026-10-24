"use strict";

const { createHash } = require("node:crypto");

// Deliberately independent of category, difficulty, answer order and bank index.
// Media/club paths distinguish template prompts such as "Who is this player?".
function normalize(value) {
  return String(value || "").normalize("NFKC").toLowerCase()
    .replace(/[\u0640\u064b-\u065f\u0670\u06d6-\u06ed]/g, "")
    .replace(/[أإآٱ]/g, "ا").replace(/ى/g, "ي")
    .replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 0x660))
    .replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 0x6f0))
    // An explicit punctuation set preserves emoji clues, including characters
    // newer than the Unicode tables on older Android/JDK releases.
    .replace(/[\u0000-\u0020\u007f\u00a0\u1680\u2000-\u200b\u2028\u2029\u202f\u205f\u3000\ufeff؟?!،؛;'"“”‘’«»()\[\]{}\\…]/g, "");
}

function questionKey(q) {
  const text = normalize(q.Q ?? q.text);
  const img = String(q.Img ?? q.img ?? "").trim();
  const clubs = (q.ClubPath ?? q.clubPath ?? []).map(normalize).join(">");
  return createHash("sha256").update(`q1|${text}|${img}|${clubs}`, "utf8").digest("hex");
}

module.exports = { questionKey, normalize };
