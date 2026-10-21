const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const aliens = [];
qs.forEach((q, idx) => {
  const cat = q.Category;
  const qText = q.Q;
  const rText = q.R;

  if (['رياضة', 'كأس العالم'].includes(cat)) {
    if (/فيلسوف|رياضيات|مؤلف كتاب|صاحب كتاب|رواية|قصيدة|شاعر|عاصمة/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Book/philosophy/geography in Sports' });
    }
  }

  if (['جغرافيا', 'دول', 'عواصم'].includes(cat)) {
    if (/كأس العالم|دوري أبطال|نادي|كرة القدم|لاعب|بطولة/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Sports in Geography/Countries' });
    }
  }

  if (['حيوانات', 'نباتات'].includes(cat)) {
    if (/فيلسوف|معلم الإسكندر|الملل والنحل|نقد العقل|الجمهورية|كتاب الشفاء|تهافت|معركة|رئيس جمهورية|فيلم|مسلسل|ممثل/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Philosophy/history/media in Nature' });
    }
  }

  if (['صحة', 'جسم الإنسان'].includes(cat)) {
    if (/مجلس الأمن|عاصمة|دولة|كأس العالم|رئيس دولة|معركة|استقلال|فيلم|ممثل/i.test(qText) && !/خلية|عضو|هرمون|عظم|قلب|دم|رئة|كبد|دماغ|عين|مرض|علاج/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Non-health in Health/Anatomy' });
    }
  }
});

console.log('Non-car aliens count:', aliens.length);
aliens.forEach(a => {
  console.log(`[${a.idx}] (${a.cat}) Q: ${a.q}\nR: ${a.r}\nReason: ${a.reason}\n`);
});
