const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));
console.log('original_friends.json count:', orig.length);

function normalize(q) {
  return q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();
}

const dupes = [];
for (let i = 0; i < orig.length; i++) {
  for (let j = i + 1; j < orig.length; j++) {
    const q1 = orig[i];
    const q2 = orig[j];
    
    const clean1 = normalize(q1.Q);
    const clean2 = normalize(q2.Q);
    
    const r1 = q1.R.trim();
    const r2 = q2.R.trim();
    
    const words1 = new Set(clean1.split(/\s+/).filter(w => w.length > 2));
    const words2 = new Set(clean2.split(/\s+/).filter(w => w.length > 2));
    const common = [...words1].filter(w => words2.has(w));
    const union = new Set([...words1, ...words2]);
    const sim = union.size > 0 ? common.length / union.size : 0;
    
    // Check if duplicate:
    // 1. Same clean question
    // 2. High question similarity and same topic
    // 3. Same answer and similarity >= 0.25
    if (clean1 === clean2) {
      dupes.push({ type: 'exact_Q', i, j, q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R, sim: 1 });
    } else if (r1 === r2 && sim >= 0.25) {
      dupes.push({ type: 'same_R_and_sim_Q', i, j, q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R, sim: Number(sim.toFixed(2)) });
    } else if (sim >= 0.50) {
      dupes.push({ type: 'high_sim_Q', i, j, q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R, sim: Number(sim.toFixed(2)) });
    }
  }
}

console.log('Duplicate pairs found in original_friends.json:', dupes.length);
dupes.forEach(d => {
  console.log(`\n[${d.type}] (#${d.i} vs #${d.j}) Sim: ${d.sim}`);
  console.log(`  Q1: ${d.q1} -> ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> ${d.r2}`);
});
