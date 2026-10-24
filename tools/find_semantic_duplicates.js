const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));

// Check ALL categories for duplicate answers or semantic duplicates
const catMap = {};
qs.forEach((q, idx) => {
  if (!catMap[q.Category]) catMap[q.Category] = [];
  catMap[q.Category].push({ ...q, globalIndex: idx });
});

console.log('=== Checking Duplicate Answers per Category ===');

for (const [cat, items] of Object.entries(catMap)) {
  const ansMap = new Map();
  items.forEach(item => {
    const normR = item.R.trim().toLowerCase();
    if (!ansMap.has(normR)) ansMap.set(normR, []);
    ansMap.get(normR).push(item);
  });

  const dupes = [];
  for (const [ans, list] of ansMap.entries()) {
    if (list.length > 1) {
      dupes.push({ ans, list });
    }
  }

  if (dupes.length > 0) {
    console.log(`\nCategory: "${cat}" (${items.length} questions) has ${dupes.length} answers repeated:`);
    dupes.forEach(d => {
      console.log(`  Answer "${d.ans}" (${d.list.length} times):`);
      d.list.forEach(q => {
        console.log(`    - [#${q.globalIndex}] Q: ${q.Q}`);
      });
    });
  }
}
