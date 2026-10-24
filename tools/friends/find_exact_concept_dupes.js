const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

// Normalize Arabic text for semantic matching
function norm(str) {
  return str
    .replace(/[؟?.,!،؛:\"'’‘()]/g, '')
    .replace(/[\u064B-\u0652]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim();
}

const dupes = [];
for (let i = 0; i < orig.length; i++) {
  for (let j = i + 1; j < orig.length; j++) {
    const q1 = orig[i];
    const q2 = orig[j];

    const nq1 = norm(q1.Q);
    const nq2 = norm(q2.Q);

    const nr1 = norm(q1.R);
    const nr2 = norm(q2.R);

    // If answers are identical or very close
    const sameAnswer = (nr1 === nr2) || (nr1.length > 4 && nr2.includes(nr1)) || (nr2.length > 4 && nr1.includes(nr2));

    // Word similarity
    const w1 = new Set(nq1.split(' ').filter(w => w.length > 2));
    const w2 = new Set(nq2.split(' ').filter(w => w.length > 2));
    const common = [...w1].filter(w => w2.has(w));
    const union = new Set([...w1, ...w2]);
    const sim = common.length / union.size;

    if (sameAnswer && sim >= 0.25) {
      dupes.push({
        i, j,
        sim: Number(sim.toFixed(2)),
        q1: q1.Q, r1: q1.R,
        q2: q2.Q, r2: q2.R
      });
    }
  }
}

console.log('Real duplicate questions in original_friends.json:', dupes.length);
dupes.forEach(d => {
  console.log(`\n[#${d.i} vs #${d.j}] (Sim: ${d.sim})`);
  console.log(`  Q1: ${d.q1} -> ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> ${d.r2}`);
});
