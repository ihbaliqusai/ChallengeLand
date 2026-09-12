const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
console.log('Total questions in database:', qs.length);

function normalizeText(text) {
  if (!text) return '';
  return text
    .replace(/[؟?.,!،؛:\"'’‘()]/g, '')
    .replace(/[\u064B-\u0652]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim();
}

// 1. Check exact / normalized question text duplicates across the entire file
const seenNormQ = new Map();
const duplicates = [];

qs.forEach((q, idx) => {
  const nq = normalizeText(q.Q);
  const key = `${q.Category}:::${nq}`;
  if (seenNormQ.has(key)) {
    duplicates.push({
      type: 'exact_or_norm_Q',
      category: q.Category,
      originalIndex: seenNormQ.get(key),
      duplicateIndex: idx,
      q1: qs[seenNormQ.get(key)].Q,
      r1: qs[seenNormQ.get(key)].R,
      q2: q.Q,
      r2: q.R
    });
  } else {
    seenNormQ.set(key, idx);
  }
});

console.log('Total normalized question duplicates (same category):', duplicates.length);
duplicates.forEach(d => {
  console.log(`\nCategory: ${d.category}`);
  console.log(`  [#${d.originalIndex}] Q1: ${d.q1} -> R: ${d.r1}`);
  console.log(`  [#${d.duplicateIndex}] Q2: ${d.q2} -> R: ${d.r2}`);
});

// 2. Cross-category duplicates
const crossSeen = new Map();
const crossDupes = [];
qs.forEach((q, idx) => {
  const nq = normalizeText(q.Q);
  if (crossSeen.has(nq)) {
    const orig = crossSeen.get(nq);
    if (orig.Category !== q.Category) {
      crossDupes.push({
        cat1: orig.Category,
        idx1: orig.idx,
        q1: orig.Q,
        cat2: q.Category,
        idx2: idx,
        q2: q.Q
      });
    }
  } else {
    crossSeen.set(nq, { ...q, idx });
  }
});
console.log('\nTotal cross-category duplicates:', crossDupes.length);
crossDupes.forEach(d => {
  console.log(`  [${d.cat1} #${d.idx1}] vs [${d.cat2} #${d.idx2}]: ${d.q1}`);
});
