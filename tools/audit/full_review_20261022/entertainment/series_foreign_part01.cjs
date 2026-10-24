"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const batchFile = path.join(__dirname, "category_07_0000.jsonl");
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

// --- Foreign TV Series Batch 1 (Category 07 Batch 0000: indices 13608 - 13677) ---

// Replace duplicate Walter White 13612 with Jesse Pinkman
addEdit(13612, {
  Q: "في مسلسل Breaking Bad، ما اسم الشاب المساعد والشريك المقرب لوالتر وايت في صناعة الميث؟ (اكتب بالإنجليزية)",
  R: "Jesse Pinkman",
  W1: "Todd Alquist",
  W2: "Skinny Pete",
  W3: "Badger",
  Level: "0"
}, "استبدال تكرار والتر وايت بشريكه جيسي بينكمان وتجنيس المشتتات");

// Tier 2 (Level 7) assignments
addEdit(13639, {
  Level: "7"
}, "بلدة فيندن Winden في مسلسل Dark وأسرار السفر عبر الزمن (Tier 2)", "difficulty");

addEdit(13640, {
  Level: "7"
}, "دورة الـ 33 سنة في كهف Dark الزمني تفصيلة حبكة متقدمة (Tier 2)", "difficulty");

addEdit(13646, {
  Level: "7"
}, "شركة Lumon Industries في مسلسل Severance فكرة درامية متقدمة (Tier 2)", "difficulty");

addEdit(13661, {
  Level: "7"
}, "حلقة Nosedive الشهيرة في Black Mirror ونظام التقييم الاجتماعي (Tier 2)", "difficulty");

addEdit(13662, {
  Level: "7"
}, "مبادرة دارما DHARMA Initiative في مسلسل Lost ومحطاتها الميدانية (Tier 2)", "difficulty");

// Replace trivial leak in Sopranos question 13668 with Bada Bing strip club
addEdit(13668, {
  Q: "في مسلسل The Sopranos، ما اسم النادي الذي يُعد المقر غير الرسمي لاجتماعات عصابة توني سوبرانو؟ (اكتب بالإنجليزية)",
  R: "Bada Bing",
  W1: "Satriale's",
  W2: "The Bamboo Lounge",
  W3: "The Vesuvio",
  Level: "4"
}, "استبدال سؤال مسرب لاسم عائلة سوبرانو بمقر العصابة الشهير بادا بينغ وتجنيس المشتتات");

addEdit(13677, {
  Level: "7"
}, "الفيزيائي السوفياتي فاليري ليغاسوف وتحقيقات مفاعل تشيرنوبل (Tier 2)", "difficulty");

// Save review
review.edits = [...editsMap.values()].sort((a, b) => a - b);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log(JSON.stringify({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length }));
