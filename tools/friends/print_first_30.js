const fs = require('fs');

const qs = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
const friends = qs.filter(q => q.Category === 'مسلسل Friends');

console.log('Friends questions 0 to 30:');
for (let i = 0; i < 30; i++) {
  console.log(i, friends[i].Q, '-> R:', friends[i].R);
}
