"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0070.jsonl");
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

// --- هزيم الرعد ---
addEdit(12581, {
  Q: "في مسلسل هزيم الرعد، ما اسم الصديق القوي الضخم المخلص لهزيم الرعد؟",
  R: "صخر",
  W1: "تاسكي",
  W2: "جينبي",
  W3: "دانجو"
}, "تصحيح اسم الصديق الضخم لهزيم الرعد في الدبلجة العربية لمركز الزهرة (صخر وليس كوجي)");

addEdit(12583, {
  Q: "في مسلسل هزيم الرعد، ما اسم السفينة الفضائية الحربية الرئيسية التي يقودها هزيم الرعد في معاركه؟",
  R: "الصاعقة",
  W1: "النمر الإمبراطوري",
  W2: "التنين المجنح",
  W3: "شهاب الفضاء"
}, "استبدال الرمز الحيواني الغامض باسم سفينة هزيم الرعد الشهيرة الصاعقة");

addEdit(12586, {
  R: "كوكب ساكورا",
  W1: "كوكب تاي",
  W2: "كوكب رين",
  W3: "كوكب غوران"
}, "تصحيح التصحيف الإملائي لاسم كوكب الأميرة سيموني (ساكورا)");

addEdit(12588, { Level: "1" }, "أول كلمات شارة هزيم الرعد معرفة واسعة جداً وشائعة في سبيس تون", "difficulty");

// --- باتمان وسوبرمان ---
addEdit(12591, { Level: "4" }, "اسم ولادة سوبرمان كال إل مستوى متوسط", "difficulty");
addEdit(12602, { Level: "1" }, "روبن مساعد باتمان معرفة أساسية عامة", "difficulty");
addEdit(12604, { Level: "2" }, "كوكب كريبتون مدمر سوبرمان معرفة عامة مشهورة", "difficulty");
addEdit(12607, { Level: "4" }, "توماس واين والد باتمان مستوى متوسط", "difficulty");
addEdit(12608, { Level: "6" }, "الشرير بين كاسر ظهر باتمان مستوى متقدم", "difficulty");

// --- صقور الأرض ---
addEdit(12610, { Level: "1" }, "قادة صقور الأرض الثلاثة عبد الرحمن وحمزة وحكمت أبطال رئيسيون", "difficulty");
addEdit(12611, { Level: "4" }, "رمح التنين الأخضر لحمزة سلاح تاريخي متوسط الصعوبة", "difficulty");
addEdit(12616, { Level: "4" }, "الفارس توتشي وإنقاذ الرضيع في صقور الأرض مستوى متوسط", "difficulty");
addEdit(12623, { Level: "2" }, "زيارات عبد الرحمن الثلاث للكوخ قصة شهيرة في صقور الأرض", "difficulty");
addEdit(12629, { Level: "6" }, "سلالة هان الإمبراطورية في صقور الأرض مستوى متقدم", "difficulty");

// --- روبن هود ---
addEdit(12637, { Level: "4" }, "كليو شقيقة غيلبرت مستوى متوسط", "difficulty");
addEdit(12640, { Level: "6" }, "أسماء الإخوة الصغار في روبن هود مستوى متقدم", "difficulty");
addEdit(12649, { Level: "1" }, "توزيع روبن هود للأموال على الفقراء فكرة القصة الجوهرية والبديهية", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
