"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_05_0070.jsonl");
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

// --- Foreign Movies Batch 2 (Category 05 Batch 0070: indices 13278 - 13347) ---

// Level and question polish
addEdit(13280, { Level: "2" }, "هارفي دينت والمدعي العام في غوثام معرفة شائعة", "difficulty");
addEdit(13281, { Level: "1" }, "الحبة الحمراء في ماتريكس معرفة بديهية عامة", "difficulty");
addEdit(13285, { Level: "2" }, "ماركوس أوريليوس في غلادياتور معرفة شائعة", "difficulty");
addEdit(13287, { Level: "1" }, "نجمة الموت في حرب النجوم معرفة بديهية عامة", "difficulty");
addEdit(13292, { Level: "1" }, "صخرة العزة برايد روك في الأسد الملك معرفة بديهية عامة", "difficulty");
addEdit(13293, { Level: "1" }, "قلب المحيط في فيلم تيتانيك معرفة بديهية عامة", "difficulty");
addEdit(13294, { Level: "1" }, "قاعدة نادي القتال الأولى معرفة بديهية عامة", "difficulty");
addEdit(13316, { Level: "4" }, "نيكولا تسلا في فيلم برستيج مستوى متوسط", "difficulty");
addEdit(13325, { Level: "4" }, "نشيد المارسيليز في فيلم كازابلانكا مستوى متوسط", "difficulty");
addEdit(13328, { Level: "2" }, "قرية كورليوني في صقلية معرفة سينمائية شائعة", "difficulty");
addEdit(13337, { Level: "4" }, "مختبر لوس ألاموس وتجربة ترينيتي في أوبنهايمر مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
