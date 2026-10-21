const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const philosophers = ['أرسطو', 'أفلاطون', 'سقراط', 'كانط', 'ديكارت', 'نيتشه', 'ابن رشد', 'ابن سينا', 'الفارابي', 'الملل والنحل'];

const found = [];
qs.forEach((q, idx) => {
  philosophers.forEach(p => {
    if ((q.Q + ' ' + q.R).includes(p)) {
      found.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R });
    }
  });
});

console.log('Philosopher/theology questions found:', found.length);
found.forEach(f => {
  console.log(`[${f.idx}] (${f.cat}, lvl ${f.lvl}) Q: ${f.q} -> R: ${f.r}`);
});
