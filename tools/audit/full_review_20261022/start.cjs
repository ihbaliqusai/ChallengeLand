"use strict";
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const root = path.resolve(__dirname, "../../.."), dir = __dirname;
const groups = {
  science: ["حيوانات", "علوم وفضاء", "جسم الإنسان", "صحة", "نباتات", "طعام وشراب", "تقنية", "اختراعات", "سيارات", "معلومات عامة", "منوعات", "لغة وادب", "لغات"],
  world: ["عواصم", "دول", "جغرافيا", "عملات", "سياحة وسفر", "تاريخ", "دين وإسلاميات", "قصص الأنبياء", "سيرة ذاتية", "رياضة", "كأس العالم", "أمثال"],
  entertainment: ["فنون وسينما", "كلثوميات", "فيروز", "سبيس تون", "أفلام عربية", "أفلام أجنبية", "مسلسلات عربية", "مسلسلات أجنبية", "مسلسل Friends", "الأنمي", "خمن الأغنية"],
  puzzles: ["ألغاز", "خمن الصورة", "خمن الاسم", "خمن الأكلة", "خمن المدينة او الدولة", "زووم", "وضح شوي", "ركز شوي", "دقة ملاحظة"],
};
const backup = path.join(dir, "backup");
if (fs.existsSync(path.join(dir, "manifest.json"))) throw new Error("Review snapshot already exists; refusing overwrite");
fs.mkdirSync(backup, { recursive: true });
const files = ["assets/questions.json", "functions/src/stake_questions.json", "functions/src/original_stake_questions.json",
  "functions/src/board_answer_matcher.js", "functions/src/answer_quantity.js", "functions/src/answer_quantity_words.json",
  "functions/src/question_tiers.js", "functions/scripts/build_stake_questions.js",
  "android/app/src/main/java/com/Qi7bali/challengeland/BoardAnswerMatcher.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/AnswerQuantity.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/AnswerQuantityVocabulary.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/LocalQuestions.java"];
const snapshots = files.map(file => {
  const bytes = fs.readFileSync(path.join(root, file)), saved = file.replaceAll("/", "__");
  fs.writeFileSync(path.join(backup, saved), bytes);
  return { file, backup: saved, sha256: crypto.createHash("sha256").update(bytes).digest("hex"), bytes: bytes.length };
});
const bank = JSON.parse(fs.readFileSync(path.join(root, "assets/questions.json"), "utf8"));
const owners = new Map(Object.entries(groups).flatMap(([owner, categories]) => categories.map(category => [category, owner])));
const coverage = {};
for (const [owner, categories] of Object.entries(groups)) {
  const owned = bank.flatMap((q, index) => owners.get(q.Category) === owner ? [{ index, ...q }] : []);
  coverage[owner] = { categories, count: owned.length, batches: [] };
  fs.mkdirSync(path.join(dir, owner), { recursive: true });
  for (const [categoryNumber, category] of categories.entries()) {
    const rows = owned.filter(q => q.Category === category);
    for (let offset = 0; offset < rows.length; offset += 70) {
      const file = `${owner}/category_${String(categoryNumber).padStart(2, "0")}_${String(offset).padStart(4, "0")}.jsonl`;
      fs.writeFileSync(path.join(dir, file), rows.slice(offset, offset + 70).map(q => JSON.stringify(q)).join("\n") + "\n");
      coverage[owner].batches.push({ file, category, count: Math.min(70, rows.length - offset), indices: rows.slice(offset, offset + 70).map(q => q.index) });
    }
  }
}
if (Object.values(coverage).reduce((sum, group) => sum + group.count, 0) !== bank.length) throw new Error("Unassigned questions");
fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify({ startUtc: "2026-10-22T05:07:08Z", deadlineUtc: "2026-10-22T10:07:08Z", total: bank.length, snapshots, coverage }, null, 2) + "\n");
console.log(JSON.stringify(Object.fromEntries(Object.entries(coverage).map(([owner, group]) => [owner, { count: group.count, batches: group.batches.length }]))));
