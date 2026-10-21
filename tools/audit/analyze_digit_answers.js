const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const digitQs = [];
const catCounts = {};

qs.forEach((q, idx) => {
  const isDigitsR = /^\d+$/.test(q.R.trim());
  if (isDigitsR) {
    catCounts[q.Category] = (catCounts[q.Category] || 0) + 1;
    const hintDigitsQ = /(أرقام|ارقام|بالأرقام|بالارقام|عدداً|رقماً|اكتب الرقم|بالأرقام فقط)/i.test(q.Q);
    digitQs.push({
      idx,
      cat: q.Category,
      lvl: q.Level,
      q: q.Q,
      r: q.R,
      hasHint: hintDigitsQ
    });
  }
});

console.log('Total questions with pure digits in R:', digitQs.length);
console.log('Questions by category:', catCounts);
console.log('Already have hint in Q:', digitQs.filter(x => x.hasHint).length);
console.log('Need hint in Q:', digitQs.filter(x => !x.hasHint).length);

// Sample
const sample = {};
digitQs.filter(x => !x.hasHint).forEach(x => {
  if (!sample[x.cat]) sample[x.cat] = [];
  if (sample[x.cat].length < 2) sample[x.cat].push(x);
});

console.log('\nSample categories with pure digit answers:');
Object.keys(sample).slice(0, 10).forEach(c => {
  console.log(`\nCategory: ${c}`);
  sample[c].forEach(s => console.log(`  [${s.idx}] Q: ${s.q} -> R: ${s.r}`));
});
