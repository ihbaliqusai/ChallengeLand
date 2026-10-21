const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const bundle1Cats = ['عواصم', 'دول', 'جغرافيا', 'سياحة وسفر', 'علوم وفضاء', 'تقنية', 'اختراعات', 'سيارات'];

const results = [];

qs.forEach((q, idx) => {
  if (!bundle1Cats.includes(q.Category)) return;

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

  // Check negative or option-dependent
  if (/ليست من|ليس من|لا يعتبر|لا تعتبر|أي مما يلي ليس|أي من الآتي ليس|أياً مما يلي/i.test(q.Q)) {
    issues.push('NEGATIVE_OR_OPTION_DEPENDENT');
  }

  // Specific factual / category checks
  if (idx === 377) {
    issues.push('NEGATIVE_CITY_JORDAN');
  }
  if (idx === 749 && q.Category === 'علوم وفضاء') {
    issues.push('MALDIVES_IN_SCIENCE');
  }

  // Check choices uniqueness
  const choices = [q.R, q.W1, q.W2, q.W3].map(x => (x || '').trim());
  if (new Set(choices).size < 4) {
    issues.push('DUPLICATE_CHOICES');
  }

  if (issues.length > 0) {
    results.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R, issues });
  }
});

console.log(`Bundle 1 Audit: Found ${results.length} questions with issues across ${bundle1Cats.join(', ')}.`);
const issueCounts = {};
results.forEach(r => r.issues.forEach(iss => issueCounts[iss] = (issueCounts[iss] || 0) + 1));
console.log('Issue breakdown:', issueCounts);

fs.writeFileSync(path.join(__dirname, 'bundle1_issues.json'), JSON.stringify(results, null, 2), 'utf8');
