const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const targets = [
  377, 568, 655, 659, 696, 736, 745, 749, 974, 1144, 1145, 1146, 1171, 1215, 1260,
  1494, 1712, 1868, 1875, 1931, 2023, 2090, 8517, 9349, 13612, 13667, 13668
];

console.log('Targets summary (count: ' + targets.length + '):');
targets.forEach(idx => {
  const q = qs[idx];
  console.log(`[${idx}] Cat: ${q.Category} | Lvl: ${q.Level} | Q: ${q.Q}`);
});
