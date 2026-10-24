const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

// Check for any other duplicates
const dupes = [];

const toRemoveIndices = new Set([92, 95, 97, 189, 289, 368]);

console.log('Original count:', orig.length);
const cleaned = orig.filter((q, idx) => !toRemoveIndices.has(idx));
console.log('Count after removing the 6 known duplicates:', cleaned.length);

// Now let's do a deep similarity check on cleaned
for (let i = 0; i < cleaned.length; i++) {
  for (let j = i + 1; j < cleaned.length; j++) {
    const q1 = cleaned[i];
    const q2 = cleaned[j];
    
    // Check if answers are identical or question asks same thing
    if (q1.R.trim() === q2.R.trim()) {
      dupes.push({ i, j, q1: q1.Q, r1: q1.R, q2: q2.Q, r2: q2.R });
    }
  }
}

console.log('Questions with identical answers in cleaned:', dupes.length);
dupes.forEach(d => {
  console.log(`\n[#${d.i} vs #${d.j}] Answer: "${d.r1}"`);
  console.log(`  Q1: ${d.q1}`);
  console.log(`  Q2: ${d.q2}`);
});
