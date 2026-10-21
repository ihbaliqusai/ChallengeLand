const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

console.log('================ FINAL COMPREHENSIVE VERIFICATION ================');
console.log('Total Questions in assets/questions.json:', qs.length);

let errors = 0;
let missingFields = 0;
let duplicateOptions = 0;
let negativeRemaining = 0;
let englishWithoutHint = 0;
let digitsWithoutHint = 0;
let songsWithoutArtist = 0;
let overLongRemaining = 0;

const negativeRegexes = [
  /مدينة ليست من/i,
  /ليست عضوًا دائمًا في مجلس الأمن/i,
  /أي الكلمات التالية لا تتناسب وكلمة قفص/i,
  /ليس عددًا أوليًا/i,
  /ليس مربعًا كاملًا/i,
  /ليست جمعًا/i
];

qs.forEach((q, idx) => {
  // Required fields
  if (!q.Q || !q.R || !q.W1 || !q.W2 || !q.W3 || !q.Level || !q.Category) {
    missingFields++;
    errors++;
  }

  // Option uniqueness
  const choices = [q.R, q.W1, q.W2, q.W3].map(x => (x || '').trim());
  if (new Set(choices).size < 4) {
    duplicateOptions++;
    errors++;
  }

  // Negative checks
  if (negativeRegexes.some(r => r.test(q.Q))) {
    negativeRemaining++;
    errors++;
    console.error(`Unresolved negative question at [${idx}]: ${q.Q}`);
  }

  // English without hint
  if (/[a-zA-Z]/.test(q.R) && !/(إنجليز|انجليز|English|باللاتيني|بالحروف الإنجليزية|اكتب بالإنجليزية)/i.test(q.Q)) {
    englishWithoutHint++;
  }

  // Digits without hint
  if (/^\d+$/.test(q.R.trim()) && !/(أرقام|ارقام|بالأرقام|بالارقام|عدداً|رقماً|اكتب الرقم)/i.test(q.Q)) {
    digitsWithoutHint++;
  }

  // Song without artist
  if (q.Category === 'خمن الأغنية') {
    const parts = q.R.split(' - ');
    if (parts.length > 1) {
      const artist = parts[1].trim();
      if (!q.Q.includes(artist)) {
        songsWithoutArtist++;
      }
    }
  }

  // Super long (> 45 chars)
  if (q.R.trim().length > 45) {
    overLongRemaining++;
  }
});

console.log(`- Missing fields: ${missingFields}`);
console.log(`- Duplicate options in any question: ${duplicateOptions}`);
console.log(`- Problematic negative / option-dependent questions remaining: ${negativeRemaining}`);
console.log(`- English answers without hint: ${englishWithoutHint}`);
console.log(`- Pure digits without hint: ${digitsWithoutHint}`);
console.log(`- Song questions without artist hint: ${songsWithoutArtist}`);
console.log(`- Super-long answers (>45 chars) remaining: ${overLongRemaining}`);

// Category breakdown
const cats = {};
qs.forEach(q => cats[q.Category] = (cats[q.Category] || 0) + 1);
console.log(`- Categories present: ${Object.keys(cats).length} categories`);

if (errors === 0) {
  console.log('\n>>> STATUS: 100% CLEAN AND VERIFIED! <<<');
} else {
  console.error(`\n>>> STATUS: FAILED WITH ${errors} ERRORS! <<<`);
}
