const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

console.log('Total Questions in assets/questions.json:', qs.length);

const categories = {};
const negativeQuestions = [];
const englishAnswers = [];
const digitAnswers = [];
const longAnswers = [];
const duplicateQuestions = [];
const duplicateChoices = [];
const categoryMismatches = [];
const seenQ = new Map();

const normArabic = s => (s || '')
  .trim()
  .replace(/[\u064B-\u065F\u0670]/g, '')
  .replace(/[أإآ]/g, 'ا')
  .replace(/ة/g, 'ه')
  .replace(/ى/g, 'ي')
  .replace(/\s+/g, ' ')
  .toLowerCase();

// Negative / option-dependent regexes
const negativeRegexes = [
  /ليست من/i, /ليس من/i, /لا يعتبر/i, /لا تعتبر/i, /أي مما يلي لا/i, /أي من الآتي ليس/i,
  /أي مما يلي ليس/i, /أياً مما يلي ليس/i, /لا ينتمي/i, /لا تعد/i, /لا يعد/i, /غير صحيح/i,
  /أي الخيارات لا/i, /ما الذي لا/i, /أي من التالي لا/i, /أي مما يأتي لا/i, /أيها ليس/i
];

qs.forEach((q, idx) => {
  // Category counting
  if (!categories[q.Category]) {
    categories[q.Category] = {
      name: q.Category,
      total: 0,
      levels: { '0': 0, '1': 0, '2': 0, '3': 0, '4': 0, '5': 0, '6': 0, '7': 0, '8': 0 },
      easy: 0,
      med: 0,
      hard: 0
    };
  }
  const c = categories[q.Category];
  c.total++;
  c.levels[q.Level] = (c.levels[q.Level] || 0) + 1;
  if (['0', '1', '2'].includes(q.Level)) c.easy++;
  else if (['4', '5', '6'].includes(q.Level)) c.med++;
  else if (['3', '7', '8'].includes(q.Level)) c.hard++;

  // Choice uniqueness
  const choices = [q.R, q.W1, q.W2, q.W3].map(x => (x || '').trim());
  if (new Set(choices).size < 4) {
    duplicateChoices.push({ idx, q: q.Q, choices, cat: q.Category });
  }

  // Duplicate Q
  const nq = normArabic(q.Q);
  if (seenQ.has(nq)) {
    duplicateQuestions.push({ idx, origIdx: seenQ.get(nq), q: q.Q, cat: q.Category });
  } else {
    seenQ.set(nq, idx);
  }

  // Negative / option-dependent
  if (negativeRegexes.some(r => r.test(q.Q))) {
    negativeQuestions.push({ idx, q: q.Q, r: q.R, cat: q.Category, lvl: q.Level });
  }

  // English answer
  const hasLatinR = /[a-zA-Z]/.test(q.R);
  const hintEnglish = /(إنجليز|انجليز|English|باللاتيني|بالحروف الإنجليزية|اكتب بالإنجليزية)/i.test(q.Q);
  if (hasLatinR && !hintEnglish) {
    englishAnswers.push({ idx, q: q.Q, r: q.R, cat: q.Category, lvl: q.Level });
  }

  // Pure digits answer
  const isDigitsR = /^\d+$/.test(q.R.trim());
  const hintDigits = /(أرقام|ارقام|بالأرقام|بالارقام|عدداً|رقماً|اكتب الرقم|بالأرقام فقط)/i.test(q.Q);
  if (isDigitsR && !hintDigits) {
    digitAnswers.push({ idx, q: q.Q, r: q.R, cat: q.Category, lvl: q.Level });
  }

  // Long answers (> 30 characters)
  if (q.R.trim().length > 30) {
    longAnswers.push({ idx, q: q.Q, r: q.R, len: q.R.trim().length, cat: q.Category, lvl: q.Level });
  }

  // Specific Category Anomaly Checks
  // e.g. Football/World Cup questions in History or General Knowledge
  if (['تاريخ', 'معلومات عامة', 'حيوانات', 'جغرافيا'].includes(q.Category)) {
    if (/كأس العالم|مونديال|دوري أبطال|مباراة كرة|ركلات الترجيح|ريال مدريد|برشلونة|لاعب كرة|الفورمولا/i.test(q.Q)) {
      categoryMismatches.push({ idx, q: q.Q, cat: q.Category, suggested: 'رياضة / كأس العالم' });
    }
  }
  if (q.Category === 'حيوانات') {
    if (/استدلال|إذا كانت كل|فأي نتيجة مؤكدة|المنطق|فما نوع الحل/i.test(q.Q)) {
      categoryMismatches.push({ idx, q: q.Q, cat: q.Category, suggested: 'ألغاز' });
    }
  }
});

const report = {
  totalQuestions: qs.length,
  categoryCount: Object.keys(categories).length,
  categories,
  negativeCount: negativeQuestions.length,
  negativeQuestions,
  englishAnswersCount: englishAnswers.length,
  englishAnswersSample: englishAnswers.slice(0, 10),
  digitAnswersCount: digitAnswers.length,
  digitAnswersSample: digitAnswers.slice(0, 10),
  longAnswersCount: longAnswers.length,
  longAnswersSample: longAnswers.slice(0, 10),
  duplicateQuestionsCount: duplicateQuestions.length,
  duplicateChoicesCount: duplicateChoices.length,
  duplicateChoices,
  categoryMismatchesCount: categoryMismatches.length,
  categoryMismatches
};

fs.writeFileSync(path.join(__dirname, 'scan_report.json'), JSON.stringify(report, null, 2), 'utf8');
console.log('Scan complete. Written to tools/audit/scan_report.json');
console.log(`Summary:
- Negative/Option-dependent: ${report.negativeCount}
- English without hint: ${report.englishAnswersCount}
- Pure digits without hint: ${report.digitAnswersCount}
- Long answers (>30 chars): ${report.longAnswersCount}
- Duplicate choices: ${report.duplicateChoicesCount}
- Category mismatches flagged: ${report.categoryMismatchesCount}
`);
