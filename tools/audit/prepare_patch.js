const fs = require('fs');
const path = require('path');

const qs = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/questions.json'), 'utf8'));

console.log('Original count:', qs.length);

// 1. Explicit replacement dictionary for misplaced / negative questions
const replacements = {
  377: {
    Level: '0',
    Category: 'دول',
    Q: 'ما هي الدولة العربية التي تقع فيها مدينة البتراء الأثرية المنحوتة في الصخر؟',
    R: 'الأردن',
    W1: 'سوريا',
    W2: 'العراق',
    W3: 'لبنان'
  },
  568: {
    Level: '4',
    Category: 'حيوانات',
    Q: 'ما هو أكبر أنواع السلاحف البرية في العالم وموطنها جزر المحيط الهادئ؟',
    R: 'سلحفاة غالاباغوس العملاقة',
    W1: 'السلحفاة المشعة',
    W2: 'السلحفاة النمرية',
    W3: 'السلحفاة اليونانية'
  },
  655: {
    Level: '1',
    Category: 'حيوانات',
    Q: 'ما هو الطائر الوديع الذي يُعد رمزاً عالمياً للسلام والمحبة؟',
    R: 'الحمامة',
    W1: 'الغراب',
    W2: 'الصقر',
    W3: 'البومة'
  },
  659: {
    Level: '1',
    Category: 'نباتات',
    Q: 'ما هي الشجرة المباركة التي يُستخرج من ثمارها زيت شهير وتعد رمزاً للصمود؟',
    R: 'شجرة الزيتون',
    W1: 'شجرة النخيل',
    W2: 'شجرة التين',
    W3: 'شجرة الأرز'
  },
  696: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو الشيء الذي يمتلك أسناناً كثيرة ولكنه لا يعض؟',
    R: 'المشط',
    W1: 'المنشار',
    W2: 'المفتاح',
    W3: 'القفل'
  },
  736: {
    Level: '3',
    Category: 'جسم الإنسان',
    Q: 'ما هي أصغر عظمة في جسم الإنسان وتقع داخل الأذن الوسطى؟',
    R: 'عظمة الركاب',
    W1: 'عظمة المطرقة',
    W2: 'عظمة السندان',
    W3: 'عظمة الترقوة'
  },
  745: {
    Level: '1',
    Category: 'رياضة',
    Q: 'كم عدد لاعبي فريق كرة السلة الأساسيين داخل أرض الملعب أثناء المباراة؟ (اكتب الرقم بالأرقام)',
    R: '5',
    W1: '6',
    W2: '7',
    W3: '4'
  },
  749: {
    Level: '1',
    Category: 'علوم وفضاء',
    Q: 'ما هو أقرب كوكب إلى الشمس في مجموعتنا الشمسية؟',
    R: 'عطارد',
    W1: 'الزهرة',
    W2: 'المريخ',
    W3: 'المشتري'
  },
  974: {
    Level: '5',
    Category: 'حيوانات',
    Q: 'ما هو العضو الحسي الفريد لدى الأفاعي المستخدم لشم واستشعار الروائح في الهواء؟',
    R: 'عضو جاكوبسون',
    W1: 'الخط الجانبي',
    W2: 'الغدد النكفية',
    W3: 'القرون الاستشعارية'
  },
  1144: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو أصغر عدد فردي غير أولي (مركّب) أكبر من الواحد؟ (اكتب الرقم بالأرقام)',
    R: '9',
    W1: '7',
    W2: '5',
    W3: '3'
  },
  1145: {
    Level: '6',
    Category: 'ألغاز',
    Q: 'ما هو ناتج ضرب العدد 4 في نفسه مضافاً إليه العدد 2؟ (اكتب الرقم بالأرقام)',
    R: '18',
    W1: '16',
    W2: '20',
    W3: '14'
  },
  1146: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو مفرد كلمة "كُتُب" في اللغة العربية؟',
    R: 'كتاب',
    W1: 'كاتب',
    W2: 'كتيب',
    W3: 'مكتبة'
  },
  1171: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو ناتج قسمة العدد 30 على العدد 3؟ (اكتب الرقم بالأرقام)',
    R: '10',
    W1: '12',
    W2: '15',
    W3: '18'
  },
  1215: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو حاصل ضرب العدد 3 في العدد 11؟ (اكتب الرقم بالأرقام)',
    R: '33',
    W1: '29',
    W2: '37',
    W3: '41'
  },
  1260: {
    Level: '1',
    Category: 'ألغاز',
    Q: 'ما هو حاصل ضرب العدد 8 في العدد 9؟ (اكتب الرقم بالأرقام)',
    R: '72',
    W1: '68',
    W2: '74',
    W3: '76'
  },
  1494: {
    Level: '7',
    Category: 'حيوانات',
    Q: 'ما هو الطائر الوحيد القادر على الطيران إلى الخلف والتحليق في مكانه بثبات؟',
    R: 'طائر الطنان',
    W1: 'السنونو',
    W2: 'الهدهد',
    W3: 'الرفراف'
  },
  1712: {
    Level: '7',
    Category: 'حيوانات',
    Q: 'ما هو أسرع كائن حي على وجه الأرض وتصل سرعة انقضاضه لأكثر من 300 كم/ساعة؟',
    R: 'صقر الشاهين',
    W1: 'الفهد الصياد',
    W2: 'السمكة الشراعية',
    W3: 'العقاب الذهبي'
  },
  1868: {
    Level: '7',
    Category: 'حيوانات',
    Q: 'ما هو أثقل حيوان ثديي بري في العالم بعد الفيل؟',
    R: 'وحيد القرن الأبيض',
    W1: 'فرس النهر',
    W2: 'الزرافة',
    W3: 'الدب القطبي'
  },
  1875: {
    Level: '7',
    Category: 'حيوانات',
    Q: 'ما هو الحيوان الثديي الوحيد المغطى كلياً بحراشف قرنية صلبة لحمايته؟',
    R: 'البنغول (آكل النمل الحرشفي)',
    W1: 'المدرع',
    W2: 'الإيكيدنا',
    W3: 'القنفذ'
  },
  1931: {
    Level: '6',
    Category: 'حيوانات',
    Q: 'ما هو الحيوان البحري الذكي الذي يستطيع النوم وإحدى عينيه مفتوحة ونصف دماغه مستيقظ؟',
    R: 'الدولفين',
    W1: 'القرش',
    W2: 'الأخطبوط',
    W3: 'فقمة البحر'
  },
  2023: {
    Level: '7',
    Category: 'حيوانات',
    Q: 'كم قلباً يمتلك الأخطبوط لضخ الدم في جسمه وخياشيمه؟ (اكتب الرقم بالأرقام)',
    R: '3',
    W1: '2',
    W2: '4',
    W3: '1'
  },
  2090: {
    Level: '8',
    Category: 'حيوانات',
    Q: 'ما هو الكائن المائي المجهري الشهير المعروف بقدرته الفائقة على النجاة في الفراغ الفضائي؟',
    R: 'دب الماء (تارديغرادا)',
    W1: 'البراميسيوم',
    W2: 'الروتيفيرا',
    W3: 'اليوجلينا'
  },
  8517: {
    Level: '1',
    Category: 'رياضة',
    Q: 'ما هو مركز اللاعب الوحيد في كرة القدم المسموح له بلمس الكرة بيديه داخل منطقة الجزاء؟',
    R: 'حارس المرمى',
    W1: 'المهاجم',
    W2: 'المدافع',
    W3: 'صانع الألعاب'
  },
  9349: {
    Level: '8',
    Category: 'فيروز',
    Q: 'في أي عام قُدمت المسرحية الغنائية الشهيرة «ميس الريم» للأخوين رحباني وبطولة فيروز؟ (اكتب الرقم بالأرقام)',
    R: '1975',
    W1: '1970',
    W2: '1980',
    W3: '1965'
  },
  13612: {
    Level: '0',
    Category: 'مسلسلات أجنبية',
    Q: 'ما اسم مدرس الكيمياء الذي يتحول لصانع مواد غير قانونية في مسلسل Breaking Bad؟ (اكتب بالإنجليزية)',
    R: 'Walter White',
    W1: 'Jesse Pinkman',
    W2: 'Saul Goodman',
    W3: 'Hank Schrader'
  },
  13667: {
    Level: '1',
    Category: 'مسلسلات أجنبية',
    Q: 'ما اسم المحامي الشهير ذي الشخصية الماكرة في مسلسلي Breaking Bad و Better Call Saul؟ (اكتب بالإنجليزية)',
    R: 'Saul Goodman',
    W1: 'Walter White',
    W2: 'Hank Schrader',
    W3: 'Mike Ehrmantraut'
  },
  13668: {
    Level: '1',
    Category: 'مسلسلات أجنبية',
    Q: 'في أي عائلة مافيا تدور الأحداث الرئيسية لمسلسل الجريمة والدراما الشهير The Sopranos؟ (اكتب بالإنجليزية)',
    R: 'Soprano',
    W1: 'Corleone',
    W2: 'Shelby',
    W3: 'Stark'
  }
};

let replacedCount = 0;
let songsUpdated = 0;
let englishHintsAdded = 0;
let digitHintsAdded = 0;

const updatedQs = qs.map((q, idx) => {
  let item = { ...q };

  // 1. Direct replacement if targeted
  if (replacements[idx]) {
    item = { ...item, ...replacements[idx] };
    replacedCount++;
    return item;
  }

  // 2. خمن الأغنية: add artist hint
  if (item.Category === 'خمن الأغنية') {
    const parts = item.R.split(' - ');
    if (parts.length > 1) {
      const artist = parts[1].trim();
      if (!item.Q.includes(artist)) {
        // Replace prefix
        if (item.Q.startsWith('ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى:')) {
          item.Q = item.Q.replace(
            'ما هي الأغنية الشهيرة المقصودة من هذه الكلمات بالفصحى:',
            `ما هي الأغنية الشهيرة للفنان (${artist}) المقصودة من هذه الكلمات:`
          );
          songsUpdated++;
        } else if (!item.Q.includes(artist)) {
          item.Q = item.Q.replace('ما هي الأغنية', `ما هي أغنية الفنان (${artist})`);
          songsUpdated++;
        }
      }
    }
  }

  // 3. English answers hint
  const hasLatinR = /[a-zA-Z]/.test(item.R);
  const hintEnglish = /(إنجليز|انجليز|English|باللاتيني|بالحروف الإنجليزية|اكتب بالإنجليزية)/i.test(item.Q);
  if (hasLatinR && !hintEnglish) {
    // Add hint cleanly to question text
    if (item.Q.endsWith('؟')) {
      item.Q = item.Q.slice(0, -1).trim() + '؟ (اكتب بالإنجليزية)';
    } else {
      item.Q = item.Q.trim() + ' (اكتب بالإنجليزية)';
    }
    englishHintsAdded++;
  }

  // 4. Pure digits answer hint
  const isDigitsR = /^\d+$/.test(item.R.trim());
  const hintDigits = /(أرقام|ارقام|بالأرقام|بالارقام|عدداً|رقماً|اكتب الرقم|بالأرقام فقط)/i.test(item.Q);
  if (isDigitsR && !hintDigits) {
    if (item.Q.endsWith('؟')) {
      item.Q = item.Q.slice(0, -1).trim() + '؟ (اكتب الرقم بالأرقام)';
    } else {
      item.Q = item.Q.trim() + ' (اكتب الرقم بالأرقام)';
    }
    digitHintsAdded++;
  }

  return item;
});

console.log(`Summary of prepared changes:
- Replaced/Fixed target questions: ${replacedCount}
- Songs with artist hint added: ${songsUpdated}
- English answers with hint added: ${englishHintsAdded}
- Digit answers with hint added: ${digitHintsAdded}
- Total questions in output: ${updatedQs.length}
`);

// Validate data integrity
let errors = 0;
updatedQs.forEach((q, i) => {
  if (!q.Q || !q.R || !q.W1 || !q.W2 || !q.W3 || !q.Level || !q.Category) {
    console.error(`Missing field at index ${i}`);
    errors++;
  }
  const choices = [q.R, q.W1, q.W2, q.W3].map(x => (x || '').trim());
  if (new Set(choices).size < 4) {
    console.error(`Duplicate choices at index ${i}: ${choices.join(' | ')}`);
    errors++;
  }
});

if (errors === 0) {
  console.log('PASSED ALL INTEGRITY CHECKS! No missing fields, no duplicate choices.');
} else {
  console.error(`FAILED WITH ${errors} ERRORS!`);
}
