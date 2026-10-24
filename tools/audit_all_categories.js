const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));

// Group by category
const byCat = {};
qs.forEach((q, idx) => {
  if (!byCat[q.Category]) byCat[q.Category] = [];
  byCat[q.Category].push({ ...q, globalIdx: idx });
});

console.log('Total categories:', Object.keys(byCat).length);

const results = [];

for (const [cat, items] of Object.entries(byCat)) {
  const catDupes = [];

  for (let i = 0; i < items.length; i++) {
    for (let j = i + 1; j < items.length; j++) {
      const q1 = items[i];
      const q2 = items[j];

      // Clean text for comparison
      const cleanQ1 = q1.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();
      const cleanQ2 = q2.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();

      const r1 = q1.R.toLowerCase().trim();
      const r2 = q2.R.toLowerCase().trim();

      // Word-based Jaccard similarity
      const words1 = new Set(cleanQ1.split(/\s+/).filter(w => w.length > 2));
      const words2 = new Set(cleanQ2.split(/\s+/).filter(w => w.length > 2));
      const common = [...words1].filter(w => words2.has(w));
      const union = new Set([...words1, ...words2]);
      const sim = union.size > 0 ? common.length / union.size : 0;

      // Duplicate detection criteria:
      // 1. Same exact or normalized question text
      // 2. Exact same answer AND question similarity > 0.3
      // 3. Very high question similarity (> 0.65)
      if (cleanQ1 === cleanQ2) {
        catDupes.push({
          type: 'exact_question',
          i: q1.globalIdx, j: q2.globalIdx,
          q1: q1.Q, r1: q1.R,
          q2: q2.Q, r2: q2.R,
          sim: 1.0
        });
      } else if (r1 === r2 && sim >= 0.30) {
        catDupes.push({
          type: 'same_answer_and_similar_q',
          i: q1.globalIdx, j: q2.globalIdx,
          q1: q1.Q, r1: q1.R,
          q2: q2.Q, r2: q2.R,
          sim: Number(sim.toFixed(2))
        });
      } else if (sim >= 0.70) {
        catDupes.push({
          type: 'high_similarity_q',
          i: q1.globalIdx, j: q2.globalIdx,
          q1: q1.Q, r1: q1.R,
          q2: q2.Q, r2: q2.R,
          sim: Number(sim.toFixed(2))
        });
      }
    }
  }

  if (catDupes.length > 0) {
    results.push({ category: cat, count: catDupes.length, dupes: catDupes });
  }
}

console.log('Categories with duplicate questions:', results.length);
results.forEach(r => {
  console.log(`\n=== Category "${r.category}": ${r.count} duplicate pairs ===`);
  r.dupes.forEach(d => {
    console.log(`  [${d.type}] (#${d.i} vs #${d.j}) Sim: ${d.sim}`);
    console.log(`    Q1: ${d.q1} -> R: ${d.r1}`);
    console.log(`    Q2: ${d.q2} -> R: ${d.r2}`);
  });
});

fs.writeFileSync('./tools/audit_duplicates_summary.json', JSON.stringify(results, null, 2));
