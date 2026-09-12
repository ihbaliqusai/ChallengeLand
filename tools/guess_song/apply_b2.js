const fs = require('fs');
const b2 = require('./vetted_batch2.js');
const t2 = require('./fusha_tashkeel_b2.js');
const { auditBatch } = require('./audit_utils.js');

console.log('b2 length:', b2.length, 't2 length:', t2.length);
b2.forEach((item, idx) => {
  item.fusha = t2[idx];
});

const questions = b2.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

const res = auditBatch(questions, 'Batch 2 with Tashkeel');
console.log('Audit result:', res);
if (res.errorCount === 0 && res.warnCount === 0) {
  fs.writeFileSync(__dirname + '/batch2.json', JSON.stringify(questions, null, 2), 'utf8');
  console.log('Successfully saved batch2.json with tashkeel!');
}
