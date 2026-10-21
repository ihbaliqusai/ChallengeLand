const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const optionPhrases = [
  /أي مما يلي/i, /أي من التالية/i, /أي من الآتي/i, /أياً مما يلي/i, /أي مما يأتي/i,
  /أي الخيارات/i, /أي من هذه/i, /أي من هؤلاء/i, /أي هذه/i, /أي من التالي/i,
  /أيها/i, /أي العبارات التالية/i, /أي الجمل التالية/i, /أي الكلمات التالية/i,
  /أيهما/i, /أي الآتي/i
];

const optionDependent = [];

qs.forEach((q, idx) => {
  for (const p of optionPhrases) {
    if (p.test(q.Q)) {
      optionDependent.push({ idx, q: q.Q, r: q.R, cat: q.Category, lvl: q.Level, choices: [q.R, q.W1, q.W2, q.W3] });
      break;
    }
  }
});

console.log('Total option phrase questions:', optionDependent.length);
fs.writeFileSync(path.join(__dirname, 'option_dependent.json'), JSON.stringify(optionDependent, null, 2), 'utf8');

// Print first 20
console.log(JSON.stringify(optionDependent.slice(0, 20), null, 2));
