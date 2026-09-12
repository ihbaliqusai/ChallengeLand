const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('Total original_friends.json:', orig.length);

const pairs = [];
for (let i = 0; i < orig.length; i++) {
  for (let j = i + 1; j < orig.length; j++) {
    const q1 = orig[i];
    const q2 = orig[j];

    const r1 = q1.R.trim();
    const r2 = q2.R.trim();

    // Check if same question or identical concept:
    const words1 = new Set(q1.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2));
    const words2 = new Set(q2.Q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').split(/\s+/).filter(w => w.length > 2));
    const common = [...words1].filter(w => words2.has(w));
    const union = new Set([...words1, ...words2]);
    const sim = common.length / union.size;

    // Check specific known semantic duplicates:
    const isSmellyCat = (q1.Q.includes('القطة') || q1.Q.includes('أغنية')) && (q2.Q.includes('القطة') || q2.Q.includes('أغنية')) && (r1.includes('الكريهة') || r2.includes('الكريهة') || r1.includes('Smelly') || r2.includes('Smelly'));
    const isJoeyActor = q1.Q.includes('جوي') && q2.Q.includes('جوي') && (q1.Q.includes('المهنة') || q1.Q.includes('المجال الفني')) && (q2.Q.includes('المهنة') || q2.Q.includes('المجال الفني'));
    const isBirds = (q1.Q.includes('طائر') || q1.Q.includes('الطائر')) && (q2.Q.includes('طائر') || q2.Q.includes('الطائر'));
    const isCentralPerk = q1.Q.includes('اسم المقهى') && q2.Q.includes('اسم المقهى');
    const isMarcelName = q1.Q.includes('اسم القرد') && q2.Q.includes('اسم القرد');
    const isEmmaName = q1.Q.includes('اسم ابنة روس') && q2.Q.includes('اسم ابنة روس');
    const isBenName = q1.Q.includes('اسم ابن روس') && q2.Q.includes('اسم ابن روس');
    const isPhoebeJob = q1.Q.includes('فيبي') && q2.Q.includes('فيبي') && (q1.Q.includes('العمل الحر') || q1.Q.includes('مهنة')) && (q2.Q.includes('العمل الحر') || q2.Q.includes('مهنة'));
    const isApothecary = q1.Q.includes('طاولة الصيدلية') && q2.Q.includes('طاولة الصيدلية');
    const isBananaHammock = q1.Q.includes('كونسويلا') && q2.Q.includes('كونسويلا');
    const isApartmentNumber = q1.Q.includes('الرقمان الأصليان') && q2.Q.includes('الرقمان الأصليان');

    if (sim >= 0.40 || isSmellyCat || isJoeyActor || isBirds || isCentralPerk || isMarcelName || isEmmaName || isBenName || isPhoebeJob || isApothecary || isBananaHammock || isApartmentNumber) {
      pairs.push({
        i, j,
        sim: Number(sim.toFixed(2)),
        q1: q1.Q, r1: q1.R,
        q2: q2.Q, r2: q2.R
      });
    }
  }
}

console.log('Duplicates / overlaps in Friends:', pairs.length);
pairs.forEach((p, idx) => {
  console.log(`\n#${idx + 1} (${p.i} vs ${p.j}) Sim: ${p.sim}`);
  console.log(`  Q1: ${p.q1} -> R: ${p.r1}`);
  console.log(`  Q2: ${p.q2} -> R: ${p.r2}`);
});
