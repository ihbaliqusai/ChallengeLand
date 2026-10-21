const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

// Helper to tighten answers cleanly
function cleanLongText(text) {
  if (!text || typeof text !== 'string') return text;
  let s = text.trim();
  if (s.length <= 40) return s;

  // Cut verbose prefixes
  s = s.replace(/^(قام بـ|قامت بـ|قام ب|قامت ب|القيام بـ|القيام ب|عن طريق |من خلال |بواسطة )/, '');
  s = s.replace(/^(لأنه |لأنها |لأنهم |بسبب أنه |بسبب أنها |بسبب أنهم )/, '');
  s = s.replace(/^(أنه |أنها |أنهم |أن )/, '');
  s = s.replace(/^(توجد |يوجد )/, '');

  // Specific phrases
  s = s.replace('مستحيل، لابد من وجود نقطة صلعاء أو زوبعة واحدة على الأقل', 'لابد من وجود زوبعة أو نقطة صلعاء');
  s = s.replace('إمكانية إخفاء معلومات المسار مستقبلاً لإعادة نمط التداخل في الماضي', 'إخفاء مسار الجسيم لاستعادة نمط التداخل');
  s = s.replace('ارتباط حالة جسيمين لحظياً بغض النظر عن المسافة بينهما', 'ارتباط حالة جسيمين لحظياً عن بُعد');
  s = s.replace('ينعكس الاتجاه والنتيجة الإحصائية تماماً عند الدمج', 'انعكاس النتيجة الإحصائية عند الدمج');
  s = s.replace('هل يوجد مسار أويلري يمر بجميع الحواف مرة واحدة؟', 'مسار يمر بجميع الحواف مرة واحدة فقط');
  s = s.replace('اختيار القرار الذي يعظم أسوأ نتيجة محتملة لتجنب الكارثة', 'اختيار الخيار الأفضل بين أسوأ النتائج');
  s = s.replace('متى تتحول حبات الرمل الفردية إلى كومة بالضبط؟ (الحدود الضبابية)', 'متى تصبح حبات الرمل كومة؟ (الحدود الضبابية)');
  s = s.replace('تنازع بين الهوية المادية التاريخية والهوية البنائية المستمرة', 'تنازع الهوية المادية والبنائية المستمرة');
  s = s.replace('كيف تضمن أنك لست مجرد دماغ متصل بحاسوب يغذي حواسك بإشارات وهمية؟', 'هل واقعك مجرد إشارات وهمية لدماغ بحاسوب؟');
  s = s.replace('99 سجيناً مضمونين بنسبة 100% والسجين الأول 50%', 'إنقاذ 99 سجيناً بنسبة 100%');

  // Strip clauses after commas / 'حيث أن' if still > 40
  if (s.length > 40) {
    const splitWords = ['،', ' حيث أن', ' حيث', ' لإنشاء', ' للتكفير', ' لتعويض', ' لإخراج', ' بعد أن'];
    for (const sw of splitWords) {
      if (s.includes(sw)) {
        const p = s.split(sw)[0].trim();
        if (p.length >= 10 && p.length <= 40) {
          s = p;
          break;
        }
      }
    }
  }

  return s.trim();
}

let modified = 0;
const updated = qs.map(q => {
  if (q.R.trim().length > 45) {
    const newR = cleanLongText(q.R);
    const newW1 = cleanLongText(q.W1);
    const newW2 = cleanLongText(q.W2);
    const newW3 = cleanLongText(q.W3);
    if (newR !== q.R || newW1 !== q.W1 || newW2 !== q.W2 || newW3 !== q.W3) {
      modified++;
      return {
        ...q,
        R: newR,
        W1: newW1,
        W2: newW2,
        W3: newW3
      };
    }
  }
  return q;
});

console.log(`Shortened ${modified} questions.`);
fs.writeFileSync(path.join(__dirname, '../../assets/questions.json'), JSON.stringify(updated, null, 2), 'utf8');

// Rebuild server questions
console.log('Running functions build_stake_questions.js...');
const { execSync } = require('child_process');
execSync('node functions/scripts/build_stake_questions.js', { stdio: 'inherit' });
