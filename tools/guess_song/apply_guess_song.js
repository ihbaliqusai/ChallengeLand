const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const ASSETS_PATH = path.join(ROOT_DIR, 'assets/questions.json');
const ANDROID_ASSETS_PATH = path.join(ROOT_DIR, 'android/app/src/main/assets/questions.json');

// 1. Load all 6 batches
const b1 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch1.json'), 'utf8'));
const b2 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch2.json'), 'utf8'));
const b3 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch3.json'), 'utf8'));
const b4 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch4.json'), 'utf8'));
const b5 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch5.json'), 'utf8'));
const b6 = JSON.parse(fs.readFileSync(path.join(__dirname, 'batch6.json'), 'utf8'));

const allNew = [...b1, ...b2, ...b3, ...b4, ...b5, ...b6];
console.log('Total questions collected across all batches:', allNew.length);

if (allNew.length !== 600) {
  console.error('ERROR: Total questions count must be exactly 600, got:', allNew.length);
  process.exit(1);
}

// 2. Assign balanced difficulty levels: '0' to '8'
// Target tiers:
// Easy (0, 1): 140
// Medium (2, 4, 5): 220
// Hard (3, 6, 7, 8): 240
const levelsPattern = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8',
  '0', '1', '2', '4', '5', '3', '6', '7', '8',
  '1', '2', '4', '5', '6', '8'
];

allNew.forEach((q, idx) => {
  q.Category = "خمن الأغنية";
  q.Level = levelsPattern[idx % levelsPattern.length];

  // Strip any parentheses just in case
  q.Q = q.Q.replace(/[()（）]/g, '');
  q.R = q.R.replace(/[()（）]/g, '');
  q.W1 = q.W1.replace(/[()（）]/g, '');
  q.W2 = q.W2.replace(/[()（）]/g, '');
  q.W3 = q.W3.replace(/[()（）]/g, '');

  // Validation
  if (!q.Q || !q.R || !q.W1 || !q.W2 || !q.W3) {
    throw new Error(`Empty field in question ${idx}: ${JSON.stringify(q)}`);
  }

  const set = new Set([q.R.trim(), q.W1.trim(), q.W2.trim(), q.W3.trim()]);
  if (set.size !== 4) {
    throw new Error(`Duplicate options in question ${idx}: R="${q.R}", W1="${q.W1}", W2="${q.W2}", W3="${q.W3}"`);
  }

  if (/[()]/.test(q.Q) || /[()]/.test(q.R) || /[()]/.test(q.W1) || /[()]/.test(q.W2) || /[()]/.test(q.W3)) {
    throw new Error(`Parenthesis detected in question ${idx}!`);
  }
});

// Check duplicate Qs within the batch
const seenQ = new Set();
allNew.forEach((q, idx) => {
  if (seenQ.has(q.Q)) {
    console.warn(`Duplicate Q at index ${idx}: ${q.Q}`);
  }
  seenQ.add(q.Q);
});

// 3. Read existing questions.json
const existing = JSON.parse(fs.readFileSync(ASSETS_PATH, 'utf8'));
console.log('Existing questions count:', existing.length);

// Filter out any existing 'خمن الأغنية' just in case
const cleaned = existing.filter(q => q.Category !== 'خمن الأغنية');
const finalQuestions = [...cleaned, ...allNew];
console.log('Final questions count:', finalQuestions.length);

// 4. Write to both assets/questions.json and android/app/src/main/assets/questions.json
const jsonStr = JSON.stringify(finalQuestions, null, 2);
fs.writeFileSync(ASSETS_PATH, jsonStr, 'utf8');
fs.writeFileSync(ANDROID_ASSETS_PATH, jsonStr, 'utf8');

const b1Check = fs.readFileSync(ASSETS_PATH);
const b2Check = fs.readFileSync(ANDROID_ASSETS_PATH);
console.log('Exact byte match:', b1Check.equals(b2Check), 'size:', b1Check.length);
console.log('Successfully added 600 questions for "خمن الأغنية"!');
