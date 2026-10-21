const fs = require('fs');
const path = require('path');
const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const aliens = [];

qs.forEach((q, idx) => {
  const cat = q.Category;
  const qText = q.Q;
  const rText = q.R;

  // Science / Books / Philosophy in Sports or World Cup
  if (['رياضة', 'كأس العالم'].includes(cat)) {
    if (/فيلسوف|رياضيات|مؤلف كتاب|صاحب كتاب|رواية|قصيدة|شاعر|عاصمة/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Book/philosophy/geography in Sports' });
    }
  }

  // Sports in Geography or Countries
  if (['جغرافيا', 'دول', 'عواصم'].includes(cat)) {
    if (/كأس العالم|دوري أبطال|نادي|كرة القدم|لاعب|بطولة/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Sports in Geography/Countries' });
    }
  }

  // Philosophy / History in Animals or Plants
  if (['حيوانات', 'نباتات'].includes(cat)) {
    if (/فيلسوف|معلم الإسكندر|الملل والنحل|نقد العقل|الجمهورية|كتاب الشفاء|تهافت|معركة|رئيس جمهورية|فيلم|مسلسل|ممثل/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Philosophy/history/media in Nature' });
    }
  }

  // Non-medical in Health or Human Body
  if (['صحة', 'جسم الإنسان'].includes(cat)) {
    if (/مجلس الأمن|عاصمة|دولة|كأس العالم|رئيس دولة|معركة|استقلال|فيلم|ممثل/i.test(qText) && !/خلية|عضو|هرمون|عظم|قلب|دم|رئة|كبد|دماغ|عين|مرض|علاج/i.test(qText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Non-health in Health/Anatomy' });
    }
  }

  // Non-cars in Cars
  if (cat === 'سيارات') {
    if (!/سيار|محرك|مركبة|إطار|فرامل|فورد|تويوتا|مرسيدس|بي ام|فيراري|بورشه|هوندا|نيسان|تسلا|أودي|شاحنة|دراجة|سرعة|بنزين|وقود|صانع|طراز|موديل|علامة تجارية/i.test(qText + ' ' + rText)) {
      aliens.push({ idx, cat, q: qText, r: rText, reason: 'Non-automotive in Cars' });
    }
  }
});

console.log('Total alien questions found:', aliens.length);
aliens.forEach(a => {
  console.log(`[${a.idx}] (${a.cat}) Q: ${a.q} -> R: ${a.r} (${a.reason})`);
});
