const fs = require('fs');
const rawList = require('./vetted_batch4.js');

const questions = rawList.map(s => ({
  Level: s.lvl,
  Q: `ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى: "${s.fusha}"؟`,
  R: `${s.r_song} - ${s.r_art}`,
  W1: `${s.w1_song} - ${s.w1_art}`,
  W2: `${s.w2_song} - ${s.w2_art}`,
  W3: `${s.w3_song} - ${s.w3_art}`,
  Category: 'خمن الأغنية'
}));

fs.writeFileSync(__dirname + '/batch4.json', JSON.stringify(questions, null, 2), 'utf8');
console.log('Saved batch4.json with', questions.length, 'questions');
