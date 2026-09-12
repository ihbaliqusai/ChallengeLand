const fs = require('fs');
const path = require('path');

const p1 = path.join(__dirname, '../assets/questions.json');
const p2 = path.join(__dirname, '../android/app/src/main/assets/questions.json');

const raw = fs.readFileSync(p1, 'utf8');
const questions = JSON.parse(raw);
console.log('Total questions before:', questions.length);

const renameMap = {
  'قصة مسلسل عربي': 'مسلسلات عربية',
  'قصة فيلم عربي': 'أفلام عربية',
  'قصة مسلسل اجنبي': 'مسلسلات أجنبية',
  'قصة مسلسل أجنبي': 'مسلسلات أجنبية',
  'قصة فيلم اجنبي': 'أفلام أجنبية',
  'قصة فيلم أجنبي': 'أفلام أجنبية'
};

const counts = {
  'مسلسلات عربية': 0,
  'أفلام عربية': 0,
  'مسلسلات أجنبية': 0,
  'أفلام أجنبية': 0
};

let renamedCount = 0;
questions.forEach(q => {
  if (renameMap[q.Category]) {
    const target = renameMap[q.Category];
    q.Category = target;
    counts[target]++;
    renamedCount++;
  }
});

console.log('Total questions renamed:', renamedCount);
console.log('Renamed breakdown:', counts);

const outputJson = JSON.stringify(questions, null, 2);
fs.writeFileSync(p1, outputJson, 'utf8');
fs.writeFileSync(p2, outputJson, 'utf8');

// Verify byte match
const b1 = fs.readFileSync(p1);
const b2 = fs.readFileSync(p2);
console.log('Both questions.json files match:', b1.equals(b2), 'size:', b1.length);
