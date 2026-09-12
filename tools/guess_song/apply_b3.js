const fs = require('fs');
const b3 = require('./vetted_batch3.js');
const t3 = require('./fusha_tashkeel_b3.js');
const { auditBatch } = require('./audit_utils.js');

console.log('b3 length:', b3.length, 't3 length:', t3.length);
b3.forEach((item, idx) => {
  item.fusha = t3[idx];
});

const questions = b3.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

const res = auditBatch(questions, 'Batch 3 with Tashkeel');
console.log('Audit result:', res);
if (res.errorCount === 0 && res.warnCount === 0) {
  fs.writeFileSync(__dirname + '/batch3.json', JSON.stringify(questions, null, 2), 'utf8');
  console.log('Successfully saved batch3.json with tashkeel!');
}
