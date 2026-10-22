"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0490.jsonl");
const lines = fs.readFileSync(batchFile, "utf8").trim().split(/\r?\n/).map(JSON.parse);

// 1. Mark all indices as reviewed
const reviewedSet = new Set(review.reviewedIndices);
for (const q of lines) reviewedSet.add(q.index);
review.reviewedIndices = [...reviewedSet].sort((a, b) => a - b);

// 2. Add edits
const editsMap = new Map(review.edits.map(e => [e.index, e]));

function addEdit(index, changes, reason, kind = "correction", sources = []) {
  const existing = editsMap.get(index);
  editsMap.set(index, {
    index,
    changes: { ...(existing?.changes || {}), ...changes },
    reason: [existing?.reason, reason].filter(Boolean).join("؛ "),
    kind: existing?.kind === "replacement" ? "replacement" : kind,
    sources: [...new Set([...(existing?.sources || []), ...sources])]
  });
}

// --- لوز وسكر خاتمة الفئة ---
addEdit(13000, {
  R: "كيريان",
  W1: "جاك",
  W2: "روبرت",
  W3: "جورج",
  Level: "4"
}, "حذف كلمة السيد وتجنيس الأسماء");

addEdit(13002, { Level: "4" }, "اتهام لوز بافتراس الماشية عقدة القصة مستوى متوسط", "difficulty");
addEdit(13007, { Level: "6" }, "رواية إرنست سيتون الأصلية مستوى متقدم", "difficulty");
addEdit(13008, { Level: "5" }, "لقب سيد الجبل الأسطوري للدب لوز مستوى متقدم", "difficulty");
addEdit(13009, { Level: "4" }, "نهاية لوز وسكر وسيرهما في الجبال مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
