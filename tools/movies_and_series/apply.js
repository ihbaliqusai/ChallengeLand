const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const ASSETS_PATH = path.join(ROOT_DIR, 'assets/questions.json');
const ANDROID_ASSETS_PATH = path.join(ROOT_DIR, 'android/app/src/main/assets/questions.json');

// 1. Load batches
const batches = [
  { name: 'arabic_films.json', category: 'قصة فيلم عربي', lang: 'ar' },
  { name: 'foreign_films.json', category: 'قصة فيلم اجنبي', lang: 'en' },
  { name: 'arabic_series.json', category: 'قصة مسلسل عربي', lang: 'ar' },
  { name: 'foreign_series.json', category: 'قصة مسلسل اجنبي', lang: 'en' },
];

const allNewQuestions = [];
const expectedLevels = { '0': 20, '1': 50, '2': 20, '4': 30, '5': 20, '6': 20, '7': 20, '8': 20 };

batches.forEach(b => {
  const filePath = path.join(__dirname, b.name);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  console.log(`Loaded ${b.name}: ${data.length} questions for category '${b.category}'`);
  if (data.length !== 200) {
    throw new Error(`Expected exactly 200 questions in ${b.name}, got ${data.length}`);
  }

  const catLevels = {};
  data.forEach((q, idx) => {
    // Check Category
    if (q.Category !== b.category) {
      throw new Error(`Category mismatch in ${b.name} at #${idx}: expected '${b.category}', got '${q.Category}'`);
    }

    // Check Level
    catLevels[q.Level] = (catLevels[q.Level] || 0) + 1;

    // Check Choices
    const choices = [q.R, q.W1, q.W2, q.W3];
    if (new Set(choices.map(c => c.trim())).size !== 4) {
      throw new Error(`Duplicate choices in ${b.name} #${idx}: ${choices.join(' | ')}`);
    }

    choices.forEach((c, cIdx) => {
      if (!c || typeof c !== 'string' || !c.trim()) {
        throw new Error(`Empty choice in ${b.name} #${idx} choice ${cIdx}`);
      }

      // Rule 1: No parentheses in answers
      if (/[()（）]/.test(c)) {
        throw new Error(`Rule 1 violation (parentheses detected) in ${b.name} #${idx} choice: "${c}"`);
      }

      // Language checks
      if (b.lang === 'ar') {
        // Pure Arabic
        if (/[a-zA-Z]/.test(c)) {
          throw new Error(`Rule 2 violation (English in Arabic category) in ${b.name} #${idx} choice: "${c}"`);
        }
      } else {
        // Foreign category must have English answers
        if (!/[a-zA-Z]/.test(c)) {
          throw new Error(`Rule 4 violation (Non-English in Foreign category) in ${b.name} #${idx} choice: "${c}"`);
        }
      }
    });

    // Rule 3: Balanced length
    const rLen = q.R.trim().length;
    const wAvgLen = (q.W1.trim().length + q.W2.trim().length + q.W3.trim().length) / 3;
    if (rLen > 40 && rLen > wAvgLen * 2.3) {
      console.warn(`Warning: R might be long in ${b.name} #${idx}: R="${q.R}" (${rLen}) vs avg distractors (${Math.round(wAvgLen)})`);
    }

    allNewQuestions.push(q);
  });

  // Verify level distribution
  for (const [lvl, expCount] of Object.entries(expectedLevels)) {
    if (catLevels[lvl] !== expCount) {
      throw new Error(`Level mismatch in ${b.name} for level ${lvl}: expected ${expCount}, got ${catLevels[lvl]}`);
    }
  }
});

console.log(`Total new questions validated: ${allNewQuestions.length}`);
if (allNewQuestions.length !== 800) {
  throw new Error(`Expected 800 questions, got ${allNewQuestions.length}`);
}

// 2. Read and update questions.json
const rawData = fs.readFileSync(ASSETS_PATH, 'utf8');
const originalQuestions = JSON.parse(rawData);
console.log(`Original total questions count: ${originalQuestions.length}`);

const categoriesToRemove = new Set([
  'قصة فيلم', 'قصة مسلسل',
  'قصة فيلم عربي', 'قصة فيلم اجنبي',
  'قصة مسلسل عربي', 'قصة مسلسل اجنبي'
]);

const retainedQuestions = originalQuestions.filter(q => !categoriesToRemove.has(q.Category));
console.log(`Retained other questions count: ${retainedQuestions.length}`);

const finalQuestions = [...retainedQuestions, ...allNewQuestions];
console.log(`New total questions count: ${finalQuestions.length}`);

// 3. Write to both asset locations
const formattedJson = JSON.stringify(finalQuestions, null, 2);
fs.writeFileSync(ASSETS_PATH, formattedJson, 'utf8');
console.log(`Successfully written to ${ASSETS_PATH}`);

if (fs.existsSync(ANDROID_ASSETS_PATH)) {
  fs.writeFileSync(ANDROID_ASSETS_PATH, formattedJson, 'utf8');
  console.log(`Successfully written to ${ANDROID_ASSETS_PATH}`);
}

// 4. Post-verification
[ASSETS_PATH, ANDROID_ASSETS_PATH].forEach(target => {
  const checkData = JSON.parse(fs.readFileSync(target, 'utf8'));
  const checkOldFilm = checkData.filter(q => q.Category === 'قصة فيلم').length;
  const checkOldSeries = checkData.filter(q => q.Category === 'قصة مسلسل').length;
  const checkArFilm = checkData.filter(q => q.Category === 'قصة فيلم عربي').length;
  const checkEnFilm = checkData.filter(q => q.Category === 'قصة فيلم اجنبي').length;
  const checkArSeries = checkData.filter(q => q.Category === 'قصة مسلسل عربي').length;
  const checkEnSeries = checkData.filter(q => q.Category === 'قصة مسلسل اجنبي').length;

  console.log(`Verification for ${target}:`);
  console.log(`  قصة فيلم (old): ${checkOldFilm}`);
  console.log(`  قصة مسلسل (old): ${checkOldSeries}`);
  console.log(`  قصة فيلم عربي: ${checkArFilm}`);
  console.log(`  قصة فيلم اجنبي: ${checkEnFilm}`);
  console.log(`  قصة مسلسل عربي: ${checkArSeries}`);
  console.log(`  قصة مسلسل اجنبي: ${checkEnSeries}`);

  if (checkOldFilm !== 0 || checkOldSeries !== 0) {
    throw new Error(`Old categories still exist in ${target}!`);
  }
  if (checkArFilm !== 200 || checkEnFilm !== 200 || checkArSeries !== 200 || checkEnSeries !== 200) {
    throw new Error(`New category counts mismatch in ${target}!`);
  }
});

console.log('SUCCESS! All 800 questions successfully integrated and verified.');
