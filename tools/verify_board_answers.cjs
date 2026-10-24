"use strict";
const fs = require("node:fs"), os = require("node:os"), path = require("node:path");
const { execFileSync } = require("node:child_process");
const { normalize, isCorrect } = require("../functions/src/board_answer_matcher");
const assert = require("node:assert/strict");
const root = path.resolve(__dirname, "..");
execFileSync(process.execPath, [path.join(__dirname, "sync_answer_quantity_vocabulary.cjs"), "--check"], { stdio: "inherit" });
const output = fs.mkdtempSync(path.join(os.tmpdir(), "challengeland-answer-check-"));
const rows = [];
function add(input, answers, expected, text = "") {
  rows.push([input, ...answers, normalize(input)].map(s => Buffer.from(s).toString("base64")).concat(String(expected), Buffer.from(text).toString("base64")).join("\t"));
}
for (const q of require("../assets/questions.json")) {
  const answers = [q.R, q.W1, q.W2, q.W3];
  answers.forEach((answer, i) => add(answer, answers, i === 0, q.Q));
}
for (const [answers, right, wrong] of [
  [["25", "-25", "10", "-10"], "٢٥", "26"],
  [["-7", "1/7", "7", "-1/7"], "−٧", "7"],
  [["3.6", "4", "3", "5"], "٣٫٦", "36"],
  [["80,000", "1", "2", "3"], "٨٠٠٠٠", "80001"],
  [["35 غرامًا", "1 غرام", "5 غرامات", "100 غرام"], "٣٥ غراما", "34 غراما"],
  [["@", "#", "&", "%"], "@", "#"],
  [["e", "π", "φ", "i"], "e", "π"],
  [["Cos(x)", "-Cos(x)", "Sin(x)", "-Sin(x)"], "cos (x)", "-cos(x)"],
  [["نجيب محفوظ", "طه حسين", "أحمد شوقي", "توفيق الحكيم"], "محفوظ", "طه حسين"],
]) { add(right, answers, true); add(wrong, answers, false); }
for (const { answers, accept, reject, text = "" } of require("../functions/test/answer_quantity_cases.json")) {
  for (const [inputs, expected] of [[accept, true], [reject, false]]) {
    for (const input of inputs) {
      assert.equal(isCorrect(input, { answers, text }), expected, `Server: ${input} / ${answers[0]}`);
      add(input, answers, expected, text);
    }
  }
}
const input = path.join(output, "cases.tsv");
fs.writeFileSync(input, rows.join("\n") + "\n");
const sources = ["android/app/src/main/java/com/Qi7bali/challengeland/Question.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/AnswerQuantity.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/AnswerQuantityVocabulary.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/BoardAnswerMatcher.java",
  "android/verification/BoardAnswerMatcherCheck.java"].map(p => path.join(root, p));
execFileSync("javac", ["-encoding", "UTF-8", "-d", output, ...sources], { stdio: "inherit" });
execFileSync("java", ["-cp", output, "com.qi7bali.landchallengeonline.BoardAnswerMatcherCheck", input], { stdio: "inherit" });
