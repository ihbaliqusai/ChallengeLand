"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0420.jsonl");
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

// --- باص المدرسة العجيب ---
addEdit(12930, { Level: "1" }, "اللون الأصفر لحافلة المدرسة بديهي", "difficulty");
addEdit(12931, { Level: "1" }, "مجال العلوم والأحياء والفضاء بديهي في باص المدرسة العجيب", "difficulty");

addEdit(12932, {
  R: "فريزل",
  W1: "سميث",
  W2: "كلارا",
  W3: "ماري",
  Level: "1"
}, "حذف كلمة المعلمة وتجنيس الأسماء");

addEdit(12933, { Level: "1" }, "السحلية ليز مرافقة المعلمة فريزل معرفة بديهية", "difficulty");
addEdit(12935, { Level: "1" }, "أرنولد الطالب القلق الحذر معرفة بديهية", "difficulty");
addEdit(12936, { Level: "2" }, "مقولة جازفوا وارتكبوا الأخطاء شعار المعلمة فريزل الأيقوني", "difficulty");
addEdit(12938, { Level: "2" }, "كارلوس صاحب النكات مستوى شائع", "difficulty");
addEdit(12940, { Level: "2" }, "واندا الطالبة الشجاعة مستوى شائع", "difficulty");
addEdit(12942, { Level: "4" }, "دوروثي آن ومقولة وفقاً لبحثي مستوى متوسط", "difficulty");
addEdit(12945, { Level: "4" }, "فيبي ومدرستها القديمة مستوى متوسط", "difficulty");

// --- بيل وسبستيان ---
addEdit(12950, {
  R: "بيل",
  W1: "لاسي",
  W2: "ديزي",
  W3: "ريكسي",
  Level: "1"
}, "حذف كلمة الكلبة وتجنيس الأسماء");

addEdit(12951, { Level: "2" }, "جبال البيرينيه بين فرنسا وإسبانيا مسرح بيل وسبستيان", "difficulty");
addEdit(12952, { Level: "1" }, "سبستيان بطل المسلسل معرفة بديهية", "difficulty");

addEdit(12953, {
  R: "سيزر",
  W1: "ألفريد",
  W2: "توماس",
  W3: "فيليب",
  Level: "2"
}, "حذف كلمة الجد وتجنيس الأسماء");

addEdit(12954, {
  R: "بوتشي",
  W1: "تومي",
  W2: "فوفو",
  W3: "لولو",
  Level: "2"
}, "حذف كلمة الجرو وتجنيس الأسماء");

addEdit(12955, { Level: "2" }, "بحث سبستيان عن والدته إيزابيل الفكرة المحورية", "difficulty");
addEdit(12957, { Level: "2" }, "أنجيلينا شقيقة سبستيان الكبرى بالرعاية", "difficulty");
addEdit(12962, { Level: "4" }, "الضابط غارسيا حارس الحدود مستوى متوسط", "difficulty");
addEdit(12968, { Level: "6" }, "سيسيل أوبري مؤلفة رواية بيل وسبستيان مستوى متقدم", "difficulty");

// --- فرانكلين ---
addEdit(12970, {
  R: "سلحفاة",
  W1: "بطة",
  W2: "أرنب",
  W3: "قندس",
  Level: "1"
}, "تبسيط الجواب وتجنيس الحيوانات لسلحفاة فرانكلين");

addEdit(12971, {
  R: "الدرقة (القوقعة)",
  W1: "الفرو الكثيف",
  W2: "الحراشف السميكة",
  W3: "الريش الملون",
  Level: "1"
}, "ضبط المصطلح وتجنيس الأغطية");

addEdit(12972, { Level: "1" }, "دبدوب الصديق الأقرب لفرانكلين معرفة بديهية", "difficulty");
addEdit(12974, { Level: "1" }, "حلزون الصديق البطيء لفرانكلين معرفة بديهية", "difficulty");
addEdit(12975, { Level: "1" }, "قندس بارع بناء السدود معرفة بديهية", "difficulty");

addEdit(12977, {
  R: "بومة",
  W1: "نمر",
  W2: "ثعلب",
  W3: "قندس",
  Level: "2"
}, "حذف كلمة الأستاذ وتجنيس حيوانات معلمي فرانكلين");

addEdit(12981, { Level: "2" }, "أرنوب الصديق السريع لفرانكلين معرفة شائعة", "difficulty");
addEdit(12986, { Level: "2" }, "ثعلوب الصديق اللطيف لفرانكلين معرفة شائعة", "difficulty");
addEdit(12989, { Level: "2" }, "شارة فرانكلين يستطيع عد الأعداد معرفة شائعة", "difficulty");

// --- لوز وسكر ---
addEdit(12990, {
  R: "دبان صغيران",
  W1: "سنجابان شقيان",
  W2: "قردان صغيران",
  W3: "ثعلبان بريان",
  Level: "1"
}, "تبسيط الجواب وتجنيس صغار الحيوانات");

addEdit(12991, {
  R: "بينتو",
  W1: "كوجي",
  W2: "تاكاشي",
  W3: "ريكاردو",
  Level: "2"
}, "تبسيط الاسم إلى بينتو وتجنيس المشتتات");

addEdit(12992, { Level: "2" }, "جبل تالاك مسرح أحداث لوز وسكر", "difficulty");
addEdit(12993, { Level: "2" }, "هيلين صديقة بينتو في لوز وسكر", "difficulty");

addEdit(12995, {
  R: "غريزلي",
  W1: "بيلا",
  W2: "لونا",
  W3: "نانا",
  Level: "2"
}, "حذف كلمة الدبة وتجنيس الأسماء");

addEdit(12996, {
  R: "كرو",
  W1: "بوبي",
  W2: "زيزو",
  W3: "ليو",
  Level: "2"
}, "حذف كلمة الكلب وتجنيس الأسماء");

addEdit(12997, {
  R: "بوناك",
  W1: "توم",
  W2: "سميث",
  W3: "ديك",
  Level: "4"
}, "حذف كلمة الصياد وتجنيس الأسماء");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
