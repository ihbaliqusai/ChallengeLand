const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

const keywords = [
  'المقهى', 'سنترال بيرك', 'القطة', 'شارة', 'الأريكة', 'انفصال', 'تريبياني',
  'مارسيل', 'القرد', 'البطة', 'الديك', 'جانيس', 'غانثر', 'إيما', 'كارول', 'سوزان',
  'ريتشارد', 'دريك راموراي', 'أيام حياتنا', 'بوتري بارن', 'كونسويلا', 'كيس القمامة',
  'الديك الرومي', 'ساندويتش', 'باربادوس', 'لندن', 'لاس فيغاس', 'الزفاف'
];

const found = {};
orig.forEach((q, i) => {
  keywords.forEach(kw => {
    if (q.Q.includes(kw) || q.R.includes(kw)) {
      if (!found[kw]) found[kw] = [];
      found[kw].push({ i, Q: q.Q, R: q.R });
    }
  });
});

console.log('=== Questions by Friends Keywords ===');
for (const [kw, list] of Object.entries(found)) {
  if (list.length > 1) {
    console.log(`\nKeyword "${kw}" (${list.length} questions):`);
    list.forEach(item => {
      console.log(`  [#${item.i}] Q: ${item.Q} -> R: ${item.R}`);
    });
  }
}
