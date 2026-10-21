const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const bundle6Cats = [
  'خمن الأغنية', 'خمن الصورة', 'خمن الاسم', 'خمن الأكلة',
  'خمن المدينة او الدولة', 'زووم', 'وضح شوي', 'ركز شوي'
];

const results = [];

qs.forEach((q, idx) => {
  if (!bundle6Cats.includes(q.Category)) return;

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

  // Guess song without artist hint in Q
  if (q.Category === 'خمن الأغنية') {
    // Check if Q mentions the artist
    const parts = q.R.split(' - ');
    if (parts.length > 1) {
      const artist = parts[1].trim();
      if (!q.Q.includes(artist)) {
        issues.push('SONG_MISSING_ARTIST_IN_Q');
      }
    }
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

console.log(`Bundle 6 Audit: Found ${results.length} questions with issues across Bundle 6.`);
const issueCounts = {};
results.forEach(r => r.issues.forEach(iss => issueCounts[iss] = (issueCounts[iss] || 0) + 1));
console.log('Issue breakdown:', issueCounts);

fs.writeFileSync(path.join(__dirname, 'bundle6_issues.json'), JSON.stringify(results, null, 2), 'utf8');
