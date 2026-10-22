"use strict";

// Both protocols use the application's existing source. The legacy bank remains
// deployable so already-held matches finish safely. New invitations use the full
// original bank, including the media fields and all available paid categories.
const fs = require("node:fs");
const path = require("node:path");
const { free } = require("../src/economy");
const source = JSON.parse(fs.readFileSync(path.join(__dirname, "../../assets/questions.json"), "utf8"));
const questions = source.filter(q => free(q.Category)
  && [q.Q, q.R, q.W1, q.W2, q.W3].every(value => typeof value === "string" && value.trim())
  && new Set([q.R, q.W1, q.W2, q.W3]).size === 4)
  .map(q => ({ category: q.Category, text: q.Q, answers: [q.R, q.W1, q.W2, q.W3], level: Number(q.Level) || 0 }));
if (questions.length < 6) throw new Error("Insufficient valid free questions");
fs.writeFileSync(path.join(__dirname, "../src/stake_questions.json"), JSON.stringify(questions));
console.log(`Prepared ${questions.length} server questions.`);
const original = source.filter(q => typeof q.Category === "string" && !["دقة ملاحظة", "دقه ملاحظه"].includes(q.Category.trim())
  && [q.Q, q.R, q.W1, q.W2, q.W3].every(value => typeof value === "string" && value.trim()))
  .map(q => ({ category: q.Category.trim(), text: q.Q, answers: [q.R, q.W1, q.W2, q.W3],
    level: String(q.Level ?? "0"), img: typeof q.Img === "string" ? q.Img : "" }));
if (original.length < 12) throw new Error("Insufficient original board questions");
fs.writeFileSync(path.join(__dirname, "../src/original_stake_questions.json"), JSON.stringify(original));
console.log(`Prepared ${original.length} original board questions across ${new Set(original.map(q => q.category)).size} categories.`);
