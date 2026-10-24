const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const ASSETS_PATH = path.join(ROOT_DIR, 'assets/questions.json');
const ANDROID_ASSETS_PATH = path.join(ROOT_DIR, 'android/app/src/main/assets/questions.json');

const newQuestions = require('./observation_questions.js');
console.log('Observation questions count:', newQuestions.length);

// Audit questions
newQuestions.forEach((q, idx) => {
  if (!q.Q || !q.R || !q.W1 || !q.W2 || !q.W3 || !q.Img) {
    throw new Error(`Missing field in observation question #${idx}: ${JSON.stringify(q)}`);
  }
  const opts = [q.R.trim(), q.W1.trim(), q.W2.trim(), q.W3.trim()];
  const set = new Set(opts);
  if (set.size !== 4) {
    throw new Error(`Duplicate options in question #${idx}: ${opts.join(', ')}`);
  }
  if (/[()]/.test(q.Q) || /[()]/.test(q.R) || /[()]/.test(q.W1) || /[()]/.test(q.W2) || /[()]/.test(q.W3)) {
    throw new Error(`Parentheses detected in question #${idx}!`);
  }
});
console.log('All observation questions validated successfully.');

// Read existing questions.json
const raw = fs.readFileSync(ASSETS_PATH, 'utf8');
const existing = JSON.parse(raw);
console.log('Existing questions total:', existing.length);

// Filter out any existing 'دقة ملاحظة'
const cleaned = existing.filter(q => q.Category !== 'دقة ملاحظة');
const finalQuestions = [...cleaned, ...newQuestions];
console.log('Final questions total:', finalQuestions.length);

const outStr = JSON.stringify(finalQuestions, null, 2);
fs.writeFileSync(ASSETS_PATH, outStr, 'utf8');
fs.writeFileSync(ANDROID_ASSETS_PATH, outStr, 'utf8');

const b1 = fs.readFileSync(ASSETS_PATH);
const b2 = fs.readFileSync(ANDROID_ASSETS_PATH);
console.log('Exact byte match:', b1.equals(b2), 'size:', b1.length);
console.log('Successfully updated questions.json with "دقة ملاحظة" questions!');
