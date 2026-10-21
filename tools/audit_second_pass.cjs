"use strict";

// Read-only audit of every active question and both generated server banks.
// Heuristic flags require editorial review; they are not factual verdicts.
const fs = require("node:fs");
const path = require("node:path");
const { normalize, isCorrect } = require("../functions/src/board_answer_matcher");
const { free } = require("../functions/src/economy");
const root = path.resolve(__dirname, "..");
const read = name => JSON.parse(fs.readFileSync(path.join(root, name), "utf8"));
const questions = read("assets/questions.json");
const focusedPath = path.join(root, "tools/audit/focused_review/review_records.json");
const focused = fs.existsSync(focusedPath) ? JSON.parse(fs.readFileSync(focusedPath, "utf8")).records : [];
const hidden = category => ["دقة ملاحظة", "دقه ملاحظه"].includes(category.trim());
const errors = [], review = [], categories = {}, duplicates = [], media = [];
const seen = new Map();
const key = value => value.normalize("NFC").replace(/[\u064b-\u0652\u0670\u0640]/g, "").replace(/\s+/g, " ").trim();
const required = ["Q", "R", "W1", "W2", "W3", "Level", "Category"];
questions.forEach((q, index) => {
  const ref = { index, category: q.Category, level: q.Level, question: q.Q, answer: q.R };
  const error = reason => errors.push({ ...ref, reason });
  const flag = reason => review.push({ ...ref, reason });
  if (required.some(k => typeof q[k] !== "string" || !q[k].trim())) { error("invalid_required_field"); return; }
  if (!/^[0-8]$/.test(q.Level)) error("invalid_level");
  if (Object.keys(q).some(k => ![...required, "Img"].includes(k))) error("unexpected_field");
  if (q.Img !== undefined && typeof q.Img !== "string") error("invalid_image_field");
  const options = [q.R, q.W1, q.W2, q.W3];
  if (new Set(options.map(x => x.trim())).size !== 4) error("duplicate_options");
  if (new Set(options.map(normalize)).size !== 4) error("normalized_option_collision");
  if (!isCorrect(q.R, q)) error("correct_answer_rejected");
  options.slice(1).forEach(wrong => { if (isCorrect(wrong, q)) error(`wrong_answer_accepted: ${wrong}`); });
  const signature = key(q.Q);
  if (seen.has(signature)) duplicates.push({ ...ref, firstIndex: seen.get(signature) });
  else seen.set(signature, index);
  const category = categories[q.Category] ||= { total: 0, levels: {}, values: { 200: 0, 400: 0, 600: 0 }, hidden: hidden(q.Category) };
  category.total++;
  category.levels[q.Level] = (category.levels[q.Level] || 0) + 1;
  category.values[["0", "1", "2"].includes(q.Level) ? 200 : ["4", "5", "6"].includes(q.Level) ? 400 : 600]++;
  if (q.Img) {
    const reviewed = focused.find(r => r.index === index && r.sources.some(s => s.startsWith("visual:"))
      && JSON.stringify(r.after) === JSON.stringify(q));
    media.push({ ...ref, url: q.Img, hidden: hidden(q.Category),
      status: reviewed ? "visually_reviewed" : "not_visually_verified",
      ...(reviewed ? { visualReview: reviewed.reason, evidence: reviewed.sources[0] } : {}) });
  }
  if (/[a-z]/i.test(q.R) && !/إنجليز|انجليز|English|لاتيني/i.test(q.Q)) flag("latin_answer_without_hint");
  if (/^[\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?$/.test(q.R) && !/أرقام|ارقام|عدداً|رقماً/.test(q.Q)) flag("numeric_answer_without_hint");
  if (/[a-z]/i.test(q.R) && /[ء-ي]/.test(q.R) && /اكتب بالإنجليزية/.test(q.Q)) flag("mixed_answer_english_only_hint");
  if (q.R.length > 45) flag("long_answer_over_45_characters");
  if (/أي مما يلي|أي من التالية|أي من الآتي|أي الخيارات|أي من هذه|أي من هؤلاء|أي العبارات التالية|أي الجمل التالية|أي الكلمات التالية|أي الآتي|ليست من|ليس من/.test(q.Q)) flag("potential_option_dependence");
  if (/ما هو|ما هي|ما اسم/.test(q.Q) && q.R.length >= 5 && key(q.Q).includes(key(q.R))) flag("potential_answer_in_question");
  if (q.Category === "خمن الأغنية" && q.Q.length > 220) flag("long_song_paraphrase");
  if (!hidden(q.Category) && /الظاهرة في الصورة|الظاهر في الصورة|أمامك في الصورة/.test(q.Q) && !q.Img) flag("possible_missing_image");
});
for (const [category, data] of Object.entries(categories)) {
  if (!data.hidden && Object.values(data.values).some(count => count < 4)) errors.push({ category, reason: "insufficient_tier_questions_for_shared_category" });
}
duplicates.forEach(duplicate => errors.push({ ...duplicate, reason: "duplicate_question_text" }));
const expectedLegacy = questions.filter(q => free(q.Category)
  && [q.Q, q.R, q.W1, q.W2, q.W3].every(v => typeof v === "string" && v.trim())
  && new Set([q.R, q.W1, q.W2, q.W3]).size === 4)
  .map(q => ({ category: q.Category, text: q.Q, answers: [q.R, q.W1, q.W2, q.W3], level: Number(q.Level) || 0 }));
const expectedOriginal = questions.filter(q => !hidden(q.Category))
  .map(q => ({ category: q.Category.trim(), text: q.Q, answers: [q.R, q.W1, q.W2, q.W3], level: q.Level, img: q.Img || "" }));
const generated = [
  ["functions/src/stake_questions.json", expectedLegacy],
  ["functions/src/original_stake_questions.json", expectedOriginal],
].map(([file, expected]) => {
  const actual = read(file), matches = JSON.stringify(actual) === JSON.stringify(expected);
  if (!matches) errors.push({ file, reason: "generated_bank_out_of_sync" });
  return { file, questions: actual.length, matchesSource: matches };
});
const originalBackup = read("assets/questions.backup_audit_start.json");
const beforeSecondPass = read("tools/audit/second_pass_backup/assets__questions.json");
function diff(before) {
  const result = { countBefore: before.length, countAfter: questions.length, changed: 0, categories: 0, levels: 0, wording: 0, answers: 0, options: 0 };
  questions.forEach((q, i) => {
    const old = before[i] || {};
    if (JSON.stringify(q) !== JSON.stringify(old)) result.changed++;
    for (const [name, keys] of Object.entries({ categories: ["Category"], levels: ["Level"], wording: ["Q"], answers: ["R"], options: ["W1", "W2", "W3"] })) {
      if (keys.some(k => q[k] !== old[k])) result[name]++;
    }
  });
  return result;
}
const reviewCounts = {};
review.forEach(item => reviewCounts[item.reason] = (reviewCounts[item.reason] || 0) + 1);
const summary = { questions: questions.length, categories: Object.keys(categories).length,
  activeQuestions: questions.filter(q => !hidden(q.Category)).length,
  activeCategories: Object.values(categories).filter(c => !c.hidden).length,
  errors: errors.length, generated, reviewCounts, media: media.length,
  comparedWithOriginalAuditBackup: diff(originalBackup), secondPassChanges: diff(beforeSecondPass) };
const report = { summary, categories, errors, review, media,
  limits: "All records checked structurally and against answer matching; review flags are heuristics. Not an authoritative fact-check or visual verification of every question." };
const reportPath = path.join(root, "tools/audit/second_pass_report.json");
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");
console.log(JSON.stringify(summary, null, 2));
process.exitCode = errors.length ? 1 : 0;
