const { execSync } = require('child_process');
const fs = require('fs');

const out = execSync('git show df3a04f3:assets/questions.json', { maxBuffer: 50 * 1024 * 1024 }).toString();
const dfData = JSON.parse(out);
const dfFriends = dfData.filter(q => q.Category === 'مسلسل Friends');
const currentOrig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('dfFriends count:', dfFriends.length);
console.log('currentOrig count:', currentOrig.length);

// Check which questions in currentOrig are in dfFriends
const dfSet = new Set(dfFriends.map(q => q.Q.trim()));

const addedQuestions = [];
currentOrig.forEach((q, idx) => {
  if (!dfSet.has(q.Q.trim())) {
    addedQuestions.push({ idx, Q: q.Q, R: q.R });
  }
});

console.log('Added / different questions in currentOrig count:', addedQuestions.length);
addedQuestions.forEach(q => console.log(`[#${q.idx}] Q: ${q.Q} -> R: ${q.R}`));
