"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_05_0000.jsonl");
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

// --- Foreign Movies Batch 1 (Category 05 Batch 0000: indices 13208 - 13277) ---

// Consistent instruction tag in Braveheart
addEdit(13263, {
  Q: "في فيلم Braveheart، ما اسم الثائر الوطني الاسكتلندي قائد المقاومة ضد الاحتلال الإنجليزي؟ (اكتب بالإنجليزية)"
}, "توحيد توجيه اللغة الإنجليزية مع سائر أسئلة فئة الأفلام الأجنبية");

// Distractor standardization in Cast Away
addEdit(13253, {
  Q: "في فيلم Cast Away، ما اسم كرة الطائرة التي اتخذها تشاك نولاند صديقاً له في الجزيرة؟ (اكتب بالإنجليزية)"
}, "تصحيح تنوين الصديق في السؤال");

// Level alignments
addEdit(13208, { Level: "1" }, "تيتانيك وجاك داوسون معرفة سينمائية أيقونية شائعة", "difficulty");
addEdit(13209, { Level: "1" }, "فارس الظلام والجوكر معرفة شائعة", "difficulty");
addEdit(13210, { Level: "1" }, "العراب وفيتو كورليوني معرفة شائعة", "difficulty");
addEdit(13211, { Level: "1" }, "إنسيبشن ودوم كوب معرفة شائعة", "difficulty");
addEdit(13212, { Level: "1" }, "ماتريكس ونيو معرفة شائعة", "difficulty");
addEdit(13213, { Level: "1" }, "سيمبا والأسد الملك معرفة بديهية", "difficulty");
addEdit(13214, { Level: "1" }, "هوغوورتس وهاري بوتر معرفة بديهية", "difficulty");
addEdit(13216, { Level: "1" }, "أفاتار وكوكب باندورا معرفة بديهية", "difficulty");
addEdit(13217, { Level: "1" }, "غلادياتور ومكسيموس معرفة شائعة", "difficulty");
addEdit(13218, { Level: "1" }, "توي ستوري ووودي معرفة بديهية", "difficulty");
addEdit(13220, { Level: "1" }, "الخلاص من شاوشانك وآندي دوفرين معرفة شائعة", "difficulty");
addEdit(13221, { Level: "1" }, "جوراسيك بارك والديناصورات معرفة بديهية", "difficulty");
addEdit(13223, { Level: "1" }, "جاك سبارو وقراصنة الكاريبي معرفة بديهية", "difficulty");
addEdit(13224, { Level: "1" }, "بيتر باركر وسبايدرمان معرفة بديهية", "difficulty");
addEdit(13225, { Level: "1" }, "فرودو باغينز وسيد الخواتم معرفة شائعة", "difficulty");
addEdit(13226, { Level: "1" }, "دارث فيدر وحرب النجوم معرفة بديهية", "difficulty");
addEdit(13227, { Level: "1" }, "توني ستارك وآيرون مان معرفة بديهية", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
