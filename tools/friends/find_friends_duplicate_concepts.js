const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
const friends = qs.map((q, idx) => ({ ...q, globalIdx: idx })).filter(q => q.Category === 'مسلسل Friends');

console.log('Total Friends questions:', friends.length);

// Let's find all questions in Friends with:
// 1. Identical answer (case-insensitive)
// 2. High semantic overlap (talking about the same event, fact, or item)
const answerMap = new Map();
friends.forEach((q, i) => {
  const ans = q.R.trim().toLowerCase();
  if (!answerMap.has(ans)) answerMap.set(ans, []);
  answerMap.get(ans).push({ i, ...q });
});

console.log('--- Duplicate Answers in Friends ---');
for (const [ans, list] of answerMap.entries()) {
  if (list.length > 1) {
    console.log(`\nAnswer: "${ans}" (${list.length} questions):`);
    list.forEach(q => {
      console.log(`  [#${q.i} | global ${q.globalIdx}] Q: ${q.Q}`);
    });
  }
}
