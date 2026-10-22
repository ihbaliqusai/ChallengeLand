"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_06_0070.jsonl");
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

// --- Arabic TV Series Batch 2 (Category 06 Batch 0070: indices 13478 - 13547) ---

addEdit(13478, {
  Q: "في مسلسل باب الحارة، من هو صاحب مقهى الحارة القبضاي ذو المواقف الوطنية الشهمة؟",
  R: "أبو حاتم",
  W1: "أبو مرزوق",
  W2: "أبو خاطر",
  W3: "أبو بشير",
  Level: "1"
}, "تدقيق صيغة السؤال وخيارات أسماء الشخصيات دون حشو الألقاب");

addEdit(13479, {
  R: "مسلم",
  W1: "بشير",
  W2: "جميل",
  W3: "لطفي"
}, "تبسيط خيارات أسماء شباب حارة الضبع وتنقيتها من الحشو الإضافي");

// Tier 2 (Level 7) assignment
addEdit(13481, {
  Level: "7"
}, "مقهى الروضة بدمشق وملتقى المثقفين والأستاذ نجيب في الفصول الأربعة (Tier 2)", "difficulty");

addEdit(13483, {
  Q: "في مسلسل ضيعة ضايعة، ما اسم كاتب المخفر المشاغب الذي يلقبه أهل القرية بـ «عادل الفساد»؟",
  R: "عادل",
  W1: "سلوم",
  W2: "حسان",
  W3: "صالح"
}, "تدقيق السؤال واختصار خيارات أسماء شخصيات ضيعة ضايعة");

addEdit(13485, {
  Q: "في مسلسل ليالي الصالحية، من هو صديق المعلم عمر الوفي بائع النحاس الذي سانده في محنته؟",
  R: "المعلم صبحي",
  W1: "أبو أحمد الفران",
  W2: "خالد صانع الأحذية",
  W3: "أبو حاتم"
}, "تنقية خيارات شخصيات ليالي الصالحية");

addEdit(13486, {
  Q: "في مسلسل التغريبة الفلسطينية، ما اسم قرية قضاء حيفا الصامدة التي تنحدر منها عائلة أبو أحمد؟",
  R: "طيرة الكرمل",
  W1: "دير ياسين",
  W2: "كفر قاسم",
  W3: "الطنطورة",
  Level: "4"
}, "تدقيق اسم قرية طيرة الكرمل وتجنيس القرى الفلسطينية");

// Tier 2 (Level 7) assignment
addEdit(13487, {
  Level: "7"
}, "الجرو الهجرس ابن كليب وتربيته في السر بالزير سالم تفصيلة تراثية متقدمة (Tier 2)", "difficulty");

addEdit(13488, {
  Q: "في مسلسل الزير سالم، من هي شقيقة جساس وزوجة كليب الممزقة بين ثأر أخيها وزوجها؟",
  R: "جليلة بنت مرة",
  W1: "اليمامة بنت كليب",
  W2: "البسوس بنت منقذ",
  W3: "أسماء بنت مرة"
}, "تجنيس شخصيات نساء حرب البسوس في الزير سالم");

addEdit(13490, {
  Q: "في مسلسل جميل وهناء، ما اسم السكرتيرة الجديدة التي عينها جميل بالشركة لإثارة غيرة زوجته؟",
  R: "سمر",
  W1: "منى",
  W2: "سلوى",
  W3: "وفاء"
}, "تبسيط خيارات شخصيات سكرتيرات جميل وهناء");

addEdit(13492, {
  Q: "في مسلسل أحلام كبيرة، ما اسم الفتاة التي أحبها عمر وتخلى عن الارتباط بها للتفرغ لرعاية أسرته؟",
  R: "وفاء",
  W1: "منى",
  W2: "سناء",
  W3: "سميرة",
  Level: "4"
}, "تبسيط خيارات الأسماء في أحلام كبيرة");

addEdit(13493, {
  Q: "في مسلسل قلم حمرة، من هو المخرج الشاب الموهوب المغرم بورد وساندها في مشروعها؟",
  R: "تيم",
  W1: "حازم",
  W2: "أيهم",
  W3: "نزار",
  Level: "4"
}, "تبسيط خيارات الأسماء في قلم حمرة");

addEdit(13497, {
  Q: "في مسلسل باب الحارة، من هو الشاب الحداد بطل الحارة الذي اشتهر بقوته وشهامته وصناعته للسيوف؟",
  R: "خاطر",
  W1: "عصام",
  W2: "بشير",
  W3: "لطفي"
}, "تبسيط خيارات أبناء حارة الضبع");

addEdit(13507, {
  Q: "في مسلسل ليالي الصالحية، من هي الفتاة التي تزوجها المعلم عمر برضا زوجته سعدية لإنجاب ولد؟",
  R: "بهية",
  W1: "فاطمة",
  W2: "أمينة",
  W3: "زهرة",
  Level: "4"
}, "تبسيط خيارات الأسماء النسائية في ليالي الصالحية");

// Tier 2 (Level 7) assignment
addEdit(13511, {
  Level: "7"
}, "مقتل بجير بن الحارث بن عباد بشسع نعل كليب تفصيلة تاريخية وتراثية دقيقة (Tier 2)", "difficulty");

// Tier 2 (Level 7) assignment
addEdit(13523, {
  Level: "7"
}, "إخراج نضال سيجري الفني لمسلسل الخربة إلى جانب الليث حجو تاريخ فني متقدم (Tier 2)", "difficulty");

addEdit(13529, {
  Q: "في مسلسل باب الحارة، من هو الشاب خادم الحمام الذي افتدى الحارة والزعيم واستشهد برصاص الفرنسيين؟",
  R: "مسلم",
  W1: "خاطر",
  W2: "بشير",
  W3: "عصام",
  Level: "4"
}, "تبسيط الخيارات لسؤال شهادة مسلم");

// Tier 2 (Level 7) assignment
addEdit(13547, {
  Level: "7"
}, "يوم قضة ويوم تحلاق اللمم الموقعة الفاصلة في حرب البسوس والزير سالم (Tier 2)", "difficulty");

// Save review
review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
