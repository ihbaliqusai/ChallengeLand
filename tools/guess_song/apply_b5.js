const fs = require('fs');
const b5 = require('./vetted_batch5.js');
const t5 = require('./fusha_tashkeel_b5.js');
const { auditBatch } = require('./audit_utils.js');

console.log('b5 length:', b5.length, 't5 length:', t5.length);
b5.forEach((item, idx) => {
  item.fusha = t5[idx];
});

const questions = b5.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

const res = auditBatch(questions, 'Batch 5 with Tashkeel');
console.log('Audit result:', res);
if (res.errorCount === 0 && res.warnCount === 0) {
  fs.writeFileSync(__dirname + '/batch5.json', JSON.stringify(questions, null, 2), 'utf8');
  console.log('Successfully saved batch5.json with tashkeel!');
} else {
  console.error('Audit failed for Batch 5!');
  process.exit(1);
}
