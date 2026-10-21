"use strict";
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const { decisions } = require("./decisions.cjs");
const inventory = require("./inventory.json");
const { normalize, isCorrect } = require("../../../functions/src/board_answer_matcher");
const root = path.resolve(__dirname, "../../..");
const file = path.join(root, "assets/questions.json");
const backup = fs.readFileSync(path.join(__dirname, "assets__questions.json.backup"), "utf8");
const recordsFile = path.join(__dirname, "review_records.json");
const previous = fs.existsSync(recordsFile) ? JSON.parse(fs.readFileSync(recordsFile, "utf8")).records : [];
const questions = JSON.parse(backup), records = [], targets = [...new Set([...inventory.long, ...inventory.reveals, ...inventory.media])];
assert.equal(decisions.length, targets.length);
assert.equal(new Set(decisions.map(d => d.index)).size, targets.length);
for (const decision of decisions) {
  assert.ok(targets.includes(decision.index));
  const before = { ...questions[decision.index] }, after = { ...before, ...decision.changes };
  for (const field of ["Q", "R", "W1", "W2", "W3", "Level", "Category"]) assert.ok(typeof after[field] === "string" && after[field].trim(), `${decision.index}: ${field}`);
  assert.equal(after.Category, before.Category);
  const options = [after.R, after.W1, after.W2, after.W3];
  assert.equal(new Set(options.map(normalize)).size, 4, `options at ${decision.index}`);
  assert.ok(isCorrect(after.R, after));
  for (const wrong of options.slice(1)) assert.ok(!isCorrect(wrong, after));
  if (inventory.long.includes(decision.index)) assert.ok(after.R.length <= 45, `${decision.index}: answer still long`);
  if (inventory.reveals.includes(decision.index)) {
    const key = v => v.replace(/[\u064b-\u0652\u0670\u0640]/g, "").replace(/\s+/g, " ").trim();
    assert.ok(!key(after.Q).includes(key(after.R)), `${decision.index}: still states answer`);
  }
  questions[decision.index] = after;
  records.push({ ...decision, before, after, changed: JSON.stringify(before) !== JSON.stringify(after) });
}
const generated = JSON.stringify(questions, null, 2) + (backup.endsWith("\n") ? "\n" : "");
const summary = { reviewed: records.length, changed: records.filter(r => r.changed).length,
  long: inventory.long.length, reveals: inventory.reveals.length, images: inventory.media.length,
  replaced: records.filter(r => r.action === "replaced").length,
  levelsChanged: records.filter(r => r.before.Level !== r.after.Level).length,
  unchanged: records.filter(r => !r.changed).map(r => r.index),
  longestTargetAnswer: Math.max(...inventory.long.map(i => questions[i].R.length)), countBefore: JSON.parse(backup).length, countAfter: questions.length };
if (process.argv.includes("--write")) {
  const current = JSON.parse(fs.readFileSync(file, "utf8"));
  assert.equal(current.length, questions.length);
  const old = JSON.parse(backup);
  for (let i = 0; i < current.length; i++) {
    const allowed = [old[i], questions[i], previous.find(r => r.index === i)?.after].filter(Boolean).map(JSON.stringify);
    assert.ok(allowed.includes(JSON.stringify(current[i])), `Concurrent change at ${i}; do not overwrite`);
  }
  fs.writeFileSync(file, generated);
}
fs.writeFileSync(recordsFile, JSON.stringify({ summary, records }, null, 2) + "\n");
console.log(summary);
