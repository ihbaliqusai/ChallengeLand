"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_06_0000.jsonl");
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

// --- Arabic TV Series Batch 1 (Category 06 Batch 0000: indices 13408 - 13477) ---

// Precision edit in Abu Issam's role (he is the barber/doctor, not the زعيم)
addEdit(13408, {
  Q: "في مسلسل باب الحارة، ما اللقب الشعبي الذي كان يُعرف به شوكت الداراني (أبو عصام) في حارة الضبع؟"
}, "تدقيق صفة أبو عصام كحكيم للحارة وليس زعيماً لها");

addEdit(13422, { Level: "4" }, "شخصية مطيع بك في مسلسل عائلتي وأنا دراما اجتماعية متوسطة الصعوبة", "difficulty");
addEdit(13423, { Level: "4" }, "شخصية عمر وتضحياته في مسلسل أحلام كبيرة", "difficulty");
addEdit(13424, { Level: "5" }, "شخصية ورد في مسلسل قلم حمرة", "difficulty");

// Tier 2 (Level 7) assignments for deep specific series lore
addEdit(13425, {
  Level: "7"
}, "تفاصيل قرية الخربة وعائلتي بو مالحة وبو قعقور مستوى متقدم (Tier 2)", "difficulty");

addEdit(13426, { Level: "4" }, "الزعيم أبو الحسن في أهل الراية", "difficulty");
addEdit(13427, { Level: "4" }, "نمط الخماسيات الدرامية في صرخة روح", "difficulty");

addEdit(13432, { Level: "4" }, "مهنة نجيب كأستاذ ومؤرخ جامعي في الفصول الأربعة", "difficulty");
addEdit(13433, { Level: "4" }, "ماجدة الابنة المحامية في الفصول الأربعة", "difficulty");
addEdit(13434, { Level: "5" }, "رقية الخادمة في بيت الفصول الأربعة", "difficulty");

addEdit(13440, { Level: "4" }, "صالح الدكنجي في ضيعة ضايعة", "difficulty");
addEdit(13441, { Level: "4" }, "سعدية زوجة المعلم عمر في ليالي الصالحية", "difficulty");
addEdit(13442, { Level: "4" }, "أمانة الذهب وحجة الدكان في ليالي الصالحية", "difficulty");
addEdit(13443, { Level: "4" }, "تجارة الأقمشة الحريرية في ليالي الصالحية", "difficulty");

addEdit(13444, { Level: "4" }, "أحمد الابن البكر المزارع في التغريبة الفلسطينية", "difficulty");
addEdit(13445, { Level: "4" }, "علي الحاصل على الدكتوراه في التغريبة الفلسطينية", "difficulty");
addEdit(13446, { Level: "4" }, "حسن الفدائي في التغريبة الفلسطينية", "difficulty");

addEdit(13449, { Level: "4" }, "ناقة البسوس سراب في حرب البسوس والزير سالم", "difficulty");
addEdit(13450, { Level: "4" }, "قرية ميت أبو غانم في ليالي الحلمية", "difficulty");
addEdit(13452, { Level: "4" }, "علي البدري ومساره السياسي في ليالي الحلمية", "difficulty");

addEdit(13454, { Level: "4" }, "وسيم وفادي ابنا جميل وهناء", "difficulty");
addEdit(13458, { Level: "5" }, "مريم الخادمة في عائلتي وأنا", "difficulty");

addEdit(13460, { Level: "4" }, "تخصص الطب البشري للابن رشيد في أحلام كبيرة", "difficulty");
addEdit(13461, { Level: "5" }, "شخصية حسن التائه في أحلام كبيرة", "difficulty");

// Tier 2 (Level 7) assignments
addEdit(13462, {
  Level: "7"
}, "قلم أحمر الشفاه في زنزانة ورد بمسلسل قلم حمرة رمزية درامية دقيقة (Tier 2)", "difficulty");

addEdit(13463, {
  Level: "7"
}, "شخصية الدكتور حازم الطبيب النفسي في قلم حمرة تفصيلة متقدمة (Tier 2)", "difficulty");

addEdit(13467, {
  Level: "7"
}, "تخصص الدكتور مشهور في مسلسل الخربة تفصيلة درامية دقيقة (Tier 2)", "difficulty");

addEdit(13468, { Level: "4" }, "رضا الحر بطل حارة ساروجة في أهل الراية", "difficulty");
addEdit(13469, { Level: "4" }, "قطر الندى في أهل الراية", "difficulty");

addEdit(13470, {
  Level: "7"
}, "شخصية دلال ومكيدتها في أهل الراية (Tier 2)", "difficulty");

addEdit(13474, { Level: "4" }, "صبيحة دابة أسعد في ضيعة ضايعة", "difficulty");

// Fix 13475 key wording (key is metal, not stone)
addEdit(13475, {
  Q: "في مسلسل التغريبة الفلسطينية، ما هو الرمز التراثي الذي احتفظ به أبو أحمد تأكيداً على التمسك بحق العودة؟",
  R: "مفتاح الدار القديم",
  W1: "ساعة جيبه الفضية",
  W2: "بندقية الثوار",
  W3: "سند ملكية الطابو"
}, "تصحيح وصف مفتاح الدار واستبعاد وصف الحجري المستحيل وتجنيس المشتتات");

// Tier 2 (Level 7) assignment
addEdit(13476, {
  Level: "7"
}, "فرس النعامة للحارث بن عباد في الزير سالم تاريخ تراثي درامي (Tier 2)", "difficulty");

// Fix 13477 cafe name in Layali El Helmeyya
addEdit(13477, {
  Q: "في مسلسل ليالي الحلمية، ما اسم المقهى الشعبي الشهير الذي يجتمع فيه أهالي الحلمية وتملكه عائلة السماحي؟",
  R: "مقهى السماحي",
  W1: "مقهى الفيشاوي",
  W2: "مقهى اللؤلؤة",
  W3: "مقهى الفنار",
  Level: "4"
}, "تصحيح اسم مقهى الحلمية إلى مقهى السماحي الشهير وتدقيق صياغة السؤال");

// Save review
review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
