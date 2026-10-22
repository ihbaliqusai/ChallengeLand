"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_04_0140.jsonl");
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

// --- Arabic Movies Batch 3 (Category 04 Batch 0140: 13150 - 13207) - Final Batch of Arabic Cinema ---
addEdit(13150, { Level: "4" }, "فيلم ثقافي تفاصيل حبكة درامية متقدمة", "difficulty");
addEdit(13151, { Level: "4" }, "سهر الليالي ذروة اعترافات شاليه الإسكندرية", "difficulty");
addEdit(13152, { Level: "4" }, "أحلى الأوقات علبة البسبوسة وذكريات شبرا", "difficulty");
addEdit(13153, { Level: "4" }, "بحب السيما تفاصيل قصة الطفل نعيم", "difficulty");
addEdit(13154, { Level: "4" }, "آسف على الإزعاج صدمة فريدة وخيال المريض", "difficulty");
addEdit(13155, { Level: "4" }, "هي فوضى مشهد اقتحام قسم شرطة شبرا", "difficulty");
addEdit(13156, { Level: "4" }, "حين ميسرة مأساة ضياع الطفل في الأتوبيس", "difficulty");
addEdit(13157, { Level: "4" }, "كباريه تردد الانتحاري داخل الكباريه", "difficulty");
addEdit(13158, { Level: "4" }, "الفرح إخفاء جثة الجدة في الفرح", "difficulty");
addEdit(13159, { Level: "4" }, "رسائل البحر تفاصيل درامية مستوى متوسط", "difficulty");
addEdit(13160, { Level: "4" }, "أسماء ظهور مريضة الإيدز في برنامج تلفزيوني", "difficulty");
addEdit(13161, { Level: "4" }, "كفرناحوم رعاية الطفل زين للرضيع الإفريقي يوناس", "difficulty");
addEdit(13162, { Level: "4" }, "وجدة حلم الدراجة الخضراء في الرياض", "difficulty");
addEdit(13163, { Level: "4" }, "يوم الدين رحلة بشاي من مستعمرة الجذام إلى قنا", "difficulty");
addEdit(13164, { Level: "4" }, "ريش تحول الأب لدجاجة ومعاناة الأم", "difficulty");
addEdit(13165, { Level: "4" }, "اشتباك صراع عربة الترحيلات المغلقة", "difficulty");
addEdit(13166, { Level: "4" }, "شيخ جاكسون الأزمة النفسية للشيخ خالد", "difficulty");
addEdit(13167, { Level: "4" }, "الأصليين تفاصيل جهاز التجسس وبصمة العين", "difficulty");
addEdit(13168, { Level: "4" }, "علي زاوا مراسم دفن الطفل المتشرد في الجزيرة", "difficulty");

addEdit(13169, { Level: "6" }, "عرق البلح تسلق أحمد للنخلة وقطع النخيل", "difficulty");
addEdit(13170, { Level: "6" }, "جنة الشياطين صحبة جثة طبل في حانات القاهرة", "difficulty");
addEdit(13171, { Level: "6" }, "الآخر ليوسف شاهين مأساة الحبيبين بالأقصر", "difficulty");
addEdit(13172, { Level: "6" }, "سكوت ح نصور ليوسف شاهين ولطيفة", "difficulty");
addEdit(13173, { Level: "6" }, "باب الشمس لقاء خليل ونهيلة في مغارة باب الشمس", "difficulty");
addEdit(13174, { Level: "6" }, "الجنة الآن تراجع خالد واستمرار سعيد", "difficulty");
addEdit(13175, { Level: "6" }, "بنتين من مصر أزمات العنوسة وتنازلات العمل", "difficulty");
addEdit(13176, { Level: "6" }, "ميكروفون حركة الفن البديل بالإسكندرية", "difficulty");
addEdit(13177, { Level: "6" }, "علي معزة وإبراهيم رحلة رمي الأحجار الثلاثة في البحار", "difficulty");
addEdit(13178, { Level: "6" }, "ساعة ونص تفاصيل كارثة قطار العياط", "difficulty");
addEdit(13179, { Level: "6" }, "أوقات فراغ حادث السير ومأساة حازم", "difficulty");
addEdit(13180, { Level: "6" }, "مسجون ترانزيت حقيقة العميد شوقي", "difficulty");
addEdit(13181, { Level: "6" }, "الشبح استعادة سعد لذاكرته ومواجهة الفيومي", "difficulty");
addEdit(13182, { Level: "6" }, "حرب كرموز المعركة الكبرى أمام الإنجليز", "difficulty");
addEdit(13183, { Level: "6" }, "العارف مغامرة بلغاريا واختراق الشبكة", "difficulty");
addEdit(13184, { Level: "6" }, "هيبتا المفاجأة الدرامية بأن القصص الأربع لشخص واحد", "difficulty");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
