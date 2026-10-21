const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const veryLong = qs
  .map((q, idx) => ({ ...q, idx }))
  .filter(q => q.R.trim().length > 35);

console.log('Very long answers (>35 chars):', veryLong.length);

const byCat = {};
veryLong.forEach(v => {
  byCat[v.Category] = (byCat[v.Category] || 0) + 1;
});
console.log('By category:', byCat);

// Write to json for inspection
fs.writeFileSync(
  path.join(__dirname, 'very_long_answers.json'),
  JSON.stringify(veryLong.map(v => ({ idx: v.idx, cat: v.Category, q: v.Q, r: v.R, len: v.R.length })), null, 2),
  'utf8'
);
