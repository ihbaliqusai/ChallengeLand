const fs = require('fs');
const path = require('path');

// 1. Load original questions
const questionsPath = path.resolve(__dirname, '../assets/questions.json');
const androidPath = path.resolve(__dirname, '../android/app/src/main/assets/questions.json');

const allQuestions = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
console.log('Total input questions:', allQuestions.length);

// 2. Load Friends components
const origFriends = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'friends/original_friends.json'), 'utf8'));
const c1 = require('./friends/generate_chunk1.js');
const part1 = require('./friends/translate_part1.js');
const part2 = require('./friends/translate_part2.js');

const friendsDupes = new Set([92, 95, 97, 122, 189, 289, 368]);

const cleanFriends = [];
for (let i = 0; i < origFriends.length; i++) {
  if (friendsDupes.has(i)) continue;

  const trans = part2[i] || part1[i] || (i < c1.length ? c1[i] : null);
  if (!trans) {
    throw new Error(`Missing translation for Friends index ${i}`);
  }

  // Sanity checks on choices
  const choices = [trans.R, trans.W1, trans.W2, trans.W3];
  choices.forEach(c => {
    if (!c || typeof c !== 'string') {
      throw new Error(`Invalid choice at Friends index ${i}: ${c}`);
    }
    if (/[()]/.test(c)) {
      throw new Error(`Parentheses found at Friends index ${i}: ${c}`);
    }
  });

  const unique = new Set(choices.map(c => c.trim().toLowerCase()));
  if (unique.size !== 4) {
    throw new Error(`Choices not distinct at Friends index ${i}: ${choices.join(' | ')}`);
  }

  cleanFriends.push({
    Level: origFriends[i].Level || '0',
    Q: origFriends[i].Q,
    R: trans.R,
    W1: trans.W1,
    W2: trans.W2,
    W3: trans.W3,
    Category: 'مسلسل Friends'
  });
}

console.log('Clean Friends questions assembled:', cleanFriends.length);

// 3. The 20 non-Friends duplicate indices in assets/questions.json
const nonFriendsToRemove = new Set([
  // فنون وسينما
  4550, 4579, 4572, 8074, 8072, 8780, 8076, 8075, 8077, 8791,
  // تقنية
  4506, 4269, 8023,
  // منوعات
  9492,
  // خمن الصورة
  9703, 9906,
  // خمن الأكلة
  10703, 10706,
  // قصة فيلم عربي
  13161, 13207
]);

console.log('Non-Friends duplicates to remove:', nonFriendsToRemove.size);

// 4. Build output questions
const finalQuestions = [];
let friendsInserted = false;

for (let i = 0; i < allQuestions.length; i++) {
  const q = allQuestions[i];

  if (q.Category === 'مسلسل Friends') {
    if (!friendsInserted) {
      // Insert our clean Friends array here
      finalQuestions.push(...cleanFriends);
      friendsInserted = true;
    }
    // Skip old Friends entries
    continue;
  }

  // If non-Friends duplicate, skip
  if (nonFriendsToRemove.has(i)) {
    console.log(`Removed duplicate at index ${i}: [${q.Category}] ${q.Q}`);
    continue;
  }

  finalQuestions.push(q);
}

console.log('Final questions total count:', finalQuestions.length);

// 5. Global sanity validation
const categoryCounts = {};
for (const q of finalQuestions) {
  categoryCounts[q.Category] = (categoryCounts[q.Category] || 0) + 1;
  if (!q.Q || !q.R || !q.W1 || !q.W2 || !q.W3 || !q.Category) {
    throw new Error(`Incomplete question found: ${JSON.stringify(q)}`);
  }
}

console.log('\nCategory breakdown:');
for (const [cat, cnt] of Object.entries(categoryCounts)) {
  console.log(` - ${cat}: ${cnt}`);
}

// Check for duplicate Q text in any category
const seenByCategory = new Map();
let anyDupes = 0;
for (const q of finalQuestions) {
  if (!seenByCategory.has(q.Category)) {
    seenByCategory.set(q.Category, new Set());
  }
  const norm = q.Q.trim().replace(/[؟?!\s]/g, '');
  if (seenByCategory.get(q.Category).has(norm)) {
    console.warn(`Warning: Potential duplicate in ${q.Category}: "${q.Q}"`);
    anyDupes++;
  } else {
    seenByCategory.get(q.Category).add(norm);
  }
}
console.log('Duplicate Q check completed. Duplicate count:', anyDupes);

// 6. Write to both assets/questions.json and android/app/src/main/assets/questions.json
const jsonString = JSON.stringify(finalQuestions, null, 2);
fs.writeFileSync(questionsPath, jsonString, 'utf8');
fs.writeFileSync(androidPath, jsonString, 'utf8');
console.log('Successfully written to both assets/questions.json and android/app/src/main/assets/questions.json');
