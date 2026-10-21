"use strict";
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const root = path.resolve(__dirname, "../../..");
const questions = require("../../../assets/questions.json");
const inventory = require("./inventory.json");
const review = require("./review_records.json");
const visual = require("./visual_review.json");
const bank = require("../second_pass_report.json");
const before = JSON.parse(fs.readFileSync(path.join(__dirname, "assets__questions.json.backup"), "utf8"));
const targets = new Set([...inventory.long, ...inventory.reveals, ...inventory.media]);
assert.equal(questions.length, before.length);
assert.equal(review.records.length, targets.size);
assert.equal(new Set(review.records.map(r => r.index)).size, targets.size);
for (const r of review.records) {
  assert.deepEqual(r.after, questions[r.index], `review stale at ${r.index}`);
  assert.equal(r.before.Category, r.after.Category);
  if (r.action === "replaced") assert.equal(r.before.Level, r.after.Level);
}
for (let i = 0; i < questions.length; i++) if (!targets.has(i)) assert.deepEqual(questions[i], before[i], `out-of-scope data change ${i}`);
assert.equal(visual.images.length, inventory.media.length);
for (const evidence of visual.images) {
  const file = fs.readFileSync(path.join(__dirname, evidence.snapshot));
  assert.equal(crypto.createHash("sha256").update(file).digest("hex"), evidence.sha256);
  assert.equal(questions[evidence.index].Img, evidence.url);
}
assert.equal(bank.errors.length, 0);
assert.ok(bank.summary.generated.every(b => b.matchesSource));
assert.equal(bank.review.filter(r => r.reason === "long_answer_over_45_characters").length, 0);
assert.equal(bank.review.filter(r => r.reason === "potential_answer_in_question").length, 0);
assert.equal(bank.media.filter(m => m.status === "visually_reviewed").length, 15);
function log(name) {
  const bytes = fs.readFileSync(path.join(__dirname, name));
  return bytes.toString(bytes[0] === 0xff && bytes[1] === 0xfe ? "utf16le" : "utf8");
}
const server = log("server_test.log");
const campaign = log("campaign_test.log");
const native = log("android_answers.log");
const build = log("android_build.log");
assert.ok(/pass 99/.test(server) && /fail 0/.test(server));
assert.ok(/\+16: All tests passed!/.test(campaign));
assert.ok(/61726 cases passed/.test(native));
assert.ok(/BUILD SUCCESSFUL/.test(build));
const result = { date: "2026-10-21", scope: review.summary, questions: questions.length, schemaErrors: 0,
  generatedBanksMatch: true, longAnswersRemaining: 0, flaggedAnswerRevealsRemaining: 0,
  imagesVisuallyReviewed: 15, untouchedRecordsPreserved: true,
  checks: { server: { passed: 99, failed: 0 }, campaignAndCategories: { passed: 16, failed: 0 },
    androidAnswerParityCases: 61726, androidDebugBuild: "passed" },
  remainingHeuristicFlags: bank.summary.reviewCounts,
  limits: "Scoped editorial review. Sources include official references and secondary episode transcripts/fan encyclopedias. Not a new fact-check of all remaining bank content." };
fs.writeFileSync(path.join(__dirname, "validation.json"), JSON.stringify(result, null, 2) + "\n");
console.log(result);
