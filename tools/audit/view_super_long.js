const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const superLong = qs.map((q, idx) => ({ ...q, idx })).filter(q => q.R.trim().length > 45);
console.log('Super long answers (> 45 chars):', superLong.length);
superLong.forEach(s => {
  console.log(`[${s.idx}] (${s.Category}, len ${s.R.length})\nQ: ${s.Q}\nR: ${s.R}\n`);
});
