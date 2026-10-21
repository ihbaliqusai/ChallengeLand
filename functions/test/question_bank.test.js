"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { isCorrect } = require("../src/board_answer_matcher");
const { tierForLevel } = require("../src/question_tiers");
const { makeBoard } = require("../src/original_stake_board");

test("all nine levels use the requested point values, including levels 2 and 6", () => {
  assert.deepEqual(Array.from({ length: 9 }, (_, i) => tierForLevel(String(i))), [0, 0, 0, 2, 1, 1, 1, 2, 2]);
  const bank = Array.from({ length: 9 }, (_, level) => Array.from({ length: 4 }, (_, i) => ({
    category: "Test", text: `Question ${level}/${i}`, level, answers: ["right", "wrong1", "wrong2", "wrong3"],
  }))).flat();
  for (let seed = 0; seed < 10; seed++) {
    const board = makeBoard(bank, ["Test", "Test"], String(seed));
    for (const cell of Object.values(board.cells)) assert.equal(cell.points, [200, 400, 600][tierForLevel(cell.question.level)]);
  }
});

test("every canonical bank answer is accepted and every listed distractor is rejected", () => {
  const questions = require("../../assets/questions.json");
  for (const [i, q] of questions.entries()) {
    assert.equal(isCorrect(q.R, q), true, `right answer at ${i}: ${q.R}`);
    for (const wrong of [q.W1, q.W2, q.W3]) assert.equal(isCorrect(wrong, q), false, `wrong answer at ${i}: ${wrong}`);
  }
});

test("numeric values, signs and mathematical symbols cannot be fuzzy spelling matches", () => {
  const question = (R, W1, W2, W3) => ({ R, W1, W2, W3 });
  for (const [q, correct, wrong] of [
    [question("25", "-25", "10", "-10"), "٢٥", "26"],
    [question("-7", "1/7", "7", "-1/7"), "−٧", "7"],
    [question("3.6", "4", "3", "5"), "٣٫٦", "36"],
    [question("80,000", "1", "2", "3"), "٨٠٠٠٠", "80001"],
    [question("35 غرامًا", "1 غرام", "5 غرامات", "100 غرام"), "٣٥ غراما", "34 غراما"],
    [question("@", "#", "&", "%"), "@", "#"],
    [question("e", "π", "φ", "i"), "e", "π"],
    [question("Cos(x)", "-Cos(x)", "Sin(x)", "-Sin(x)"), "cos (x)", "-cos(x)"],
  ]) {
    assert.equal(isCorrect(correct, q), true, correct);
    assert.equal(isCorrect(wrong, q), false, wrong);
  }
  assert.equal(isCorrect("نجيب محفوظ", question("نجيب محفوظ", "طه حسين", "أحمد شوقي", "توفيق الحكيم")), true);
  assert.equal(isCorrect("محفوظ", question("نجيب محفوظ", "طه حسين", "أحمد شوقي", "توفيق الحكيم")), true);
});
