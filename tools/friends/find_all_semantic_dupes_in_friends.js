const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('Total original_friends.json:', orig.length);

function norm(s) {
  return s.replace(/[؟?.,!،؛:\"'’‘()]/g, '').replace(/[\u064B-\u0652]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي').replace(/\s+/g, ' ').trim();
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

    const w1 = new Set(nq1.split(' ').filter(w => w.length > 2));
    const w2 = new Set(nq2.split(' ').filter(w => w.length > 2));
    const common = [...w1].filter(w => w2.has(w));
    const union = new Set([...w1, ...w2]);
    const sim = common.length / union.size;

    // Check match
    const sameAns = nr1 === nr2 || (nr1.length > 4 && nr2.includes(nr1)) || (nr2.length > 4 && nr1.includes(nr2));

    // Check specific topics:
    const bothTanning = nq1.includes('تسمير') && nq2.includes('تسمير');
    const bothSmellyCat = (nq1.includes('اغنيه') || nq1.includes('قطه')) && (nq2.includes('اغنيه') || nq2.includes('قطه')) && (nr1.includes('كريهه') || nr2.includes('كريهه') || nr1.includes('smelly') || nr2.includes('smelly'));
    const bothJoeyJob = nq1.includes('جوي') && nq2.includes('جوي') && (nq1.includes('مهنه') || nq1.includes('مجال')) && (nq2.includes('مهنه') || nq2.includes('مجال'));
    const bothBirds = (nq1.includes('طائر') || nq1.includes('بطه')) && (nq2.includes('طائر') || nq2.includes('بطه'));
    const bothAtm = (nq1.includes('صراف') || nq1.includes('atm')) && (nq2.includes('صراف') || nq2.includes('atm'));
    const bothParis = (nq1.includes('مسافره') || nq1.includes('متجهه')) && (nq2.includes('مسافره') || nq2.includes('متجهه')) && (nr1.includes('باريس') && nr2.includes('باريس'));
    const bothMinsk = (nq1.includes('بيلاروسيا') || nq1.includes('فيزيائيه')) && (nq2.includes('بيلاروسيا') || nq2.includes('فيزيائيه')) && (nr1.includes('مينسك') && nr2.includes('مينسك'));
    const bothMoistMaker = nq1.includes('ساندويتش') && nq2.includes('ساندويتش') && (nr1.includes('مويست') || nr2.includes('مويست') || nr1.includes('moist') || nr2.includes('moist'));

    if (bothTanning || bothSmellyCat || bothJoeyJob || bothBirds || bothAtm || bothParis || bothMinsk || bothMoistMaker || (sameAns && sim >= 0.20 && !nr1.includes('موسم'))) {
      dupes.push({ i, j, sim: Number(sim.toFixed(2)), q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R });
    }
  }
}

console.log('Total semantic duplicates in Friends:', dupes.length);
dupes.forEach(d => {
  console.log(`\n[#${d.i} vs #${d.j}] (Sim: ${d.sim})`);
  console.log(`  Q1: ${d.q1} -> ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> ${d.r2}`);
});
