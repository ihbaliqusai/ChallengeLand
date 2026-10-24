"use strict";
const fs = require("node:fs");
const path = require("node:path");
const w = require("./work.cjs");
const E = (i, c, r, s = [], k = "correction") => w.edit(i, c, r, k, s);

// --- Quranic Surahs Order Calibration (6756 - 6825) ---

const surahPairs = [
  [6757, 15], [6759, 16], [6761, 17], [6763, 18], [6765, 19],
  [6767, 20], [6769, 21], [6771, 22], [6773, 23], [6775, 24],
  [6777, 25], [6779, 26], [6781, 27], [6783, 28], [6785, 29],
  [6787, 30], [6789, 31], [6791, 32], [6793, 33], [6795, 34],
  [6797, 35], [6799, 36], [6801, 37], [6803, 38], [6805, 39],
  [6807, 40], [6809, 41], [6811, 42], [6813, 43], [6815, 44],
  [6817, 45], [6819, 46], [6821, 47], [6823, 48], [6825, 49]
];

for (const [idx, num] of surahPairs) {
  E(idx, {
    W1: String(num - 1),
    W2: String(num + 1),
    W3: String(num + 2)
  }, "تجنيس المشتتات العددية المتجاورة لترتيب السور");
}

// Adjust difficulty for prominent surahs
E(6762, { Level: "2" }, "سورة الكهف سورة الجمعة الشهيرة معرفة شائعة", [], "difficulty");
E(6763, { Level: "2" }, "ترتيب سورة الكهف (18) معرفة شائعة", [], "difficulty");
E(6764, { Level: "2" }, "سورة مريم سورة شهيرة معرفة شائعة", [], "difficulty");
E(6765, { Level: "2" }, "ترتيب سورة مريم (19) معرفة شائعة", [], "difficulty");
E(6766, { Level: "2" }, "سورة طه معرفة قرآنية شائعة", [], "difficulty");
E(6774, { Level: "2" }, "سورة النور وآداب الأسرة معرفة شائعة", [], "difficulty");
E(6798, { Level: "2" }, "سورة يس قلب القرآن سورة شهيرة جداً", [], "difficulty");
E(6799, { Level: "2" }, "ترتيب سورة يس (36) معرفة شائعة", [], "difficulty");
E(6820, { Level: "2" }, "سورة محمد باسم النبي معرفة شائعة", [], "difficulty");
E(6821, { Level: "2" }, "ترتيب سورة محمد (47) معرفة شائعة", [], "difficulty");
E(6822, { Level: "2" }, "سورة الفتح معرفة قرآنية شائعة", [], "difficulty");
E(6824, { Level: "2" }, "سورة الحجرات سورة الأخلاق معرفة شائعة", [], "difficulty");

// --- Mark all reviewed indices in category_06_0140.jsonl ---
const records = fs.readFileSync(path.join(__dirname, "category_06_0140.jsonl"), "utf8").trim().split(/\r?\n/).map(JSON.parse);
for (const x of records) w.out.reviewedIndices.push(x.index);
w.out.reviewedIndices = [...new Set(w.out.reviewedIndices)].sort((a, b) => a - b);
w.save();
console.log(JSON.stringify({ reviewed: w.out.reviewedIndices.length, edits: w.out.edits.length, unresolved: w.out.unresolved.length }));
