const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const ASSETS_PATH = path.join(ROOT_DIR, 'assets/questions.json');
const ANDROID_ASSETS_PATH = path.join(ROOT_DIR, 'android/app/src/main/assets/questions.json');

const friendsEnglish = JSON.parse(fs.readFileSync(path.join(__dirname, 'friends_english.json'), 'utf8'));
console.log(`Loaded ${friendsEnglish.length} English-choice Friends questions.`);

if (friendsEnglish.length !== 411) {
  throw new Error(`Expected exactly 411 questions, got ${friendsEnglish.length}`);
}

// 1. Read existing questions
const originalQuestions = JSON.parse(fs.readFileSync(ASSETS_PATH, 'utf8'));
console.log(`Original total questions in assets: ${originalQuestions.length}`);

// 2. Replace Friends category
const nonFriendsQuestions = originalQuestions.filter(q => q.Category !== 'مسلسل Friends');
console.log(`Retained non-Friends questions count: ${nonFriendsQuestions.length}`);

const finalQuestions = [...nonFriendsQuestions, ...friendsEnglish];
console.log(`New total questions count: ${finalQuestions.length}`);

if (finalQuestions.length !== originalQuestions.length) {
  throw new Error(`Count mismatch! Original: ${originalQuestions.length}, Final: ${finalQuestions.length}`);
}

// 3. Write to both asset locations
const formattedJson = JSON.stringify(finalQuestions, null, 2);
fs.writeFileSync(ASSETS_PATH, formattedJson, 'utf8');
console.log(`Successfully written to ${ASSETS_PATH}`);

if (fs.existsSync(ANDROID_ASSETS_PATH)) {
  fs.writeFileSync(ANDROID_ASSETS_PATH, formattedJson, 'utf8');
  console.log(`Successfully written to ${ANDROID_ASSETS_PATH}`);
}

// 4. Verification
[ASSETS_PATH, ANDROID_ASSETS_PATH].forEach(target => {
  const checkData = JSON.parse(fs.readFileSync(target, 'utf8'));
  const checkFriends = checkData.filter(q => q.Category === 'مسلسل Friends');
  console.log(`Verification for ${target}:`);
  console.log(`  Total questions: ${checkData.length}`);
  console.log(`  مسلسل Friends questions: ${checkFriends.length}`);

  if (checkFriends.length !== 411) {
    throw new Error(`Mismatch in Friends questions count in ${target}!`);
  }

  let errorCount = 0;
  checkFriends.forEach((q, idx) => {
    const choices = [q.R, q.W1, q.W2, q.W3];
    choices.forEach((c, cIdx) => {
      if (!/[a-zA-Z]/.test(c)) {
        console.error(`Error: No English in choice at #${idx} choice ${cIdx}: "${c}"`);
        errorCount++;
      }
      if (/[\u0600-\u06FF]/.test(c)) {
        console.error(`Error: Arabic in choice at #${idx} choice ${cIdx}: "${c}"`);
        errorCount++;
      }
      if (/[()（）]/.test(c)) {
        console.error(`Error: Parentheses in choice at #${idx} choice ${cIdx}: "${c}"`);
        errorCount++;
      }
    });
  });

  if (errorCount > 0) {
    throw new Error(`Found ${errorCount} validation errors in ${target}`);
  }
});

console.log('SUCCESS! All 411 Friends questions successfully converted to English choices in both asset files.');
