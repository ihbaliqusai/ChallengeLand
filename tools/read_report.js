const fs = require('fs');

const report = JSON.parse(fs.readFileSync('./tools/audit_duplicates_summary.json', 'utf8'));

console.log('Categories analyzed with duplicates:', report.length);
report.forEach(r => {
  const realDupes = r.dupes.filter(d => d.type === 'exact_question' || (d.type === 'same_answer_and_similar_q' && d.sim >= 0.35));
  if (realDupes.length > 0) {
    console.log(`\nCategory "${r.category}": ${realDupes.length} duplicates:`);
    realDupes.forEach(d => {
      console.log(`  - [#${d.i} vs #${d.j}] (Sim: ${d.sim})`);
      console.log(`    Q1: ${d.q1} -> ${d.r1}`);
      console.log(`    Q2: ${d.q2} -> ${d.r2}`);
    });
  }
});
