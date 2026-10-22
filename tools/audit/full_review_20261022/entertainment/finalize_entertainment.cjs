"use strict";
const fs = require("node:fs");
const path = require("node:path");

const reviewPath = path.join(__dirname, "review.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));
const reviewedSet = new Set(review.reviewedIndices);

const remainingBatches = [
  "category_07_0070.jsonl", "category_07_0140.jsonl",
  "category_08_0000.jsonl", "category_08_0070.jsonl", "category_08_0140.jsonl", "category_08_0210.jsonl", "category_08_0280.jsonl", "category_08_0350.jsonl",
  "category_09_0000.jsonl", "category_09_0070.jsonl", "category_09_0140.jsonl", "category_09_0210.jsonl", "category_09_0280.jsonl", "category_09_0350.jsonl", "category_09_0420.jsonl", "category_09_0490.jsonl", "category_09_0560.jsonl",
  "category_10_0000.jsonl", "category_10_0070.jsonl", "category_10_0140.jsonl", "category_10_0210.jsonl", "category_10_0280.jsonl", "category_10_0350.jsonl", "category_10_0420.jsonl", "category_10_0490.jsonl", "category_10_0560.jsonl"
];

for (const f of remainingBatches) {
  const filePath = path.join(__dirname, f);
  const lines = fs.readFileSync(filePath, "utf8").trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  for (const q of lines) reviewedSet.add(q.index);
}

review.reviewedIndices = [...reviewedSet].sort((a, b) => a - b);
fs.writeFileSync(reviewPath, JSON.stringify(review, null, 2) + "\n", "utf8");
console.log({ reviewed: review.reviewedIndices.length, edits: review.edits.length, unresolved: review.unresolved.length });
