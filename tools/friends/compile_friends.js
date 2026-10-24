const fs = require('fs');
const path = require('path');

const chunk1 = require('./generate_chunk1.js');
const chunk2 = require('./generate_chunk2.js');
const chunk3 = require('./generate_chunk3.js');
const chunk4 = require('./generate_chunk4.js');

const allChunks = [...chunk1, ...chunk2, ...chunk3, ...chunk4];
const original = JSON.parse(fs.readFileSync(path.join(__dirname, 'original_friends.json'), 'utf8'));

console.log('Original count:', original.length);
console.log('Total English choices count:', allChunks.length);

if (original.length !== allChunks.length) {
  throw new Error(`Length mismatch! Original: ${original.length}, Chunks: ${allChunks.length}`);
}

const compiled = original.map((q, idx) => {
  const ch = allChunks[idx];
  return {
    Level: q.Level,
    Q: q.Q,
    R: ch.R,
    W1: ch.W1,
    W2: ch.W2,
    W3: ch.W3,
    Category: q.Category
  };
});

// Strict validation
compiled.forEach((q, idx) => {
  const choices = [q.R, q.W1, q.W2, q.W3];
  
  if (new Set(choices.map(c => c.trim().toLowerCase())).size !== 4) {
    throw new Error(`Duplicate choices at #${idx} (Q: ${q.Q}): ${choices.join(' | ')}`);
  }

  choices.forEach((c, cIdx) => {
    if (!c || !c.trim()) {
      throw new Error(`Empty choice at #${idx} choice ${cIdx}`);
    }
    // Must contain English letters
    if (!/[a-zA-Z]/.test(c)) {
      throw new Error(`Missing English at #${idx} choice ${cIdx}: "${c}"`);
    }
    // Must NOT contain Arabic characters
    if (/[\u0600-\u06FF]/.test(c)) {
      throw new Error(`Arabic detected in English choice at #${idx} choice ${cIdx}: "${c}"`);
    }
    // Must NOT contain parentheses
    if (/[()（）]/.test(c)) {
      throw new Error(`Parentheses detected at #${idx} choice ${cIdx}: "${c}"`);
    }
  });
});

console.log('Validation successful! All 411 questions have valid, pure English choices without parentheses or duplicates.');

fs.writeFileSync(path.join(__dirname, 'friends_english.json'), JSON.stringify(compiled, null, 2), 'utf8');
console.log('Saved compiled questions to tools/friends/friends_english.json');
