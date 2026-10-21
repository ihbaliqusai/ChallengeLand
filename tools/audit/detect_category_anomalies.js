const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

const anomalies = [];

// Helper check
qs.forEach((q, idx) => {
  const cat = q.Category;
  const text = (q.Q + ' ' + q.R).toLowerCase();

  // 1. Animals (حيوانات) should not contain cars, movies, countries, UN, math puzzles
  if (cat === 'حيوانات') {
    if (/فيلم|مسلسل|فورمولا|عاصمة|مجلس الأمن|استدلال|دوائر|مستطيل|أشكال مظللة|مازنين/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Non-animal content in حيوانات' });
    }
  }

  // 2. Human Body (جسم الإنسان) should not contain countries, UN, world cup, history
  if (cat === 'جسم الإنسان') {
    if (/مجلس الأمن|عاصمة|دولة|كأس العالم|رئيس|معركة|استقلال/i.test(text) && !/خلية|عضو|هرمون|عظم|قلب|دم|رئة|كبد|دماغ|عين/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Non-anatomy content in جسم الإنسان' });
    }
  }

  // 3. Capitals (عواصم) must ask for a capital or about a capital
  if (cat === 'عواصم') {
    if (!/عاصمة|عواصم/i.test(q.Q)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in عواصم does not mention عاصمة' });
    }
  }

  // 4. Currencies (عملات) must ask for a currency
  if (cat === 'عملات') {
    if (!/عملة|عملات|دينار|درهم|ريال|دولار|يورو|جنيه|فرنك|ليرة|ين|روبية|بيزو|كرونة/i.test(q.Q)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in عملات does not mention currency' });
    }
  }

  // 5. Inventions (اختراعات) must ask for an invention, inventor, discovery, or discoverer
  if (cat === 'اختراعات') {
    if (!/اخترع|اختراع|مخترع|اكتشف|اكتشاف|مكتشف|ابتكر|مبتكر|براءة اختراع|صاحب فكرة|أول من صنع|طور/i.test(q.Q)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in اختراعات does not mention invention/discovery' });
    }
  }

  // 6. Science & Space (علوم وفضاء)
  if (cat === 'علوم وفضاء') {
    if (/جزيرة تقع على المحيط|عاصمة|دوري أبطال|فيلم/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Geographical/movie question in علوم وفضاء' });
    }
  }

  // 7. World Cup (كأس العالم) must be about World Cup
  if (cat === 'كأس العالم') {
    if (!/كأس العالم|مونديال|world cup/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in كأس العالم does not mention World Cup/Mundial' });
    }
  }

  // 8. Friends (مسلسل Friends)
  if (cat === 'مسلسل Friends') {
    if (!/فريندز|friends|مونيكا|تشاندلر|جوي|رايتشل|ريتشل|فيبي|روس|غونتر|سنترال بيرك|central perk/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in مسلسل Friends might not be about Friends' });
    }
  }

  // 9. Umm Kulthum (كلثوميات)
  if (cat === 'كلثوميات') {
    if (!/أم كلثوم|ام كلثوم|كوكب الشرق|السنباطي|القصبجي|أحمد رامي|سيدة الغناء|ثومة/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in كلثوميات not mentioning Umm Kulthum keywords' });
    }
  }

  // 10. Fairouz (فيروز)
  if (cat === 'فيروز') {
    if (!/فيروز|الرحباني|عاصي|منصور|زياد|جارة القمر/i.test(text)) {
      anomalies.push({ idx, cat, q: q.Q, r: q.R, reason: 'Question in فيروز not mentioning Fairouz keywords' });
    }
  }
});

console.log('Total anomalies flagged:', anomalies.length);
fs.writeFileSync(path.join(__dirname, 'category_anomalies.json'), JSON.stringify(anomalies, null, 2), 'utf8');

// Summary by category
const summary = {};
anomalies.forEach(a => {
  summary[a.cat] = (summary[a.cat] || 0) + 1;
});
console.log('Anomalies by category:', summary);
