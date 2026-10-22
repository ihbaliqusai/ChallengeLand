"use strict";
const fs = require("node:fs"), path = require("node:path");
const dir = __dirname, bank = require("./backup/assets__questions.json"), manifest = require("./manifest.json");
const { normalize, isCorrect } = require("../../../functions/src/board_answer_matcher");
const proposed = bank.map(q => ({ ...q })), changes = new Map(), errors = [], coverage = {}, unresolved = [];
for (const group of Object.keys(manifest.coverage)) {
  const file = path.join(dir, group, "review.json");
  if (!fs.existsSync(file)) { coverage[group] = { read: 0, total: manifest.coverage[group].count }; continue; }
  const review = JSON.parse(fs.readFileSync(file, "utf8"));
  const allowed = new Set(manifest.coverage[group].batches.flatMap(b => b.indices));
  const read = new Set(review.reviewedIndices);
  for (const index of read) if (!allowed.has(index)) errors.push({ group, index, reason: "coverage_outside_assignment" });
  coverage[group] = { read: read.size, total: allowed.size, edits: review.edits.length };
  for (const entry of review.edits) {
    const { index } = entry;
    if (!allowed.has(index)) errors.push({ group, index, reason: "edit_outside_assignment" });
    if (!read.has(index)) errors.push({ group, index, reason: "edit_without_review" });
    const edit = entry.changes;
    if (!edit || Object.entries(edit).some(([key, value]) => !["Q", "R", "W1", "W2", "W3", "Level", "Category", "Img"].includes(key) || typeof value !== "string" || !value.trim())) {
      errors.push({ group, index, reason: "invalid_edit", entry }); continue;
    }
    const existing = changes.get(index);
    if (existing && existing.group !== group) errors.push({ group, index, reason: "cross_group_conflict" });
    changes.set(index, { group, index, changes: { ...(existing?.changes || {}), ...edit }, reasons: [...(existing?.reasons || []), entry.reason], kinds: [...new Set([...(existing?.kinds || []), entry.kind])], sources: [...new Set([...(existing?.sources || []), ...(entry.sources || [])])] });
    Object.assign(proposed[index], edit);
  }
  unresolved.push(...review.unresolved.map(entry => ({ ...entry, group })));
}
const categories = {}, qSeen = new Map();
for (const [index, q] of proposed.entries()) {
  const answers = [q.R, q.W1, q.W2, q.W3];
  if (new Set(answers.map(normalize)).size !== 4) errors.push({ index, reason: "option_collision", answers });
  if (!isCorrect(q.R, q)) errors.push({ index, reason: "right_rejected", question: q });
  for (const wrong of answers.slice(1)) if (isCorrect(wrong, q)) errors.push({ index, reason: "wrong_accepted", wrong, question: q });
  // Emoji, formulas and their order are part of a question's visible clues.
  // The answer normalizer deliberately strips these and cannot key questions.
  const key = q.Q.normalize("NFKC").toLowerCase().replace(/[\u064b-\u0652\u0670\u0640]/g, "").replace(/\s+/g, " ").trim();
  if (qSeen.has(key)) errors.push({ index, first: qSeen.get(key), reason: "duplicate_question", question: q.Q });
  else qSeen.set(key, index);
  const counts = categories[q.Category] ??= [0, 0, 0];
  counts[["0", "1", "2"].includes(q.Level) ? 0 : ["4", "5", "6"].includes(q.Level) ? 1 : 2]++;
}
for (const [category, counts] of Object.entries(categories)) if (category !== "دقة ملاحظة" && counts.some(n => n < 4)) errors.push({ category, counts, reason: "insufficient_tier" });
for (const [index] of changes) if (JSON.stringify(bank[index]) === JSON.stringify(proposed[index])) changes.delete(index);
const result = { coverage, countBefore: bank.length, countAfter: proposed.length, uniqueEditedQuestions: changes.size, errors, categories, unresolved };
fs.writeFileSync(path.join(dir, "provisional_validation.json"), JSON.stringify(result, null, 2) + "\n");
fs.writeFileSync(path.join(dir, "proposed_questions.json"), JSON.stringify(proposed, null, 2) + "\n");
fs.writeFileSync(path.join(dir, "merged_changes.json"), JSON.stringify([...changes.values()], null, 2) + "\n");
console.log(JSON.stringify({ coverage, uniqueEditedQuestions: changes.size, errors: errors.length, errorExamples: errors.slice(0, 15), unresolved: unresolved.length }, null, 2));
process.exitCode = errors.length ? 1 : 0;
