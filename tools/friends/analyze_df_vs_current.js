const { execSync } = require('child_process');
const fs = require('fs');

const out = execSync('git show df3a04f3:assets/questions.json', { maxBuffer: 50 * 1024 * 1024 }).toString();
const dfData = JSON.parse(out);
const dfFriends = dfData.filter(q => q.Category === 'مسلسل Friends');
const currentOrig = JSON.parse(fs.readFileSync('./tools/friends/original_friends.json', 'utf8'));

console.log('dfFriends count:', dfFriends.length);
console.log('currentOrig count:', currentOrig.length);

// Let's check how currentOrig was constructed:
// Was currentOrig made of dfFriends plus something, or did it have duplicates inside it?
// Let's check duplicates inside dfFriends:
const dfSeen = new Map();
const dfDupes = [];
dfFriends.forEach((q, i) => {
  const norm = q.Q.trim();
  if (dfSeen.has(norm)) {
    dfDupes.push({ i, orig: dfSeen.get(norm), q: norm });
  } else {
    dfSeen.set(norm, i);
  }
});
console.log('Exact duplicates inside dfFriends:', dfDupes.length);

// Let's check duplicates inside currentOrig:
const origSeen = new Map();
const origDupes = [];
currentOrig.forEach((q, i) => {
  const norm = q.Q.trim();
  if (origSeen.has(norm)) {
    origDupes.push({ i, orig: origSeen.get(norm), q: norm });
  } else {
    origSeen.set(norm, i);
  }
});
console.log('Exact duplicates inside currentOrig:', origDupes.length);
