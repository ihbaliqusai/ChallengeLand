const fs = require('fs');
const path = require('path');
const { auditBatch } = require('./audit_utils.js');

const ASSETS_PATH = path.resolve(__dirname, '../../assets/questions.json');
const ANDROID_ASSETS_PATH = path.resolve(__dirname, '../../android/app/src/main/assets/questions.json');

// 1. Check exact byte equality
const b1 = fs.readFileSync(ASSETS_PATH);
const b2 = fs.readFileSync(ANDROID_ASSETS_PATH);
if (!b1.equals(b2)) {
  console.error('ERROR: assets and android assets do not match!');
  process.exit(1);
}
console.log('PASS: assets/questions.json and android/app/src/main/assets/questions.json match exactly! (Byte size:', b1.length, ')');

// 2. Parse and filter
const all = JSON.parse(b1.toString('utf8'));
const songQuestions = all.filter(q => q.Category === 'خمن الأغنية');
console.log('Total questions in file:', all.length);
console.log('Total "خمن الأغنية" questions:', songQuestions.length);

if (songQuestions.length !== 600) {
  console.error('ERROR: Expected 600 questions, found:', songQuestions.length);
  process.exit(1);
}

// 3. Run audit engine on all 600 questions
const result = auditBatch(songQuestions, 'ALL 600 FINAL GUESS THE SONG QUESTIONS');

// 4. Check level distribution
const levels = {};
songQuestions.forEach(q => {
  levels[q.Level] = (levels[q.Level] || 0) + 1;
});
console.log('Level distribution:', levels);

// 5. Check no duplicate Qs
const qMap = new Map();
let dupQCount = 0;
songQuestions.forEach((q, idx) => {
  if (qMap.has(q.Q)) {
    console.warn(`Duplicate Q found at #${idx} and #${qMap.get(q.Q)}: ${q.Q}`);
    dupQCount++;
  } else {
    qMap.set(q.Q, idx);
  }
});
console.log('Duplicate Q count:', dupQCount);

if (result.errorCount === 0 && dupQCount === 0) {
  console.log('\n=========================================');
  console.log('>>> 100% VERIFICATION COMPLETE AND PASSED <<<');
  console.log('=========================================\n');
} else {
  console.error('VERIFICATION FAILED!');
  process.exit(1);
}
