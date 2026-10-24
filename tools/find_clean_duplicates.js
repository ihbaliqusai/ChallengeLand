const fs = require('fs');

const report = JSON.parse(fs.readFileSync('./tools/audit_duplicates_summary.json', 'utf8'));

console.log('=== All Categories with Real Duplicate Questions ===');
let totalRealDupes = 0;

report.forEach(r => {
  // Filter out false positives (e.g. two math questions asking different things, or two Um Kulthum questions with different songs)
  const real = r.dupes.filter(d => {
    if (d.type === 'exact_question') return true;
    if (d.type === 'same_answer_and_similar_q') {
      // Exclude different songs or different events with same answer
      if (r.category === 'كلثوميات' || r.category === 'فيروز') {
        return false; // Different songs by same composer/poet
      }
      if (r.category === 'ركز شوي' || r.category === 'ألغاز' || r.category === 'جغرافيا' || r.category === 'تاريخ') {
        if (d.sim < 0.6) return false;
      }
      return d.sim >= 0.40;
    }
    return false;
  });

  if (real.length > 0) {
    console.log(`\nCategory: "${r.category}" (${real.length} duplicates):`);
    totalRealDupes += real.length;
    real.forEach(d => {
      console.log(`  - [#${d.i} vs #${d.j}] (Sim: ${d.sim})`);
      console.log(`    Q1: ${d.q1} -> R: ${d.r1}`);
      console.log(`    Q2: ${d.q2} -> R: ${d.r2}`);
    });
  }
});

console.log(`\nTotal real duplicates found (excluding Friends): ${totalRealDupes}`);
