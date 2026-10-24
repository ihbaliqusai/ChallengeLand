const fs = require('fs');

const processed = JSON.parse(fs.readFileSync('./tools/guess_name/processed_guess_name.json', 'utf8'));
const filePath1 = './assets/questions.json';
const filePath2 = './android/app/src/main/assets/questions.json';

const allQs1 = JSON.parse(fs.readFileSync(filePath1, 'utf8'));
console.log('Original count in assets/questions.json:', allQs1.length);

let guessNameIndex = 0;
const updatedQs1 = allQs1.map(q => {
  if (q.Category === 'خمن الاسم') {
    const updated = processed[guessNameIndex++];
    return updated;
  }
  return q;
});

console.log('Replaced count for "خمن الاسم":', guessNameIndex);
console.log('New total count:', updatedQs1.length);

if (updatedQs1.length !== allQs1.length || guessNameIndex !== 400) {
  console.error('Count mismatch! Aborting.');
  process.exit(1);
}

const jsonString = JSON.stringify(updatedQs1, null, 2);
fs.writeFileSync(filePath1, jsonString, 'utf8');
fs.writeFileSync(filePath2, jsonString, 'utf8');

console.log('Successfully updated both assets/questions.json and android/app/src/main/assets/questions.json');
