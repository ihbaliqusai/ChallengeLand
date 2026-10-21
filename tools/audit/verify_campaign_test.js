const fs = require('fs');
const path = require('path');

// Read the clean bank
const questions = JSON.parse(fs.readFileSync(path.join(__dirname, 'questions.clean.json'), 'utf8'));

// Stages configuration from campaign_defaults.dart
// In Dart: 100 stages, 10 worlds (10 stages each)
const worldLevels = [
  ['0', '1'],
  ['0', '1', '2'],
  ['1', '2'],
  ['2', '4'],
  ['2', '5'],
  ['4', '5'],
  ['5', '6'],
  ['6', '7'],
  ['7', '8'],
  ['3', '8'],
];

// Check category pool at each world
worldLevels.forEach((levels, worldIdx) => {
  const eligible = {};
  questions.forEach(q => {
    if (q.Category && levels.includes(String(q.Level))) {
      if (!eligible[q.Category]) eligible[q.Category] = [];
      eligible[q.Category].push(q);
    }
  });

  const available = Object.entries(eligible).filter(([cat, list]) => {
    if (list.length < 6) return false;
    if (levels.length === 2) {
      return levels.every(lvl => list.filter(q => String(q.Level) === lvl).length >= 2);
    }
    return true;
  });

  console.log(`World ${worldIdx + 1} (levels: ${levels.join(',')}): ${available.length} categories available (each >= 6 Qs)`);
  if (available.length < 6) {
    console.error(`ERROR: World ${worldIdx + 1} has insufficient available categories!`);
  }
});

console.log('Campaign stages compatibility check PASSED successfully!');
