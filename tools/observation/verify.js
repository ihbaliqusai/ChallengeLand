const fs = require('fs');
const f1 = fs.readFileSync('assets/questions.json');
const f2 = fs.readFileSync('android/app/src/main/assets/questions.json');
console.log('f1 length:', f1.length, 'f2 length:', f2.length, 'equals:', f1.equals(f2));
const q1 = JSON.parse(f1);
console.log('Total questions:', q1.length);
const obs = q1.filter(q => q.Category === 'دقة ملاحظة');
console.log('Observation questions count:', obs.length);
obs.forEach((q, i) => console.log((i+1) + '. ' + q.Q + ' -> ' + q.R + ' (Level: ' + q.Level + ', Img: ' + (q.Img ? q.Img.slice(0, 45) + '...' : 'none') + ')'));
