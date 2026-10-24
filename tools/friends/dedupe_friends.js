const { execSync } = require('child_process');
const fs = require('fs');

const out = execSync('git show df3a04f3:assets/questions.json', { maxBuffer: 50 * 1024 * 1024 }).toString();
const dfData = JSON.parse(out);
const dfFriends = dfData.filter(q => q.Category === 'مسلسل Friends');
const currentFriends = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('dfFriends count:', dfFriends.length);
console.log('currentFriends count:', currentFriends.length);

// Merge and deduplicate by question meaning
// First, let's collect all questions from both sources
const allFriends = [...dfFriends, ...currentFriends];

const unique = [];
const seenQ = new Set();

function normalize(q) {
  return q.replace(/[؟?.,!،؛:\"'’‘()]/g, '').trim();
}

allFriends.forEach(item => {
  const norm = normalize(item.Q);
  if (!seenQ.has(norm)) {
    // Also check if similar question exists in unique
    let isDupe = false;
    const words = new Set(norm.split(/\s+/).filter(w => w.length > 2));
    
    for (const u of unique) {
      const uNorm = normalize(u.Q);
      const uWords = new Set(uNorm.split(/\s+/).filter(w => w.length > 2));
      const common = [...words].filter(w => uWords.has(w));
      const union = new Set([...words, ...uWords]);
      const sim = union.size > 0 ? common.length / union.size : 0;
      
      // If same answer and high similarity, or very high similarity
      if ((u.R.trim() === item.R.trim() && sim >= 0.35) || sim >= 0.70) {
        isDupe = true;
        break;
      }
    }
    
    if (!isDupe) {
      seenQ.add(norm);
      unique.push(item);
    }
  }
});

console.log('Total unique Friends questions after deduplication:', unique.length);
fs.writeFileSync('./tools/friends/unique_friends_arabic.json', JSON.stringify(unique, null, 2));
