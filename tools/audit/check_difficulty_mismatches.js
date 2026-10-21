const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

// Sample checks
const easyInHard = [];
const hardInEasy = [];

qs.forEach((q, idx) => {
  const isHardLevel = ['3', '7', '8'].includes(q.Level);
  const isEasyLevel = ['0', '1', '2'].includes(q.Level);

  // Check if a super-common easy question is placed in Hard (3, 7, 8)
  if (isHardLevel) {
    if (/عاصمة مصر|عاصمة فرنسا|عاصمة إيطاليا|عاصمة السعودية|عدد أركان الإسلام|أكبر كوكب|أسرع حيوان|ملك الغابة|عدد شهور السنة|ألوان إشارة المرور/i.test(q.Q)) {
      easyInHard.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R });
    }
  }

  // Check if an obscure, specialized date/metric is in Easy (0, 1, 2)
  if (isEasyLevel) {
    if (/في أي عام تم توقيع معاهدة|ما هي الصيغة الكيميائية لـ|كم تبلغ المسافة الدقيقة بين|في أي دقيقة من مباراة/i.test(q.Q)) {
      hardInEasy.push({ idx, cat: q.Category, lvl: q.Level, q: q.Q, r: q.R });
    }
  }
});

console.log('Easy questions in Hard tier:', easyInHard.length);
console.log(easyInHard);

console.log('Hard questions in Easy tier:', hardInEasy.length);
console.log(hardInEasy);
