const fs = require('fs');
const b1 = require('./vetted_batch1.js');
const t1 = require('./fusha_tashkeel_b1.js');
const { auditBatch } = require('./audit_utils.js');

console.log('b1 length:', b1.length, 't1 length:', t1.length);
b1.forEach((item, idx) => {
  item.fusha = t1[idx];
});

const questions = b1.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

const res = auditBatch(questions, 'Batch 1 with Tashkeel');
console.log('Audit result:', res);
if (res.errorCount === 0 && res.warnCount === 0) {
  fs.writeFileSync(__dirname + '/batch1.json', JSON.stringify(questions, null, 2), 'utf8');
  console.log('Successfully saved batch1.json with tashkeel!');
}
