const fs = require('fs');

const orig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

// Print questions 100 to 130 to inspect the Arabic choices
for (let i = 100; i < 130; i++) {
  const q = orig[i];
  console.log(`[${i}] Q: ${q.Q}`);
  console.log(`     R: ${q.R} | W1: ${q.W1} | W2: ${q.W2} | W3: ${q.W3}`);
}
