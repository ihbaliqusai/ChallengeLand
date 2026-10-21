const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

['مسلسل Friends', 'مسلسلات عربية', 'الأنمي', 'ركز شوي'].forEach(cat => {
  const catLong = qs
    .map((q, idx) => ({ ...q, idx }))
    .filter(q => q.Category === cat && q.R.trim().length > 30);
  console.log(`\n================ ${cat} (Total Long: ${catLong.length}) ================`);
  catLong.slice(0, 5).forEach(x => {
    console.log(`[${x.idx}] (len ${x.R.length})\nQ: ${x.Q}\nR: ${x.R}\n`);
  });
});
