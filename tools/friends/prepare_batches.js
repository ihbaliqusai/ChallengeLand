const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('Writing questions 91 to 150 to a json for translation...');
const slice = [];
for (let i = 91; i <= 150; i++) {
  slice.push({ i, ...orig[i] });
}
fs.writeFileSync('./tools/friends/batch_91_150.json', JSON.stringify(slice, null, 2));
console.log('Written batch_91_150.json');
