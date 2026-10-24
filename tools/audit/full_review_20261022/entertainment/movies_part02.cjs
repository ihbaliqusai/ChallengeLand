"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_04_0070.jsonl");
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

// --- Arabic Movies Batch 2 (Category 04 Batch 0070: 13080 - 13149) ---
addEdit(13080, { Level: "2" }, "فيلم ثقافي كوميديا اجتماعية شهيرة", "difficulty");
addEdit(13081, { Level: "2" }, "شورت وفانلة وكاب معرفة شائعة", "difficulty");
addEdit(13082, { Level: "2" }, "محامي خلع كوميديا اجتماعية معرفة شائعة", "difficulty");
addEdit(13083, { Level: "2" }, "أحلى الأوقات دراما اجتماعية شهيرة", "difficulty");
addEdit(13084, { Level: "2" }, "الساحر لمحمود عبد العزيز معرفة سينمائية شائعة", "difficulty");
addEdit(13085, { Level: "2" }, "أيام السادات لأحمد زكي سيرة تاريخية شائعة جداً", "difficulty");
addEdit(13086, { Level: "2" }, "جواز بقرار جمهوري معرفة شائعة", "difficulty");
addEdit(13087, { Level: "2" }, "طباخ الريس لطلعت زكريا معرفة شائعة", "difficulty");
addEdit(13088, { Level: "2" }, "إتش دبور لأحمد مكي معرفة شائعة", "difficulty");
addEdit(13089, { Level: "2" }, "بوشكاش لمحمد سعد معرفة شائعة", "difficulty");
addEdit(13090, { Level: "2" }, "كابتن هيما لتامر حسني معرفة شائعة", "difficulty");
addEdit(13091, { Level: "2" }, "مسجون ترانزيت لأحمد عز ونور الشريف معرفة شائعة", "difficulty");
addEdit(13092, { Level: "2" }, "دكان شحاتة لعمرو سعد معرفة شائعة", "difficulty");
addEdit(13093, { Level: "2" }, "عمر وسلمى 3 معرفة شائعة", "difficulty");
addEdit(13095, { Level: "2" }, "بوبوس لعادل إمام معرفة شائعة", "difficulty");
addEdit(13096, { Level: "2" }, "عيال حبيبة لحمادة هلال معرفة شائعة", "difficulty");
addEdit(13097, { Level: "2" }, "ابن عز لعلاء ولي الدين معرفة شائعة", "difficulty");
addEdit(13098, { Level: "2" }, "هيبتا: المحاضرة الأخيرة رواية وفيلم شهير جداً", "difficulty");
addEdit(13099, { Level: "2" }, "حرب كرموز لأمير كرارة معرفة شائعة", "difficulty");

addEdit(13100, { Level: "4" }, "أرض الخوف للمخرج داود عبد السيد مستوى متوسط", "difficulty");
addEdit(13101, { Level: "2" }, "هي فوضى للمخرج يوسف شاهين وخالد يوسف معرفة سينمائية شائعة", "difficulty");
addEdit(13102, { Level: "2" }, "حين ميسرة لخالد يوسف معرفة سينمائية شائعة", "difficulty");
addEdit(13103, { Level: "4" }, "تراب الماس لأحمد مراد ومروان حامد مستوى متوسط", "difficulty");
addEdit(13104, { Level: "4" }, "أسماء لهند صبري وعمرو سلامة مستوى متوسط", "difficulty");
addEdit(13105, { Level: "4" }, "ساعة ونص دراما اليوم الواحد مستوى متوسط", "difficulty");
addEdit(13106, { Level: "4" }, "اشتباك لمحمد دياب مستوى متوسط", "difficulty");
addEdit(13107, { Level: "4" }, "شيخ جاكسون لأحمد الفيشاوي وعمرو سلامة مستوى متوسط", "difficulty");
addEdit(13108, { Level: "4" }, "الأصليين لمروان حامد مستوى متوسط", "difficulty");
addEdit(13109, { Level: "4" }, "وجدة لهيفاء المنصور مستوى متوسط", "difficulty");
addEdit(13110, { Level: "4" }, "كفرناحوم لنادين لبكي والترشح للأوسكار مستوى متوسط", "difficulty");
addEdit(13111, { Level: "4" }, "يوم الدين لأبو بكر شوقي ومهرجان كان مستوى متوسط", "difficulty");
addEdit(13112, { Level: "4" }, "ريش لعمر الزهيري وجائزة مهرجان كان مستوى متوسط", "difficulty");
addEdit(13113, { Level: "4" }, "علي معزة وإبراهيم لشريف البنداري مستوى متوسط", "difficulty");
addEdit(13114, { Level: "4" }, "رسائل البحر لداود عبد السيد وآسر ياسين مستوى متوسط", "difficulty");
addEdit(13115, { Level: "2" }, "أوقات فراغ فيلم شبابي شهير معرفة شائعة", "difficulty");
addEdit(13116, { Level: "4" }, "بحب السيما للمخرج أسامة فوزي مستوى متوسط", "difficulty");
addEdit(13117, { Level: "4" }, "الجنة الآن لهاني أبو أسعد والغولدن غلوب مستوى متوسط", "difficulty");
addEdit(13118, { Level: "4" }, "باب الشمس للمخرج يسري نصر الله ملحمة فلسطينية مستوى متوسط", "difficulty");
addEdit(13119, { Level: "4" }, "علي زاوا لنبيل عيوش سينما مغربية مستوى متوسط", "difficulty");

addEdit(13130, { Level: "4" }, "تفاصيل أحداث صعيدي في الجامعة الأمريكية مستوى متوسط", "difficulty");
addEdit(13131, { Level: "4" }, "تفاصيل أحداث فيلم الناظر مستوى متوسط", "difficulty");
addEdit(13132, { Level: "4" }, "تفاصيل أحداث فيلم عسل أسود مستوى متوسط", "difficulty");
addEdit(13133, { Level: "4" }, "تفاصيل أحداث الفيل الأزرق مستوى متوسط", "difficulty");
addEdit(13134, { Level: "4" }, "تفاصيل أحداث كيرة والجن مستوى متوسط", "difficulty");
addEdit(13135, { Level: "4" }, "تفاصيل أحداث ولاد رزق مستوى متوسط", "difficulty");
addEdit(13136, { Level: "4" }, "تفاصيل أحداث تيتو مستوى متوسط", "difficulty");
addEdit(13137, { Level: "4" }, "تفاصيل أحداث مافيا مستوى متوسط", "difficulty");
addEdit(13138, { Level: "4" }, "تفاصيل أحداث ملاكي إسكندرية مستوى متوسط", "difficulty");
addEdit(13139, { Level: "4" }, "تفاصيل أحداث فيلم الجزيرة مستوى متوسط", "difficulty");
addEdit(13140, { Level: "4" }, "تفاصيل أحداث عمارة يعقوبيان مستوى متوسط", "difficulty");
addEdit(13141, { Level: "4" }, "تفاصيل أحداث واحد من الناس مستوى متوسط", "difficulty");
addEdit(13142, { Level: "4" }, "تفاصيل أحداث كدة رضا مستوى متوسط", "difficulty");
addEdit(13143, { Level: "4" }, "تفاصيل أحداث ولاد العم مستوى متوسط", "difficulty");
addEdit(13144, { Level: "4" }, "تفاصيل أحداث 1000 مبروك مستوى متوسط", "difficulty");
addEdit(13145, { Level: "4" }, "تفاصيل أحداث لا تراجع ولا استسلام مستوى متوسط", "difficulty");
addEdit(13146, { Level: "4" }, "تفاصيل أحداث فيلم الممر مستوى متوسط", "difficulty");
addEdit(13147, { Level: "4" }, "تفاصيل أحداث تراب الماس مستوى متوسط", "difficulty");
addEdit(13148, { Level: "4" }, "تفاصيل أحداث فوي فوي فوي مستوى متوسط", "difficulty");
addEdit(13149, { Level: "4" }, "تفاصيل أحداث أرض الخوف والرسائل المشفرة مستوى متوسط", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
