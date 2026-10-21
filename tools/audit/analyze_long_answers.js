const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const longQs = [];
const catCounts = {};

qs.forEach((q, idx) => {
  const len = q.R.trim().length;
  if (len > 30) {
    catCounts[q.Category] = (catCounts[q.Category] || 0) + 1;
    longQs.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R, len });
  }
});

console.log('Total questions with R length > 30 chars:', longQs.length);
console.log('Long answers by category:', catCounts);

// Sort by length descending
longQs.sort((a,b) => b.len - a.len);

console.log('\nTop 15 longest answers:');
longQs.slice(0, 15).forEach(x => {
  console.log(`[${x.idx}] (${x.cat}, len ${x.len})\nQ: ${x.q}\nR: ${x.r}\n`);
});
