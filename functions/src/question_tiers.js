"use strict";

// Shared by both server board protocols; matches LocalQuestions.tierForLevel.
function tierForLevel(level) {
  const value = Number(level);
  return [0, 1, 2].includes(value) ? 0 : [4, 5, 6].includes(value) ? 1 : 2;
}

module.exports = { tierForLevel };
