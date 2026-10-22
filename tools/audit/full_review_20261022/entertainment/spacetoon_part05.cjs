"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0280.jsonl");
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

// --- دروب ريمي ---
addEdit(12790, { Level: "1" }, "عزف ريمي على الهارب والقيثارة معرفة شائعة", "difficulty");
addEdit(12791, { Level: "1" }, "القرد جوليكور في فرقة فيتالس معرفة شائعة", "difficulty");
addEdit(12792, { Level: "1" }, "العم فيتالس مؤسس الفرقة معرفة بديهية بالمسلسل", "difficulty");
addEdit(12793, {
  R: "كابي",
  W1: "زيربينو",
  W2: "دولتشي",
  W3: "ريكس",
  Level: "1"
}, "حذف كلمة الكلب وتجنيس كلاب فرقة فيتالس وتعديل المستوى إلى بديهي");

addEdit(12794, { Level: "1" }, "الفتى ماتيا عازف الكمان رفيق ريمي معرفة بديهية", "difficulty");
addEdit(12795, {
  R: "شافانون",
  W1: "تولوز",
  W2: "ليل",
  W3: "ليون",
  Level: "2"
}, "حذف كلمة قرية وتثبيت اسم شافانون ريف فرنسا");

addEdit(12796, { Level: "1" }, "الأم باربارين مربية ريمي معرفة بديهية", "difficulty");
addEdit(12797, { Level: "2" }, "الفتى آرثر المقعد شقيق ريمي معرفة شائعة", "difficulty");
addEdit(12798, { Level: "2" }, "السيدة ميليغان والدة ريمي النبيلة معرفة شائعة", "difficulty");
addEdit(12800, { Level: "1" }, "أغنية أمي كم أهواها أشهر أغنية لريمي بديهياً", "difficulty");
addEdit(12801, { Level: "2" }, "السيد كاسبر مستغل الأطفال في باريس معرفة شائعة", "difficulty");
addEdit(12804, { Level: "4" }, "وصية إلى الأمام دائماً مقولة العم فيتالس الشهيرة", "difficulty");
addEdit(12806, {
  R: "روسيت",
  W1: "بيلا",
  W2: "زهرة",
  W3: "نجمة",
  Level: "5"
}, "تثبيت اسم البقرة روسيت بحسب القصة الأصلية والدبلجة وتجنيس المشتتات");

// --- لحن الحياة ---
addEdit(12810, { Level: "1" }, "مدينة سالزبورغ النمساوية مسرح أحداث لحن الحياة", "difficulty");
addEdit(12811, { Level: "1" }, "الآنسة صفاء مربية الأطفال معرفة بديهية", "difficulty");
addEdit(12812, { Level: "1" }, "السيد ربيع والد الأطفال معرفة بديهية", "difficulty");
addEdit(12813, { Level: "1" }, "سبعة أطفال في عائلة السيد ربيع معرفة بديهية", "difficulty");
addEdit(12815, { Level: "1" }, "الغناء والموسيقى وسيلة صفاء لكسب الأطفال", "difficulty");
addEdit(12816, { Level: "1" }, "نزهات مروج الجبال نشاط صفاء والأطفال المفضل", "difficulty");
addEdit(12819, { Level: "2" }, "استخدام السيد ربيع للصافرة البحرية لاستدعاء الأطفال معرفة شائعة", "difficulty");
addEdit(12820, { Level: "2" }, "خياطة ملابس اللعب من الستائر القديمة مشهد أيقوني شهير", "difficulty");

// --- حكايات ما أحلاها ---
addEdit(12830, { Level: "1" }, "الأخوان غريم جامعو الحكايات معرفة عالمية بديهية", "difficulty");
addEdit(12831, { Level: "1" }, "حذاء سندريلا الزجاجي معرفة خرافية بديهية", "difficulty");
addEdit(12832, { Level: "1" }, "سبعة أقزام لبياض الثلج معرفة بديهية", "difficulty");
addEdit(12833, { Level: "1" }, "التفاحة الحمراء المسمومة لبياض الثلج معرفة بديهية", "difficulty");
addEdit(12834, { Level: "1" }, "زيارة ليلى لجدتها المريضة معرفة بديهية", "difficulty");
addEdit(12835, { Level: "2" }, "حيوانات بريمن الأربعة: حمار وكلب وقط وديك معرفة شائعة", "difficulty");
addEdit(12836, { Level: "2" }, "الكرة الذهبية للأميرة في حكاية الأمير الضفدع", "difficulty");
addEdit(12837, { Level: "1" }, "عقلة الإصبع وحجمه الصغير معرفة بديهية", "difficulty");
addEdit(12838, { Level: "4" }, "لقب كونت كاراباس للقط ذو الحذاء مستوى متوسط", "difficulty");
addEdit(12839, { Level: "2" }, "مغزل النسيج في حكاية الأميرة النائمة معرفة شائعة", "difficulty");
addEdit(12840, { Level: "1" }, "منزل الكعك والحلويات لهانسل وغريتل معرفة بديهية", "difficulty");
addEdit(12841, { Level: "4" }, "التصاق الطامعين بريش الإوزة الذهبية مستوى متوسط", "difficulty");
addEdit(12842, { Level: "4" }, "تحويل القش لذهب للقزم رامبلستيلتسكين مستوى متوسط", "difficulty");
addEdit(12844, { Level: "4" }, "ابتلاع الذئب للطباشير والعسل لتنعيم صوته مستوى متوسط", "difficulty");
addEdit(12845, { Level: "2" }, "حبس رابونزيل في البرج بلا أبواب معرفة شائعة", "difficulty");
addEdit(12846, { Level: "4" }, "حبة البازلاء تحت عشرين مرتبة وفراشاً مستوى متوسط", "difficulty");
addEdit(12849, { Level: "2" }, "شارة حكايات ما أحلاها في يوم من الأيام معرفة شائعة", "difficulty");

// --- بينكي وبرين ---
addEdit(12850, { Level: "1" }, "بينكي وبرين فأرا تجارب معرفة بديهية بالرسوم", "difficulty");
addEdit(12851, { Level: "1" }, "السيطرة على العالم الهدف اليومي لبرين معرفة بديهية", "difficulty");
addEdit(12852, { Level: "2" }, "مختبرات أكمي مقر بينكي وبرين معرفة شائعة", "difficulty");
addEdit(12853, { Level: "1" }, "رأس برين الضخم وعبقريته معرفة بديهية", "difficulty");
addEdit(12855, { Level: "1" }, "عبارة سنحاول السيطرة على العالم أشهر لازمة بالمسلسل", "difficulty");
addEdit(12856, { Level: "1" }, "بينكي الفأر الطويل النحيف معرفة بديهية", "difficulty");
addEdit(12857, { Level: "4" }, "الفأر المنافس سنوبول مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
