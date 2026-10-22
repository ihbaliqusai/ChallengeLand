"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0140.jsonl");
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

// --- سلام دانك ---
addEdit(12664, { Level: "1" }, "عبارة أنا العبقري حسان أشهر لازماته البديهية في المسلسل", "difficulty");
addEdit(12667, { Level: "4" }, "أمل مديرة فريق الصقور مستوى متوسط", "difficulty");
addEdit(12668, { Level: "6" }, "لقب العجوز لماهر مستوى متقدم", "difficulty");

// --- عهد الأصدقاء ---
addEdit(12688, { Level: "4" }, "زواج روميو من بيانكا شقيقة ألفريدو معرفة شائعة لدى متابعي المسلسل", "difficulty");
addEdit(12689, { Level: "1" }, "أول كلمات شارة عهد الأصدقاء حلمنا نهار نهارنا عمل شهيرة جداً", "difficulty");

// --- الكابتن ماجد ---
addEdit(12702, { Level: "2" }, "عمر وتصدياته بوجهه أشهر مشاهد الكابتن ماجد الكوميدية", "difficulty");
addEdit(12707, { Level: "4" }, "احتراف ماجد في نادي برشلونة الإسباني مستوى متوسط", "difficulty");
addEdit(12708, { Level: "4" }, "احتراف بسام في نادي يوفنتوس الإيطالي مستوى متوسط", "difficulty");
addEdit(12709, { Level: "1" }, "مقولة الكرة صديقتي الشعار الأشهر للكابتن ماجد في كل الأجزاء", "difficulty");

// --- سابق ولاحق ---
addEdit(12712, {
  R: "السونيك",
  W1: "الماغنوم",
  W2: "الإعصار",
  W3: "النمر السريع"
}, "تثبيت اسم سيارة سابق السونيك وتجنيس مشتتات سيارات المسلسل");

addEdit(12713, {
  R: "الماغنوم",
  W1: "السونيك",
  W2: "الفأس الدوار",
  W3: "ترايدغر"
}, "تثبيت اسم سيارة لاحق الماغنوم وتجنيس مشتتات السيارات");

addEdit(12718, { Level: "4" }, "سيارة إعصار ماغنوم سايكلون ماغنوم مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
