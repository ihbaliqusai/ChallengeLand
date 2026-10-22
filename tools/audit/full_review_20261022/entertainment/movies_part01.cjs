"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_04_0000.jsonl");
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

// --- Arabic Movies Batch 1 (Category 04 Batch 0000: 13010 - 13079) ---
addEdit(13015, { Level: "2" }, "فيلم الفيل الأزرق دراما نفسية معرفة سينمائية شائعة", "difficulty");
addEdit(13017, { Level: "2" }, "فيلم كيرة والجن ملحمة تاريخية معرفة شائعة", "difficulty");
addEdit(13027, { Level: "2" }, "فيلم فوي فوي فوي معرفة سينمائية حديثة شائعة", "difficulty");
addEdit(13032, { Level: "2" }, "فيلم عمارة يعقوبيان رواية وفيلم معرفة شائعة", "difficulty");
addEdit(13039, { Level: "2" }, "فيلم إبراهيم الأبيض دراما تشويقية معرفة شائعة", "difficulty");
addEdit(13042, { Level: "2" }, "فيلم ملاكي إسكندرية غموض وجريمة معرفة شائعة", "difficulty");
addEdit(13043, { Level: "2" }, "فيلم حرب أطاليا تشويق وجريمة معرفة شائعة", "difficulty");
addEdit(13044, { Level: "2" }, "فيلم واحد من الناس دراما وانتقام معرفة شائعة", "difficulty");
addEdit(13047, { Level: "2" }, "فيلم الشبح غموض وفقدان ذاكرة معرفة شائعة", "difficulty");
addEdit(13053, { Level: "2" }, "فيلم كازابلانكا أكشن وسرقة معرفة شائعة", "difficulty");
addEdit(13055, { Level: "2" }, "فيلم العارف حرب سيبرانية معرفة شائعة", "difficulty");
addEdit(13057, { Level: "2" }, "فيلم ولاد رزق 2 عودة أسود الأرض معرفة شائعة", "difficulty");
addEdit(13058, { Level: "2" }, "فيلم ولاد رزق 3 القاضية معرفة شائعة", "difficulty");
addEdit(13059, { Level: "2" }, "فيلم الفيل الأزرق 2 معرفة شائعة", "difficulty");
addEdit(13060, { Level: "2" }, "فيلم الجزيرة 2 معرفة شائعة", "difficulty");
addEdit(13061, { Level: "2" }, "فيلم الخلية مكافحة إرهاب معرفة شائعة", "difficulty");
addEdit(13062, { Level: "2" }, "فيلم هروب اضطراري معرفة شائعة", "difficulty");
addEdit(13070, { Level: "2" }, "فيلم سهر الليالي دراما اجتماعية معرفة شائعة", "difficulty");
addEdit(13074, { Level: "2" }, "فيلم الرهينة أكشن وتشويق معرفة شائعة", "difficulty");
addEdit(13077, { Level: "2" }, "فيلم المصلحة صراع أمني في سيناء معرفة شائعة", "difficulty");
addEdit(13078, { Level: "2" }, "فيلم كباريه دراما اليوم الواحد معرفة شائعة", "difficulty");
addEdit(13079, { Level: "2" }, "فيلم الفرح دراما اجتماعية معرفة شائعة", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
