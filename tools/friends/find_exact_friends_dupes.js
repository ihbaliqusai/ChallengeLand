const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

// Check duplicate questions in original_friends.json
const dupes = [];

for (let i = 0; i < orig.length; i++) {
  for (let j = i + 1; j < orig.length; j++) {
    const q1 = orig[i];
    const q2 = orig[j];

    // Check if both questions ask for the same answer / concept
    const r1 = q1.R.toLowerCase().trim();
    const r2 = q2.R.toLowerCase().trim();

    // Check key concept matches
    const isSameSmellyCat = (q1.Q.includes('القطة') || q1.Q.includes('أغنية')) && (q2.Q.includes('القطة') || q2.Q.includes('أغنية')) && (r1.includes('smelly') || r1.includes('الكريهة') || r2.includes('smelly') || r2.includes('الكريهة'));
    const isSameJoeyJob = (q1.Q.includes('جوي') && (q1.Q.includes('المهنة') || q1.Q.includes('المجال الفني') || q1.Q.includes('يسعى'))) && (q2.Q.includes('جوي') && (q2.Q.includes('المهنة') || q2.Q.includes('المجال الفني') || q2.Q.includes('يسعى')));
    const isSameBirds = (q1.Q.includes('الطائر') || q1.Q.includes('طائرين')) && (q2.Q.includes('الطائر') || q2.Q.includes('طائرين'));
    const isSameCafe = (q1.Q.includes('اسم المقهى') && q2.Q.includes('اسم المقهى'));
    const isSameMarcel = (q1.Q.includes('القرد') && q2.Q.includes('القرد') && (r1.includes('مارسيل') || r2.includes('مارسيل')));
    const isSameEmma = (q1.Q.includes('ابنة روس') && q2.Q.includes('ابنة روس'));
    const isSameBen = (q1.Q.includes('ابن روس') && q2.Q.includes('ابن روس'));
    const isSamePhoebeMassuese = (q1.Q.includes('فيبي') && (q1.Q.includes('مدلكة') || q1.Q.includes('العمل الحر') || q1.Q.includes('مهنة'))) && (q2.Q.includes('فيبي') && (q2.Q.includes('مدلكة') || q2.Q.includes('العمل الحر') || q2.Q.includes('مهنة')));

    if (isSameSmellyCat || isSameJoeyJob || isSameBirds || isSameCafe || isSameEmma || isSameBen || isSamePhoebeMassuese) {
      dupes.push({
        i, j,
        q1: q1.Q, r1: q1.R,
        q2: q2.Q, r2: q2.R
      });
    }
  }
}

console.log('Duplicate concept questions found:', dupes.length);
dupes.forEach(d => {
  console.log(`\n[#${d.i} vs #${d.j}]`);
  console.log(`  Q1: ${d.q1} -> ${d.r1}`);
  console.log(`  Q2: ${d.q2} -> ${d.r2}`);
});
