const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const ASSETS_PATH = path.join(ROOT_DIR, 'assets/questions.json');
const ANDROID_ASSETS_PATH = path.join(ROOT_DIR, 'android/app/src/main/assets/questions.json');

// 1. Load all 6 batches
const batches = [];
const batchCounts = [80, 80, 80, 80, 80, 100];

for (let i = 1; i <= 6; i++) {
  const batchFile = path.join(__dirname, `batch${i}.json`);
  const data = JSON.parse(fs.readFileSync(batchFile, 'utf8'));
  console.log(`Loaded batch${i}.json: ${data.length} questions`);
  if (data.length !== batchCounts[i - 1]) {
    throw new Error(`Batch ${i} count mismatch: expected ${batchCounts[i - 1]}, got ${data.length}`);
  }
  batches.push(...data);
}

console.log(`Total questions loaded: ${batches.length}`);
if (batches.length !== 500) {
  throw new Error(`Expected exactly 500 questions, got ${batches.length}`);
}

// 2. Strict validation of player feedback rules
const seenQuestions = new Set();
const levelCounts = {};

const englishRegex = /[a-zA-Z]/;
const parenthesisRegex = /[()（）]/;

batches.forEach((q, idx) => {
  // Check levels
  if (!q.Level || !['0', '1', '2', '4', '5', '6', '7', '8'].includes(q.Level)) {
    throw new Error(`Invalid level at #${idx}: ${q.Level} (${q.Q})`);
  }

  // Check question prefix / cartoon reference (Rule 4)
  if (!q.Q || typeof q.Q !== 'string' || !q.Q.trim()) {
    throw new Error(`Invalid question text at #${idx}`);
  }
  if (!q.Q.startsWith('في ') && !q.Q.includes('كرتون') && !q.Q.includes('مسلسل') && !q.Q.includes('أنمي')) {
    throw new Error(`Question #${idx} does not reference show context: ${q.Q}`);
  }

  // Check choices
  const choices = [q.R, q.W1, q.W2, q.W3];
  choices.forEach((c, cIdx) => {
    if (!c || typeof c !== 'string' || !c.trim()) {
      throw new Error(`Empty choice at #${idx} choice ${cIdx} in (${q.Q})`);
    }

    // Rule 1: No parentheses in any choice
    if (parenthesisRegex.test(c)) {
      throw new Error(`Rule 1 violation (parentheses detected) at #${idx} choice: "${c}" in (${q.Q})`);
    }

    // Rule 2: No English characters in any choice
    if (englishRegex.test(c)) {
      throw new Error(`Rule 2 violation (English detected) at #${idx} choice: "${c}" in (${q.Q})`);
    }
  });

  // Rule 3: Balanced length check (R length vs distractors)
  const rLen = q.R.trim().length;
  const wAvgLen = (q.W1.trim().length + q.W2.trim().length + q.W3.trim().length) / 3;
  // If R is more than 2.5x the average distractor length and R > 30 chars, flag it
  if (rLen > 30 && rLen > wAvgLen * 2.2) {
    console.warn(`Warning: R might be substantially longer at #${idx}: R="${q.R}" (${rLen}) vs avg distractors (${Math.round(wAvgLen)})`);
  }

  // Uniqueness of choices in the question
  const uniqueChoices = new Set(choices.map(c => c.trim()));
  if (uniqueChoices.size !== 4) {
    throw new Error(`Duplicate choices detected at #${idx} (${q.Q}): ${choices.join(' | ')}`);
  }

  // Check Category
  if (q.Category !== 'سبيس تون') {
    throw new Error(`Category mismatch at #${idx}: ${q.Category}`);
  }

  // Check duplicate question
  const normQ = q.Q.replace(/[؟?!\s]/g, '').trim();
  if (seenQuestions.has(normQ)) {
    throw new Error(`Duplicate question text detected at #${idx}: ${q.Q}`);
  }
  seenQuestions.add(normQ);

  levelCounts[q.Level] = (levelCounts[q.Level] || 0) + 1;
});

// Rule 5: Verify "مدرسة الكونغ فو" and "ليدي لين" are not present
const kungFuCount = batches.filter(q => q.Q.includes('مدرسة الكونغ فو')).length;
if (kungFuCount > 0) {
  throw new Error(`Rule 5 violation: 'مدرسة الكونغ فو' was not removed! Found ${kungFuCount} questions.`);
}
const ladyLynnCount = batches.filter(q => q.Q.includes('ليدي لين')).length;
if (ladyLynnCount > 0) {
  throw new Error(`Violation: 'ليدي لين' was not removed! Found ${ladyLynnCount} questions.`);
}

// Rule 6: Verify "بوكيمون" and "الكابتن رابح" are present
const pokemonCount = batches.filter(q => q.Q.includes('بوكيمون')).length;
const rabahCount = batches.filter(q => q.Q.includes('الكابتن رابح')).length;
const sallyCount = batches.filter(q => q.Q.includes('كرتون سالي')).length;

console.log(`Show verification: بوكيمون=${pokemonCount}, الكابتن رابح=${rabahCount}, سالي=${sallyCount}, ليدي لين=${ladyLynnCount}`);
if (pokemonCount !== 20 || rabahCount !== 20 || sallyCount !== 20) {
  throw new Error(`Show counts mismatch: pokemon=${pokemonCount}, rabah=${rabahCount}, sally=${sallyCount}`);
}

console.log('All player feedback rules PASSED successfully!');
console.log('Level distribution in new 500 Spacetoon questions:');
console.log(JSON.stringify(levelCounts, null, 2));

const easy = (levelCounts['0'] || 0) + (levelCounts['1'] || 0);
const med = (levelCounts['2'] || 0) + (levelCounts['4'] || 0) + (levelCounts['5'] || 0);
const hard = (levelCounts['6'] || 0) + (levelCounts['7'] || 0) + (levelCounts['8'] || 0);
console.log(`Easy: ${easy} | Medium: ${med} | Hard: ${hard} | Total: ${easy + med + hard}`);

// 3. Update questions.json
const rawData = fs.readFileSync(ASSETS_PATH, 'utf8');
const originalQuestions = JSON.parse(rawData);
console.log(`Original total questions: ${originalQuestions.length}`);

const nonSpacetoon = originalQuestions.filter(q => q.Category !== 'سبيس تون');
const oldSpacetoonCount = originalQuestions.length - nonSpacetoon.length;
console.log(`Removing ${oldSpacetoonCount} Spacetoon questions...`);

const updatedQuestions = [...nonSpacetoon, ...batches];
console.log(`New total questions: ${updatedQuestions.length}`);

// 4. Write to both target files
const updatedJsonStr = JSON.stringify(updatedQuestions, null, 2);
fs.writeFileSync(ASSETS_PATH, updatedJsonStr, 'utf8');
console.log(`Successfully updated ${ASSETS_PATH}`);

if (fs.existsSync(ANDROID_ASSETS_PATH)) {
  fs.writeFileSync(ANDROID_ASSETS_PATH, updatedJsonStr, 'utf8');
  console.log(`Successfully updated ${ANDROID_ASSETS_PATH}`);
}

// 5. Post-verification
const verifyData = JSON.parse(fs.readFileSync(ASSETS_PATH, 'utf8'));
const finalSpacetoon = verifyData.filter(q => q.Category === 'سبيس تون');
console.log(`Verification: Final Spacetoon questions count = ${finalSpacetoon.length}`);
if (finalSpacetoon.length !== 500) {
  throw new Error(`Verification failed! Expected 500 questions, found ${finalSpacetoon.length}`);
}

console.log('SUCCESS! Spacetoon questions fully updated and verified according to player feedback.');
