"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { normalize, isCorrect } = require("../../../../functions/src/board_answer_matcher");

const list = JSON.parse(fs.readFileSync(path.join(__dirname, "unresolved_details.json"), "utf8"));
const fixes = [];

function escapeRegex(s) {
  return s.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
}

for (const x of list) {
  const q = x.current;
  if (!q) continue;
  const normQ = normalize(q.Q);
  const normR = normalize(q.R);
  if (normQ.includes(normR) && normR.length > 2) {
    let newQ = q.Q;
    const rRegex = new RegExp(escapeRegex(q.R), "gi");
    newQ = newQ.replace(rRegex, "...");
    const bareR = q.R.replace(/^ال/, "");
    if (bareR.length > 2 && bareR !== q.R) {
      const bareRegex = new RegExp(escapeRegex(bareR), "gi");
      newQ = newQ.replace(bareRegex, "...");
    }
    newQ = newQ.replace(/\.{2,}/g, "...").replace(/\.\.\.\s*يا\s*\.\.\./g, "...").replace(/«\s*\.\.\.\s*/g, "«... ").replace(/\s*\.\.\.\s*»/g, " ...»");
    if (newQ.startsWith("ما الأغنية") && !newQ.includes("أكمل")) {
      newQ = newQ.replace(/^(ما الأغنية التي (غنت فيها|تبدأ بـ|مطلعها|فيها):)/, "أكمل كلمات أغنية فيروز:");
    }
    if (newQ.startsWith("أي أغنية") && !newQ.includes("أكمل")) {
      newQ = newQ.replace(/^(أي أغنية (تبدأ بـ|مطلعها):)/, "أكمل مطلع أغنية فيروز:");
    }
    if (newQ.startsWith("من أي أغنية") && !newQ.includes("أكمل")) {
      newQ = newQ.replace(/^(من أي أغنية هذا المقطع:)/, "أكمل مقطع أغنية فيروز:");
    }
    fixes.push({ index: x.index, oldQ: q.Q, newQ, r: q.R, w: [q.W1, q.W2, q.W3] });
  }
}

console.log("Total fixes found:", fixes.length);
for (const f of fixes.slice(0, 10)) {
  console.log(f.index, "| OLD:", f.oldQ);
  console.log(f.index, "| NEW:", f.newQ);
  console.log("---");
}
