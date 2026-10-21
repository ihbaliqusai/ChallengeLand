"use strict";
const fs = require("node:fs"), os = require("node:os"), path = require("node:path");
const { execFileSync } = require("node:child_process");
const { normalize } = require("../functions/src/board_answer_matcher");
const root = path.resolve(__dirname, "..");
const output = fs.mkdtempSync(path.join(os.tmpdir(), "challengeland-answer-check-"));
const rows = [];
function add(input, answers, expected) {
  rows.push([input, ...answers, normalize(input)].map(s => Buffer.from(s).toString("base64")).concat(String(expected)).join("\t"));
}
for (const q of require("../assets/questions.json")) {
  const answers = [q.R, q.W1, q.W2, q.W3];
  answers.forEach((answer, i) => add(answer, answers, i === 0));
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
const input = path.join(output, "cases.tsv");
fs.writeFileSync(input, rows.join("\n") + "\n");
const sources = ["android/app/src/main/java/com/Qi7bali/challengeland/Question.java",
  "android/app/src/main/java/com/Qi7bali/challengeland/BoardAnswerMatcher.java",
  "android/verification/BoardAnswerMatcherCheck.java"].map(p => path.join(root, p));
execFileSync("javac", ["-encoding", "UTF-8", "-d", output, ...sources], { stdio: "inherit" });
execFileSync("java", ["-cp", output, "com.qi7bali.landchallengeonline.BoardAnswerMatcherCheck", input], { stdio: "inherit" });
