const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const emojiCats = ['خمن الصورة', 'خمن الاسم', 'خمن الأكلة', 'خمن المدينة او الدولة'];

emojiCats.forEach(cat => {
  const catQs = qs.filter(q => q.Category === cat);
  console.log(`\n=================== ${cat} (Total: ${catQs.length}) ===================`);
  // Check for questions without emoji
  const withoutEmoji = catQs.filter(q => !/[\u{1F300}-\u{1F9FF}]/u.test(q.Q));
  console.log('Without standard emoji:', withoutEmoji.length);
  if (withoutEmoji.length > 0) {
    console.log('Sample without emoji:', withoutEmoji.slice(0, 3));
  }
  // Check levels
  const lvls = {};
  catQs.forEach(q => lvls[q.Level] = (lvls[q.Level] || 0) + 1);
  console.log('Levels:', lvls);
  // Show 3 easy, 3 med, 3 hard
  console.log('-- Sample Easy (lvl 0,1,2) --');
  catQs.filter(q => ['0','1','2'].includes(q.Level)).slice(0, 3).forEach(q => console.log(`  [lvl ${q.Level}] Q: ${q.Q} -> R: ${q.R}`));
  console.log('-- Sample Med (lvl 4,5,6) --');
  catQs.filter(q => ['4','5','6'].includes(q.Level)).slice(0, 3).forEach(q => console.log(`  [lvl ${q.Level}] Q: ${q.Q} -> R: ${q.R}`));
  console.log('-- Sample Hard (lvl 3,7,8) --');
  catQs.filter(q => ['3','7','8'].includes(q.Level)).slice(0, 3).forEach(q => console.log(`  [lvl ${q.Level}] Q: ${q.Q} -> R: ${q.R}`));
});
