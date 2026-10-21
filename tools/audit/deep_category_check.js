const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const candidates = [];

qs.forEach((q, idx) => {
  const c = q.Category;
  const fullText = (q.Q + ' ' + q.R).trim();

  // 1. Spacetoon questions outside Spacetoon / Anime
  if (!['سبيس تون', 'الأنمي'].includes(c)) {
    if (/سبيس تون|سبيستون|كابتن ماجد|المحقق كونان|دراغون بول|أبطال الديجيتال|سلام دانك/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'سبيس تون', q: q.Q, r: q.R });
    }
  }

  // 2. Friends questions outside Friends
  if (c !== 'مسلسل Friends') {
    if (/مسلسل فريندز|مسلسل friends|شخصية تشاندلر|شخصية جوي تريبياني|شخصية فيبي بوفيه|شخصية مونيكا غيلر|شخصية ريتشل غرين|شخصية روس غيلر/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'مسلسل Friends', q: q.Q, r: q.R });
    }
  }

  // 3. Umm Kulthum outside كلثوميات
  if (c !== 'كلثوميات' && c !== 'فنون وسينما' && c !== 'خمن الأغنية') {
    if (/أم كلثوم|كوكب الشرق/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'كلثوميات', q: q.Q, r: q.R });
    }
  }

  // 4. Fairouz outside فيروز
  if (c !== 'فيروز' && c !== 'فنون وسينما' && c !== 'خمن الأغنية') {
    if (/السيدة فيروز|جارة القمر|الأخوين رحباني|زياد الرحباني/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'فيروز', q: q.Q, r: q.R });
    }
  }

  // 5. Quran / Prophets outside دين وإسلاميات / قصص الأنبياء
  if (!['دين وإسلاميات', 'قصص الأنبياء'].includes(c)) {
    if (/سورة في القرآن|آية الكرسي|كم عدد سور القرآن|سفينة نوح|ناقة صالح|طوفان نوح/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'دين وإسلاميات / قصص الأنبياء', q: q.Q, r: q.R });
    }
  }

  // 6. World Cup outside كأس العالم / رياضة
  if (!['كأس العالم', 'رياضة'].includes(c)) {
    if (/كأس العالم \d\d\d\d|مونديال \d\d\d\d|هداف كأس العالم/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'كأس العالم', q: q.Q, r: q.R });
    }
  }

  // 7. Currencies outside عملات
  if (!['عملات', 'دول', 'معلومات عامة'].includes(c)) {
    if (/ما هي العملة الرسمية في|ما اسم العملة في/i.test(q.Q)) {
      candidates.push({ idx, current: c, suggested: 'عملات', q: q.Q, r: q.R });
    }
  }

  // 8. Capitals outside عواصم
  if (!['عواصم', 'دول', 'جغرافيا', 'معلومات عامة'].includes(c)) {
    if (/ما هي عاصمة|ما عاصمة دولة/i.test(q.Q)) {
      candidates.push({ idx, current: c, suggested: 'عواصم', q: q.Q, r: q.R });
    }
  }

  // 9. Cars outside سيارات / تقنية
  if (!['سيارات', 'تقنية', 'اختراعات'].includes(c)) {
    if (/شركة سيارات|طراز سيارة|محرك V8|صانع سيارات/i.test(fullText)) {
      candidates.push({ idx, current: c, suggested: 'سيارات', q: q.Q, r: q.R });
    }
  }
});

console.log('Cross-category checks found:', candidates.length);
candidates.forEach(cand => {
  console.log(`[${cand.idx}] Current: ${cand.current} -> Suggested: ${cand.suggested}\nQ: ${cand.q}\nR: ${cand.r}\n`);
});
