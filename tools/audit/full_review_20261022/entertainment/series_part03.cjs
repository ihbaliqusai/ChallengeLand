"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_06_0140.jsonl");
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

// --- Arabic TV Series Batch 3 (Category 06 Batch 0140: indices 13548 - 13607) ---
// Final batch of Category 06: completes 100% of Arabic TV Series!

addEdit(13551, {
  Q: "في مسلسل ضيعة ضايعة، من هو مختار القرية الذي كان يلجأ إليه أسعد وجودة للتحكيم بينهما؟",
  R: "المختار عبد السلام",
  W1: "المساعد أبو نادر",
  W2: "صالح الدكنجي",
  W3: "الشرطي حسان"
}, "تدقيق صيغة السؤال وتبسيط أسماء الشخصيات");

addEdit(13566, {
  Q: "في مسلسل الزير سالم، ما اسم الفارس البكري الذي كان الصديق الصدوق والمخلص للزير سالم ورفض خيانته؟",
  R: "همام بن مرة",
  W1: "شرحبيل بن مرة",
  W2: "يزيد بن مرة",
  W3: "الحارث بن عباد"
}, "تبسيط خيارات شخصيات فرسان بكر في الزير سالم");

addEdit(13581, {
  Q: "في مسلسل أهل الراية، ما اسم المقاتل الشجاع قائد ثوار الغوطة الذي ساند رضا الحر؟",
  R: "أبو دياب",
  W1: "أبو شكري",
  W2: "أبو حمزة",
  W3: "أبو غازي"
}, "تبسيط خيارات قادة ثوار الغوطة في أهل الراية");

addEdit(13586, {
  Q: "في مسلسل الزير سالم، ما اسم الفارس والشاعر الشاب صاحب المعلقة الشهيرة الذي قاد قبيلة تغلب؟",
  R: "عمرو بن كلثوم",
  W1: "نويرة بن ربيعة",
  W2: "شرحبيل بن مرة",
  W3: "الحارث بن عباد"
}, "تبسيط خيارات فرسان تغلب في الزير سالم");

// Save review
review.edits = [...editsMap.values()].sort((a, b) => a - b);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
