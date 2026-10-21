const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

// Helper to shorten string by removing redundant introductory clauses
function makeConcise(str) {
  if (!str || typeof str !== 'string') return str;
  let s = str.trim();

  // If already short enough, return
  if (s.length <= 32) return s;

  // Common verbose prefixes and fluff
  s = s.replace(/^(قام بـ|قامت بـ|قام ب|قامت ب|القيام بـ|القيام ب|عن طريق |من خلال |بواسطة )/, '');
  s = s.replace(/^(لأنه |لأنها |لأنهم |بسبب أنه |بسبب أنها |بسبب أنهم )/, '');
  s = s.replace(/^(أنها |أنه |أنهم )/, '');
  
  // Cut explanatory suffix after commas / 'حيث أن' / 'قبل أن' / 'من أجل' / 'بهدف'
  if (s.length > 35) {
    const splitPoints = ['،', ' حيث أن', ' حيث', ' لإنشاء', ' للتكفير', ' لتعويض', ' لإخراج', ' بعد أن'];
    for (const sp of splitPoints) {
      if (s.includes(sp)) {
        const firstPart = s.split(sp)[0].trim();
        if (firstPart.length >= 10 && firstPart.length <= 40) {
          s = firstPart;
          break;
        }
      }
    }
  }

  // Remove trailing conjunctions or prepositions
  s = s.replace(/\s+(و|أو|في|من|إلى|على|عن|مع|بـ|لـ)$/, '').trim();

  return s;
}

// Test on very long items
let shortenedCount = 0;
const sampleTests = [];

qs.forEach((q, idx) => {
  if (q.R.trim().length > 35) {
    const shortR = makeConcise(q.R);
    const shortW1 = makeConcise(q.W1);
    const shortW2 = makeConcise(q.W2);
    const shortW3 = makeConcise(q.W3);
    if (shortR !== q.R) {
      shortenedCount++;
      if (sampleTests.length < 20) {
        sampleTests.push({
          idx,
          cat: q.Category,
          origR: q.R,
          newR: shortR,
          origLen: q.R.length,
          newLen: shortR.length
        });
      }
    }
  }
});

console.log(`Can automatically tighten ${shortenedCount} long answers.`);
console.log('Sample before & after:');
sampleTests.slice(0, 10).forEach(t => {
  console.log(`\n[${t.idx}] (${t.cat}) ${t.origLen} -> ${t.newLen}`);
  console.log(`  BEFORE: ${t.origR}`);
  console.log(`  AFTER:  ${t.newR}`);
});
