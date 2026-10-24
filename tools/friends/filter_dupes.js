const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

const dupes = [];
for (let i = 0; i < orig.length; i++) {
  for (let j = i + 1; j < orig.length; j++) {
    const q1 = orig[i];
    const q2 = orig[j];
    
    const r1 = q1.R.trim();
    const r2 = q2.R.trim();
    
    const w1 = q1.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2);
    const w2 = q2.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2);
    const s1 = new Set(w1);
    const s2 = new Set(w2);
    const common = [...s1].filter(w => s2.has(w));
    const union = new Set([...s1, ...s2]);
    const sim = union.size > 0 ? common.length / union.size : 0;
    
    if (r1 === r2 && !r1.includes('الموسم')) {
      dupes.push({ i, j, sim: sim.toFixed(2), q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R, type: 'Same non-season answer' });
    } else if (sim >= 0.45 && !r1.includes('الموسم')) {
      dupes.push({ i, j, sim: sim.toFixed(2), q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R, type: 'High Q similarity' });
    }
  }
}

console.log('Duplicates count:', dupes.length);
dupes.forEach((d, idx) => {
  console.log(`\n#${idx + 1} [${d.type}] (${d.i} & ${d.j}) Sim: ${d.sim}`);
  console.log(`  Q1: ${d.q1} -> R: ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> R: ${d.r2}`);
});
