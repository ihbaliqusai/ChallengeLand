const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const englishQs = [];
const catCounts = {};

qs.forEach((q, idx) => {
  const hasLatinR = /[a-zA-Z]/.test(q.R);
  if (hasLatinR) {
    catCounts[q.Category] = (catCounts[q.Category] || 0) + 1;
    const hintLatinQ = /(إنجليز|انجليز|English|باللاتيني|بالحروف الإنجليزية|اكتب بالإنجليزية)/i.test(q.Q);
    englishQs.push({
      idx,
      cat: q.Category,
      lvl: q.Level,
      q: q.Q,
      r: q.R,
      hasHint: hintLatinQ
    });
  }
});

console.log('Total questions with English in R:', englishQs.length);
console.log('Questions by category:', catCounts);
console.log('Already have hint in Q:', englishQs.filter(x => x.hasHint).length);
console.log('Need hint in Q:', englishQs.filter(x => !x.hasHint).length);

// Sample of questions without hint in different categories
const sample = {};
englishQs.filter(x => !x.hasHint).forEach(x => {
  if (!sample[x.cat]) sample[x.cat] = [];
  if (sample[x.cat].length < 3) sample[x.cat].push(x);
});

fs.writeFileSync(path.join(__dirname, 'english_answers_analysis.json'), JSON.stringify({
  total: englishQs.length,
  catCounts,
  sample
}, null, 2), 'utf8');

console.log('\nSample categories with English answers:');
Object.keys(sample).slice(0, 10).forEach(c => {
  console.log(`\nCategory: ${c}`);
  sample[c].forEach(s => console.log(`  [${s.idx}] Q: ${s.q} -> R: ${s.r}`));
});
