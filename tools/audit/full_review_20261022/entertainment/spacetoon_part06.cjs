"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0350.jsonl");
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

// --- بينكي وبرين ---
addEdit(12865, { Level: "4" }, "ظهور بينكي وبرين الأول في مسلسل الضاحكون مستوى متوسط", "difficulty");
addEdit(12869, { Level: "2" }, "إعلان تكرار المحاولة غداً أشهر نهاية متكررة لحلقات بينكي وبرين", "difficulty");

// --- بوكيمون ---
addEdit(12872, { Level: "1" }, "بلدة باليت مسقط رأس آش كيتشام معرفة بديهية بالأنمي", "difficulty");
addEdit(12873, { Level: "1" }, "ميستي مدربة بوكيمونات الماء معرفة بديهية", "difficulty");
addEdit(12874, { Level: "1" }, "بروك مدرب بوكيمونات الصخور معرفة بديهية", "difficulty");
addEdit(12876, {
  R: "أوك",
  W1: "إلم",
  W2: "بيرش",
  W3: "روان",
  Level: "1"
}, "حذف لقب البروفيسور وتجنيس علماء البوكيمون");

addEdit(12877, { Level: "1" }, "فريق الصاروخ العصابة الشهيرة معرفة بديهية", "difficulty");
addEdit(12878, { Level: "1" }, "القط الناطق مياوث معرفة بديهية", "difficulty");
addEdit(12879, { Level: "2" }, "صاعقة الرعد الهجمة الأيقونية لبيكاتشو معرفة شائعة", "difficulty");
addEdit(12880, { Level: "2" }, "سكويرتل سلحفاة الماء الأولية معرفة شائعة", "difficulty");
addEdit(12881, { Level: "2" }, "تشارمندر بوكيمون النار الأولي معرفة شائعة", "difficulty");
addEdit(12882, { Level: "2" }, "بلباسور بوكيمون العشب الأولي معرفة شائعة", "difficulty");
addEdit(12883, { Level: "2" }, "أوسمة القاعات شرط دخول الدوري معرفة شائعة", "difficulty");

addEdit(12885, {
  R: "جوي",
  W1: "كلارا",
  W2: "سارة",
  W3: "آن",
  Level: "2"
}, "حذف كلمة الممرضة وتجنيس الأسماء وتعديل المستوى إلى شائع");

addEdit(12886, { Level: "4" }, "توغيبي بوكيمون ميستي البيضوي مستوى متوسط", "difficulty");

addEdit(12887, {
  R: "جيني",
  W1: "كيت",
  W2: "ماريا",
  W3: "ندى",
  Level: "2"
}, "حذف كلمة الضابطة وتجنيس الأسماء وتعديل المستوى إلى شائع");

addEdit(12888, { Level: "4" }, "ميوثو البوكيمون المستنسخ مستوى متوسط", "difficulty");
addEdit(12889, { Level: "1" }, "حلم آش بأن يصبح أفضل مدرب بوكيمون معرفة بديهية عامة", "difficulty");

// --- الكابتن رابح ---
addEdit(12891, { Level: "1" }, "الكابتن رابح بطل المسلسل وهداف كولومبوس معرفة بديهية", "difficulty");
addEdit(12892, {
  R: "جنوى",
  W1: "روما",
  W2: "البندقية",
  W3: "تورينو",
  Level: "2"
}, "حذف كلمة مدينة وتجنيس المدن الإيطالية");

addEdit(12893, {
  R: "كولومبوس",
  W1: "الأجنحة",
  W2: "المجد",
  W3: "الصقور",
  Level: "1"
}, "حذف كلمة فريق وتجنيس المشتتات");

addEdit(12894, { Level: "2" }, "جوليان منافس رابح الأنيق معرفة شائعة", "difficulty");
addEdit(12897, {
  R: "برتيني",
  W1: "ماريو",
  W2: "ماركو",
  W3: "غسان",
  Level: "4"
}, "حذف كلمة المدرب وتجنيس الأسماء الإيطالية");

addEdit(12898, {
  R: "سان بوديستا",
  W1: "كولومبوس",
  W2: "الأجنحة",
  W3: "الصقور",
  Level: "4"
}, "حذف كلمة فريق من البدائل");

addEdit(12899, { Level: "2" }, "تسديدة الصقر الضربة الصاروخية لرابح معرفة شائعة", "difficulty");

addEdit(12901, {
  R: "الأجنحة",
  W1: "النصر",
  W2: "الأبطال",
  W3: "الصاعقة",
  Level: "4"
}, "حذف كلمة فريق وتجنيس المشتتات");

addEdit(12902, {
  R: "ماريو",
  W1: "جورجيو",
  W2: "باولو",
  W3: "فرانكو",
  Level: "5"
}, "حذف كلمة الحارس وتجنيس الأسماء");

addEdit(12908, { Level: "2" }, "شارة رابح بطل هداف معرفة كرتونية شائعة", "difficulty");

// --- بابار ---
addEdit(12910, { Level: "1" }, "بابار ملك الفيلة معرفة بديهية", "difficulty");
addEdit(12911, { Level: "1" }, "البدلة الخضراء الأنيقة لبابار معرفة بديهية", "difficulty");
addEdit(12912, {
  R: "سيليستفيل",
  W1: "الواحة الخضراء",
  W2: "وادي الزهور",
  W3: "مدينة النجوم",
  Level: "2"
}, "حذف كلمة مدينة وتجنيس المشتتات");

addEdit(12913, { Level: "2" }, "الملكة سيليست زوجة بابار معرفة شائعة", "difficulty");
addEdit(12914, { Level: "2" }, "آرثر الفيل الصغير المشاكس معرفة شائعة", "difficulty");
addEdit(12917, { Level: "4" }, "الملك راتاكسس ملك وحيد القرن مستوى متوسط", "difficulty");

addEdit(12918, {
  R: "زفير",
  W1: "كوكو",
  W2: "تيتو",
  W3: "بندق",
  Level: "2"
}, "حذف كلمة القرد وتجنيس الأسماء");

addEdit(12920, { Level: "2" }, "مقتل والدة بابار برصاص صياد قصة نشأة شهيرة", "difficulty");

addEdit(12921, {
  R: "كورنيليوس",
  W1: "بومبادور",
  W2: "ألكسندر",
  W3: "آرثر",
  Level: "4"
}, "حذف كلمة المستشار وتجنيس شخصيات المسلسل");

addEdit(12922, {
  R: "بومبادور",
  W1: "كورنيليوس",
  W2: "أندريه",
  W3: "لويس",
  Level: "5"
}, "حذف كلمة الوزير وتجنيس المشتتات");

addEdit(12924, { Level: "4" }, "منطاد الهواء الساخن وسيلة سفر بابار وسيليست مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
