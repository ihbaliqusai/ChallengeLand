const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const indices = [377, 568, 655, 736, 749, 8517, 9349, 974, 13612, 13667, 13668];
indices.forEach(i => {
  const q = qs[i];
  console.log(`\nIndex: ${i} | Category: ${q.Category} | Level: ${q.Level}`);
  console.log(`Q: ${q.Q}`);
  console.log(`R: ${q.R}`);
  console.log(`Choices: ${[q.R, q.W1, q.W2, q.W3].join(' | ')}`);
});
