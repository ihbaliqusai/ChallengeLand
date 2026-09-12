const fs = require('fs');
const path = require('path');

const b1 = require('./batch1.js');
const b2 = require('./batch2.js');
const b3 = require('./batch3.js');
const b4 = require('./batch4.js');
const b5 = require('./batch5.js');
const b6 = require('./batch6.js');

console.log('Batch counts:', {
  b1: b1.length,
  b2: b2.length,
  b3: b3.length,
  b4: b4.length,
  b5: b5.length,
  b6: b6.length,
});

const allAnime = [...b1, ...b2, ...b3, ...b4, ...b5, ...b6];
console.log('Total anime questions to add:', allAnime.length);

if (allAnime.length !== 600) {
  console.error(`ERROR: Expected 600 questions, got ${allAnime.length}`);
  process.exit(1);
}

// Validation
let parenErrors = 0;
let choiceErrors = 0;
let levelDist = {};
const animeQSet = new Set();
let dupInAnime = 0;

allAnime.forEach((q, idx) => {
  ['Q', 'R', 'W1', 'W2', 'W3'].forEach(f => {
    if (!q[f] || typeof q[f] !== 'string') {
      console.error(`Missing or non-string field ${f} at index ${idx}`);
      process.exit(1);
    }
    if (q[f].includes('(') || q[f].includes(')')) {
      console.error(`Paren error at index ${idx}, field ${f}: ${q[f]}`);
      parenErrors++;
    }
  });

  const choices = [q.R.trim(), q.W1.trim(), q.W2.trim(), q.W3.trim()];
  const choiceSet = new Set(choices);
  if (choiceSet.size !== 4) {
    console.error(`Duplicate choice at index ${idx}:`, choices);
    choiceErrors++;
  }

  if (animeQSet.has(q.Q.trim())) {
    console.error(`Duplicate question in anime batches: ${q.Q}`);
    dupInAnime++;
  }
  animeQSet.add(q.Q.trim());

  levelDist[q.Level] = (levelDist[q.Level] || 0) + 1;
});

if (parenErrors > 0 || choiceErrors > 0 || dupInAnime > 0) {
  console.error(`Validation failed: ${parenErrors} paren errors, ${choiceErrors} choice errors, ${dupInAnime} dup questions.`);
  process.exit(1);
}

console.log('Validation PASSED for all 600 questions!');
console.log('Level distribution:', levelDist);

// Check tier distribution
// easy: 0, 1
// medium: 2, 4, 5
// hard: 3, 6, 7, 8
const easyCount = (levelDist['0'] || 0) + (levelDist['1'] || 0);
const medCount = (levelDist['2'] || 0) + (levelDist['4'] || 0) + (levelDist['5'] || 0);
const hardCount = (levelDist['3'] || 0) + (levelDist['6'] || 0) + (levelDist['7'] || 0) + (levelDist['8'] || 0);
console.log(`Tiers: Easy (0,1): ${easyCount}, Medium (2,4,5): ${medCount}, Hard (3,6,7,8): ${hardCount}`);

// Load existing database
const p1 = path.join(__dirname, '../../assets/questions.json');
const p2 = path.join(__dirname, '../../android/app/src/main/assets/questions.json');

const raw1 = fs.readFileSync(p1, 'utf8');
const existingDb = JSON.parse(raw1);
console.log('Existing DB count:', existingDb.length);

// Check duplicates against existing database
let dupWithDb = 0;
const existingQSet = new Set(existingDb.map(x => x.Q.trim()));
allAnime.forEach((q, idx) => {
  if (existingQSet.has(q.Q.trim())) {
    console.error(`Question already exists in DB: ${q.Q}`);
    dupWithDb++;
  }
});

if (dupWithDb > 0) {
  console.error(`Found ${dupWithDb} questions already in existing DB!`);
  process.exit(1);
}

// Append and save
const combinedDb = [...existingDb, ...allAnime];
console.log('New total DB count:', combinedDb.length);

const outputJson = JSON.stringify(combinedDb, null, 2);
fs.writeFileSync(p1, outputJson, 'utf8');
fs.writeFileSync(p2, outputJson, 'utf8');
console.log('Successfully written to both assets/questions.json and android/app/src/main/assets/questions.json');

// Verify byte identity
const check1 = fs.readFileSync(p1);
const check2 = fs.readFileSync(p2);
if (check1.equals(check2)) {
  console.log('Files are 100% byte identical! Size:', check1.length, 'bytes');
} else {
  console.error('ERROR: Files are NOT byte identical!');
  process.exit(1);
}
