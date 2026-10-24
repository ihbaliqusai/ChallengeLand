const { execSync } = require('child_process');
const fs = require('fs');

const out = execSync('git show df3a04f3:assets/questions.json', { maxBuffer: 50 * 1024 * 1024 }).toString();
const dfData = JSON.parse(out);
const dfFriends = dfData.filter(q => q.Category === 'مسلسل Friends');

console.log('dfFriends count:', dfFriends.length);

// Check duplicate questions in dfFriends
const dupes = [];
for (let i = 0; i < dfFriends.length; i++) {
  for (let j = i + 1; j < dfFriends.length; j++) {
    const q1 = dfFriends[i];
    const q2 = dfFriends[j];
    const clean1 = q1.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();
    const clean2 = q2.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();
    const words1 = new Set(clean1.split(/\s+/).filter(w => w.length > 2));
    const words2 = new Set(clean2.split(/\s+/).filter(w => w.length > 2));
    const common = [...words1].filter(w => words2.has(w));
    const union = new Set([...words1, ...words2]);
    const sim = union.size > 0 ? common.length / union.size : 0;
    
    if (clean1 === clean2 || (q1.R === q2.R && sim >= 0.35) || sim >= 0.65) {
      dupes.push({ i, j, sim: sim.toFixed(2), q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R });
    }
  }
}

console.log('Duplicates in dfFriends:', dupes.length);
dupes.forEach(d => {
  console.log(`\nPair (${d.i} & ${d.j}) Sim: ${d.sim}`);
  console.log(`  Q1: ${d.q1} -> ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> ${d.r2}`);
});
