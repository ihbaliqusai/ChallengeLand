const fs = require('fs');
const b4 = require('./vetted_batch4.js');
const t4 = require('./fusha_tashkeel_b4.js');
const { auditBatch } = require('./audit_utils.js');

console.log('b4 length:', b4.length, 't4 length:', t4.length);
b4.forEach((item, idx) => {
  item.fusha = t4[idx];
});

const questions = b4.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

const res = auditBatch(questions, 'Batch 4 with Tashkeel');
console.log('Audit result:', res);
if (res.errorCount === 0 && res.warnCount === 0) {
  fs.writeFileSync(__dirname + '/batch4.json', JSON.stringify(questions, null, 2), 'utf8');
  console.log('Successfully saved batch4.json with tashkeel!');
}
