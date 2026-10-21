const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const remaining = qs.map((q, idx) => ({ ...q, idx })).filter(q => q.R.trim().length > 45);
console.log('Remaining > 45 chars:', remaining.length);
const cats = {};
remaining.forEach(r => cats[r.Category] = (cats[r.Category] || 0) + 1);
console.log('By category:', cats);

console.log('Sample first 10:');
remaining.slice(0, 10).forEach(r => {
  console.log(`[${r.idx}] (${r.Category}, len ${r.R.length})\nQ: ${r.Q}\nR: ${r.R}\n`);
});
