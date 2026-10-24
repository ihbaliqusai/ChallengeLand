"use strict";
const fs = require("node:fs");
const path = require("node:path");
const w = require("./work.cjs");
const E = (i, c, r, s = [], k = "correction") => w.edit(i, c, r, k, s);

// --- Historical Milestones Calibration (8253 - 8263) ---
E(8254, { Level: "4" }, "أزمة السويس وتأميم القناة معرفة تاريخية متوسطة", [], "difficulty");
E(8258, { Level: "4" }, "اتفاق الطائف وإنهاء الحرب الأهلية اللبنانية معرفة عربية متوسطة", [], "difficulty");
E(8260, { Level: "4" }, "معاهدة وادي عربة لسلام الأردن وإسرائيل معرفة متوسطة", [], "difficulty");

// --- Mark all reviewed indices in category_05_0280.jsonl ---
const records = fs.readFileSync(path.join(__dirname, "category_05_0280.jsonl"), "utf8").trim().split(/\r?\n/).map(JSON.parse);
for (const x of records) w.out.reviewedIndices.push(x.index);
w.out.reviewedIndices = [...new Set(w.out.reviewedIndices)].sort((a, b) => a - b);
w.save();
console.log(JSON.stringify({ reviewed: w.out.reviewedIndices.length, edits: w.out.edits.length, unresolved: w.out.unresolved.length }));
