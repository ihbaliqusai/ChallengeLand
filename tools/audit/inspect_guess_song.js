const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const songQs = qs.filter(q => q.Category === 'خمن الأغنية');
console.log('Total خمن الأغنية questions:', songQs.length);

console.log('Sample first 10:');
songQs.slice(0, 10).forEach((q, i) => {
  console.log(`\n[${i}] Level: ${q.Level}`);
  console.log(`Q: ${q.Q}`);
  console.log(`R: ${q.R}`);
  console.log(`W: ${[q.W1, q.W2, q.W3].join(' | ')}`);
});
