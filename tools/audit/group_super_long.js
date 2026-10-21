const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const superLong = qs.map((q, idx) => ({ ...q, idx })).filter(q => q.R.trim().length > 45);

const grouped = {};
superLong.forEach(item => {
  if (!grouped[item.Category]) grouped[item.Category] = [];
  grouped[item.Category].push(item);
});

console.log('Categories with R > 45 chars:');
Object.keys(grouped).forEach(cat => {
  console.log(`- ${cat}: ${grouped[cat].length} questions`);
});

fs.writeFileSync(path.join(__dirname, 'super_long_grouped.json'), JSON.stringify(grouped, null, 2), 'utf8');
