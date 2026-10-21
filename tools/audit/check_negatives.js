const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const negRegexes = [
  /ليست من/i, /ليس من/i, /لا يعتبر/i, /لا تعتبر/i, /أي مما يلي لا/i, /أي من الآتي ليس/i,
  /أي مما يلي ليس/i, /أياً مما يلي ليس/i, /لا ينتمي/i, /لا تعد/i, /لا يعد/i, /غير صحيح/i,
  /أي الخيارات لا/i, /ما الذي لا/i, /أي من التالي لا/i, /أي مما يأتي لا/i, /أيها ليس/i,
  /أي .* ليس/i, /أي .* ليست/i, /ما .* ليس/i, /ما .* ليست/i
];

const found = [];
qs.forEach((q, idx) => {
  for (const r of negRegexes) {
    if (r.test(q.Q)) {
      found.push({ idx, q: q.Q, r: q.R, cat: q.Category, lvl: q.Level, choices: [q.R, q.W1, q.W2, q.W3] });
      break;
    }
  }
});

console.log('Found negative / option-dependent questions:', found.length);
found.forEach(item => {
  console.log(`\nIndex: ${item.idx} | Category: ${item.cat} | Level: ${item.lvl}`);
  console.log(`Q: ${item.q}`);
  console.log(`R: ${item.r}`);
  console.log(`Choices: ${item.choices.join(' | ')}`);
});
