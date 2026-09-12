const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
console.log('Total questions in assets/questions.json:', qs.length);

function normalizeText(text) {
  if (!text) return '';
  return text
    .replace(/[؟?.,!،؛:\"'’‘()]/g, '')
    .replace(/[\u064B-\u0652]/g, '') // remove arabic tashkeel
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim();
}

// 1. Group by category
const catMap = {};
qs.forEach((q, idx) => {
  if (!catMap[q.Category]) catMap[q.Category] = [];
  catMap[q.Category].push({ ...q, originalIndex: idx });
});

console.log('Categories count:', Object.keys(catMap).length);

const allDupes = [];

for (const [cat, items] of Object.entries(catMap)) {
  const seenExact = new Map();
  const seenNorm = new Map();
  const catDupes = [];

  items.forEach(item => {
    const rawQ = item.Q.trim();
    const normQ = normalizeText(rawQ);

    if (seenExact.has(rawQ)) {
      catDupes.push({
        type: 'exact',
        category: cat,
        originalIndex: seenExact.get(rawQ).originalIndex,
        dupeIndex: item.originalIndex,
        Q: rawQ,
        R: item.R,
        origR: seenExact.get(rawQ).R
      });
    } else {
      seenExact.set(rawQ, item);
    }

    if (seenNorm.has(normQ)) {
      if (!seenExact.has(rawQ) || seenExact.get(rawQ).originalIndex !== item.originalIndex) {
        // Only if not already recorded as exact
        const alreadyExact = catDupes.some(d => d.dupeIndex === item.originalIndex);
        if (!alreadyExact) {
          catDupes.push({
            type: 'normalized',
            category: cat,
            originalIndex: seenNorm.get(normQ).originalIndex,
            dupeIndex: item.originalIndex,
            Q: rawQ,
            origQ: seenNorm.get(normQ).Q,
            R: item.R,
            origR: seenNorm.get(normQ).R
          });
        }
      }
    } else {
      seenNorm.set(normQ, item);
    }
  });

  if (catDupes.length > 0) {
    console.log(`Category "${cat}": found ${catDupes.length} duplicate questions`);
    allDupes.push(...catDupes);
  }
}

console.log(`\nTotal duplicate questions found within same category: ${allDupes.length}`);
fs.writeFileSync('./tools/duplicates_report.json', JSON.stringify(allDupes, null, 2));

// Show details for Friends specifically, since user was on Friends:
const friendsDupes = allDupes.filter(d => d.category === 'مسلسل Friends');
console.log(`\n"مسلسل Friends" duplicates count: ${friendsDupes.length}`);
friendsDupes.forEach((d, i) => {
  console.log(`${i + 1}. [${d.type}] Dupe #${d.dupeIndex} matches #${d.originalIndex}:`);
  console.log(`   Q1: ${d.origQ || d.Q} | R1: ${d.origR}`);
  console.log(`   Q2: ${d.Q} | R2: ${d.R}`);
});
