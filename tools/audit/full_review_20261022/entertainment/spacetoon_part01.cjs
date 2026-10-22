"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_03_0000.jsonl");
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

addEdit(12526, { Level: "4" }, "شخصية جين من البدايات معرفة متوسطة وليست صعبة", "difficulty");
addEdit(12527, { Level: "0" }, "براعة سينشي في كرة القدم معرفة أساسية عامة", "difficulty");
addEdit(12536, { R: "اليويو المعدني", W1: "الخناجر", W2: "السلاسل", W3: "السوط" }, "اختصار الجواب لتسهيل الإدخال المكتوب وتجنيس المشتتات");
addEdit(12548, { R: "عصابة العناكب", W1: "القتلة المحترفون", W2: "وحوش الظلال", W3: "صيادو الجوائز" }, "حذف كلمة فقط لتسهيل المطابقة وتجنيس المشتتات");
addEdit(12562, { Q: "في كرتون أبطال الديجيتال، ما هي صفة القلادة الرقمية الخاصة بالطفلة سمر؟", R: "المحبة", W1: "الشجاعة", W2: "الصداقة", W3: "المعرفة", Level: "4" }, "استبدال سؤال غير مألوف بالإنجليزية بسؤال عن قلائد أبطال الديجيتال في الدبلجة العربية", "replacement");
addEdit(12569, { R: "الحوت", W1: "السلحفاة", W2: "القرش", W3: "التنين" }, "اختصار الجواب وتجنيس المشتتات البحرية");
addEdit(12579, { R: "توحيد المجرة", W1: "تدمير الكواكب", W2: "جمع الثروات", W3: "السيطرة على الأرض" }, "اختصار الجواب الطويل ليلائم نمط الإدخال");

review.edits = [...editsMap.values()].sort((a, b) => a.index - b.index);

fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length });
