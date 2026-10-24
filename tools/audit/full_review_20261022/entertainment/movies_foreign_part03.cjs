"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_05_0140.jsonl");
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

// --- Foreign Movies Batch 3 (Category 05 Batch 0140: indices 13348 - 13407) ---
// Finalizes Category 05 (أفلام أجنبية) in Entertainment to 100% completion.

addEdit(13349, { Level: "4" }, "كلمة روزبد في المواطن كين معرفة سينمائية كلاسيكية", "difficulty");
addEdit(13357, { Level: "2" }, "كلمة ريدرام معكوسة في البريق معرفة شائعة", "difficulty");
addEdit(13366, { Level: "4" }, "تحية بونجورنو برينشبيسا في الحياة جميلة معرفة سينمائية شائعة", "difficulty");
addEdit(13374, { Level: "4" }, "جبل رشمور في فيلم شمالاً إلى الشمال الغربي مستوى متوسط", "difficulty");
addEdit(13378, { Level: "2" }, "ميناء العقبة في لورنس العرب معرفة شائعة عربياً وعالمياً", "difficulty");
addEdit(13382, { Level: "4" }, "الروليت الروسي في صائد الغزلان مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
