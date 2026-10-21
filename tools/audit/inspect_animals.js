const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const animals = qs.map((q, idx) => ({ ...q, idx })).filter(q => q.Category === 'حيوانات');
console.log('Total animals questions:', animals.length);

const hardAnimals = animals.filter(a => ['3', '7', '8'].includes(a.Level));
console.log('Hard tier (3, 7, 8):', hardAnimals.length);
hardAnimals.forEach(a => {
  console.log(`[${a.idx}] lvl ${a.Level}: ${a.Q} -> ${a.R}`);
});
