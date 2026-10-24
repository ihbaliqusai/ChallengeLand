const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
const friends = qs.map((q, idx) => ({ ...q, globalIdx: idx })).filter(q => q.Category === 'مسلسل Friends');

console.log('Total Friends questions:', friends.length);

const pairs = [];
for (let i = 0; i < friends.length; i++) {
  for (let j = i + 1; j < friends.length; j++) {
    const q1 = friends[i];
    const q2 = friends[j];
    
    const r1 = q1.R.toLowerCase().trim();
    const r2 = q2.R.toLowerCase().trim();
    
    const w1 = q1.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2);
    const w2 = q2.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2);
    const s1 = new Set(w1);
    const s2 = new Set(w2);
    const common = [...s1].filter(w => s2.has(w));
    const union = new Set([...s1, ...s2]);
    const sim = union.size > 0 ? common.length / union.size : 0;
    
    // Check match criteria:
    // 1. Same exact answer
    // 2. High question similarity
    // 3. One answer contained in another
    if (r1 === r2) {
      pairs.push({
        type: 'same_answer',
        i, j,
        q1Idx: q1.globalIdx, q2Idx: q2.globalIdx,
        sim: sim.toFixed(2),
        q1: q1.Q, r1: q1.R,
        q2: q2.Q, r2: q2.R
      });
    } else if (sim >= 0.35) {
      pairs.push({
        type: 'high_q_similarity',
        i, j,
        q1Idx: q1.globalIdx, q2Idx: q2.globalIdx,
        sim: sim.toFixed(2),
        q1: q1.Q, r1: q1.R,
        q2: q2.Q, r2: q2.R
      });
    }
  }
}

console.log('Potential duplicate pairs found:', pairs.length);
pairs.forEach((p, idx) => {
  console.log(`\n#${idx + 1} [${p.type}] [Indices: ${p.i} vs ${p.j} (global ${p.q1Idx} vs ${p.q2Idx})] Sim: ${p.sim}`);
  console.log(`  Q1: ${p.q1}`);
  console.log(`  R1: ${p.r1}`);
  console.log(`  Q2: ${p.q2}`);
  console.log(`  R2: ${p.r2}`);
});
