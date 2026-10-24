"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0210.jsonl");
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

// --- سابق ولاحق ---
addEdit(12723, {
  Q: "في كرتون سابق ولاحق، ما اسم الشقيق الأصغر لريو تاكابا؟",
  R: "جيرومارو",
  W1: "كارلو",
  W2: "كاي",
  W3: "مايكل",
  Level: "5"
}, "حذف كلمة صغير الدخيلة وتثبيت اسم جيرومارو وتجنيس مشتتات شخصيات المسلسل");

addEdit(12726, {
  R: "الدكتور كمال",
  W1: "الدكتور عاصم",
  W2: "الدكتور زاهر",
  W3: "الدكتور مجدي",
  Level: "6"
}, "تثبيت اسم الدكتور كمال بحسب الدبلجة العربية وتجنيس مشتتات علماء الكرتون");

addEdit(12729, {
  R: "القرش الأبيض",
  W1: "السونيك",
  W2: "الماغنوم",
  W3: "الفأس الدوار",
  Level: "6"
}, "تثبيت اسم سيارة جي الشهيرة القرش الأبيض وتجنيس المشتتات");

// --- النمر المقنع ---
addEdit(12730, { Level: "1" }, "رياضة المصارعة الحرة في النمر المقنع بديهية", "difficulty");
addEdit(12731, { Level: "1" }, "قناع رأس النمر بديهي في النمر المقنع", "difficulty");
addEdit(12735, {
  R: "هناء",
  W1: "منى",
  W2: "ريم",
  W3: "ندى",
  Level: "2"
}, "تثبيت الاسم العربي هناء بحسب الدبلجة وحذف الاسم الياباني وتجنيس المشتتات");

addEdit(12736, {
  R: "سيارة النمر",
  W1: "سيارة الصقر",
  W2: "سيارة الشبح",
  W3: "سيارة البرق",
  Level: "1"
}, "تبسيط التسمية إلى سيارة النمر وتجنيس المشتتات");

addEdit(12738, {
  R: "حسان",
  W1: "عمر",
  W2: "شادي",
  W3: "باسم",
  Level: "2"
}, "تثبيت الاسم العربي حسان بحسب الدبلجة وحذف الاسم الياباني وتجنيس المشتتات");

addEdit(12740, {
  R: "كمال",
  W1: "صخر",
  W2: "عنتر",
  W3: "رمزي",
  Level: "4"
}, "حذف كلمة المصارع من البدائل وتجنيس الخيارات");

addEdit(12742, {
  R: "الأفعى",
  W1: "الثور الهائج",
  W2: "القرصان",
  W3: "الجزار",
  Level: "5"
}, "تبسيط لقب المصارع وحذف اللقب الأجنبي بايثون");

// --- ساندي بل ---
addEdit(12750, { Level: "1" }, "نشأة ساندي بل في اسكتلندا معرفة أساسية عامة", "difficulty");
addEdit(12751, {
  Q: "في مسلسل ساندي بل، ما اسم الكلب الأبيض الوفي الملازم لساندي؟",
  R: "أوليفر",
  W1: "ريكس",
  W2: "بوبي",
  W3: "باركي",
  Level: "1"
}, "حذف كلمة الكلب من الخيارات وتحديد اسم الكلب أوليفر");

addEdit(12754, {
  R: "النرجس البري",
  W1: "الياسمين",
  W2: "زنبق الوادي",
  W3: "الأقحوان",
  Level: "2"
}, "تبسيط وتجنيس أسماء الزهور لزهرة النرجس البري المفضلة لساندي");

addEdit(12755, { Level: "2" }, "شخصية كيتي شيرر المغرورة في ساندي بل مستوى شائع", "difficulty");
addEdit(12757, { Level: "2" }, "شاحنة الأخبار المتنقلة لساندي بل معرفة شائعة", "difficulty");
addEdit(12759, { Level: "1" }, "سفر ساندي بل إلى لندن معرفة جغرافية أساسية بالقصة", "difficulty");
addEdit(12763, { Level: "4" }, "لقاء ساندي بوالدتها في اليونان مستوى متوسط", "difficulty");
addEdit(12767, {
  R: "أليك",
  W1: "سام",
  W2: "توم",
  W3: "هاري",
  Level: "4"
}, "حذف كلمة الصحفي من الخيارات ومواءمة المستوى");

// --- سالي ---
addEdit(12770, { Level: "1" }, "معهد الآنسة منشن أشهر معهد في كرتون سالي", "difficulty");
addEdit(12771, { Level: "1" }, "عيش سالي مع والدها في الهند معرفة بديهية عامة", "difficulty");
addEdit(12772, {
  R: "رالف كروي",
  W1: "آرثر كروي",
  W2: "إدوارد كروي",
  W3: "جورج كروي",
  Level: "2"
}, "تبسيط الاسم وحذف الرتبة العسكرية من الخيارات");

addEdit(12773, { Level: "1" }, "الآنسة منشن مديرة المدرسة القاسية معرفة بديهية", "difficulty");
addEdit(12774, {
  R: "إميلي",
  W1: "جولي",
  W2: "كيتي",
  W3: "ماري",
  Level: "1"
}, "حذف كلمة الدمية وتجنيس الأسماء لدمية سالي المحبوبة إميلي");

addEdit(12775, { Level: "1" }, "خادمة المطبخ بيكي الصديقة المخلصة لسالي معرفة بديهية", "difficulty");
addEdit(12776, { Level: "2" }, "الطفلة الصغيرة لوتي التي تعتبر سالي كأم لها مستوى شائع", "difficulty");
addEdit(12777, { Level: "2" }, "إرمينغارد الطالبة الطيبة الوفية لسالي مستوى شائع", "difficulty");
addEdit(12778, { Level: "2" }, "لافينيا الطالبة المتنمرة المغرورة مستوى شائع", "difficulty");
addEdit(12779, { Level: "2" }, "مناجم الألماس استثمار والد سالي معرفة شائعة بالقصة", "difficulty");
addEdit(12781, { Level: "1" }, "نوم سالي في العلية الباردة معرفة بديهية شهيرة", "difficulty");
addEdit(12783, { Level: "4" }, "السيد كريسفورد الجار الثري صديق والد سالي مستوى متوسط", "difficulty");
addEdit(12784, { Level: "4" }, "الخادم الهندي المخلص رام داس مستوى متوسط", "difficulty");
addEdit(12785, { Level: "4" }, "الآنسة إميليا شقيقة الآنسة منشن الطيبة مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
