const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const bundle5Cats = [
  'فنون وسينما', 'أفلام عربية', 'أفلام أجنبية', 'مسلسلات عربية', 'مسلسلات أجنبية',
  'مسلسل Friends', 'سبيس تون', 'الأنمي', 'كلثوميات', 'فيروز'
];

const results = [];

qs.forEach((q, idx) => {
  if (!bundle5Cats.includes(q.Category)) return;

  const issues = [];

  // Check English answer hint
  if (/[a-zA-Z]/.test(q.R) && !/(إنجليز|انجليز|English|باللاتيني|بالحروف الإنجليزية|اكتب بالإنجليزية)/i.test(q.Q)) {
    issues.push('ENGLISH_WITHOUT_HINT');
  }

  // Check Digit answer hint
  if (/^\d+$/.test(q.R.trim()) && !/(أرقام|ارقام|بالأرقام|بالارقام|عدداً|رقماً|اكتب الرقم)/i.test(q.Q)) {
    issues.push('DIGITS_WITHOUT_HINT');
  }

  // Check very long answer
  if (q.R.trim().length > 30) {
    issues.push('LONG_ANSWER');
  }

  // Cross-category Friends in foreign series
  if (q.Category === 'مسلسلات أجنبية' && /مسلسل Friends/i.test(q.Q)) {
    issues.push('FRIENDS_IN_FOREIGN_SERIES');
  }

  // Inta Omri in Fairouz
  if (idx === 9349) {
    issues.push('INTA_OMRI_IN_FAIROUZ');
  }

  // Choices uniqueness
  const choices = [q.R, q.W1, q.W2, q.W3].map(x => (x || '').trim());
  if (new Set(choices).size < 4) {
    issues.push('DUPLICATE_CHOICES');
  }

  if (issues.length > 0) {
    results.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R, issues });
  }
});

console.log(`Bundle 5 Audit: Found ${results.length} questions with issues across Bundle 5.`);
const issueCounts = {};
results.forEach(r => r.issues.forEach(iss => issueCounts[iss] = (issueCounts[iss] || 0) + 1));
console.log('Issue breakdown:', issueCounts);

fs.writeFileSync(path.join(__dirname, 'bundle5_issues.json'), JSON.stringify(results, null, 2), 'utf8');
