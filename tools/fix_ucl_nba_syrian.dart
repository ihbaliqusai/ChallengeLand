import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

String cleanSimple(String text) {
  var s = text.trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }
  // Remove parentheticals
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  if (s.contains('/')) {
    s = s.split('/')[0].trim();
  }
  s = s.replaceAll(RegExp(r'[.!؟:;]+$'), '').trim();
  return s;
}

void main() {
  final mainFile = File('assets/questions.json');
  final mainList = jsonDecode(mainFile.readAsStringSync()) as List;

  // ==========================================
  // 1. دوري أبطال أوروبا
  // ==========================================
  final uclFile = File('assets/questions_ucl_300.json');
  final uclList = jsonDecode(uclFile.readAsStringSync()) as List;

  for (var q in uclList) {
    // Clean all answers first
    q['R'] = cleanSimple(q['R']);
    q['W1'] = cleanSimple(q['W1']);
    q['W2'] = cleanSimple(q['W2']);
    q['W3'] = cleanSimple(q['W3']);

    // Specific replacements for remaining long answers in UCL
    if (q['Q'].toString().contains('ملعب نهائي 2005')) {
      q['R'] = 'ملعب أتاتورك الأولمبي';
      q['W1'] = 'ملعب سان سيرو';
      q['W2'] = 'ملعب سانتياغو برنابيو';
      q['W3'] = 'ملعب أليانز أرينا';
    } else if (q['Q'].toString().contains('أياكس') && q['W2'].toString().contains('آيندهوفن')) {
      q['W2'] = 'آيندهوفن الهولندي';
    } else if (q['Q'].toString().contains('أول نادٍ فرنسي')) {
      q['R'] = 'أولمبيك مارسيليا';
      q['W1'] = 'باريس سان جيرمان';
      q['W2'] = 'نادي موناكو';
      q['W3'] = 'أولمبيك ليون';
    } else if (q['Q'].toString().contains('أول نادٍ روماني')) {
      q['R'] = 'ستيوا بوخارست';
      q['W1'] = 'دينامو بوخارست';
      q['W2'] = 'كلوج الروماني';
      q['W3'] = 'رابيد بوخارست';
    } else if (q['Q'].toString().contains('أول نادٍ صربي') || q['Q'].toString().contains('النجم الأحمر')) {
      q['R'] = 'النجم الأحمر';
      q['W1'] = 'بارتيزان بلغراد';
      q['W2'] = 'دينامو زغرب';
      q['W3'] = 'هايدوك سبليت';
    } else if (q['Q'].toString().contains('خماسية')) {
      q['R'] = 'ميسي وهالاند وأدريانو';
      q['W1'] = 'رونالدو وبنزيما ونيمار';
      q['W2'] = 'ليفاندوفسكي وسواريز ومبابي';
      q['W3'] = 'راؤول وهنري وروني';
    } else if (q['R'].toString().contains('ريال مدريد ومانشستر')) {
      q['R'] = 'ريال ومانشستر يونايتد';
    }
  }

  // ==========================================
  // 2. NBA
  // ==========================================
  final nbaFile = File('assets/questions_nba_300.json');
  final nbaList = jsonDecode(nbaFile.readAsStringSync()) as List;

  for (var q in nbaList) {
    q['R'] = cleanSimple(q['R']);
    q['W1'] = cleanSimple(q['W1']);
    q['W2'] = cleanSimple(q['W2']);
    q['W3'] = cleanSimple(q['W3']);

    if (q['Q'].toString().contains('لاري بيرد عن مايكل جوردن')) {
      q['Q'] = 'بماذا شبّه لاري بيرد أداء مايكل جوردن الخارق عام 1986؟';
      q['R'] = 'كائن أسطوري متنكر';
      q['W1'] = 'أفضل مسدد بالتاريخ';
      q['W2'] = 'لاعب عادي ومحظوظ';
      q['W3'] = 'مبتدئ سريع فقط';
    } else if (q['Q'].toString().contains('أفضل لاعب سادس') && q['R'].toString().contains('كروفورد')) {
      q['R'] = 'كروفورد ولو ويليامز';
      q['W1'] = 'مانو جينوبيلي وغوردون';
      q['W2'] = 'جيسون تيري وهاردن';
      q['W3'] = 'شريمبف وهاريل';
    } else if (q['Q'].toString().contains('الرميات الحرة التي سجلها') || q['Q'].toString().contains('شاكيل أونيل')) {
      q['Q'] = 'كم عدد الرميات الحرة التي أهدرها شاكيل أونيل تقريباً في مسيرته؟';
      q['R'] = 'أكثر من 5000';
      q['W1'] = 'أكثر من 8000';
      q['W2'] = 'نحو 2000 رمية';
      q['W3'] = 'نحو 3000 رمية';
    } else if (q['Q'].toString().contains('7 ثوانٍ أو أقل')) {
      q['R'] = 'سبع ثوانٍ أوأقل';
      q['W1'] = 'المثلث السريع';
      q['W2'] = 'هجوم برينستون';
      q['W3'] = 'موشن سيكس';
    } else if (q['Q'].toString().contains('73 نقطة فارق')) {
      q['R'] = '73 نقطة';
      q['W1'] = '68 نقطة';
      q['W2'] = '70 نقطة';
      q['W3'] = '75 نقطة';
    } else if (q['Q'].toString().contains('رباعية مزدوجة') && q['R'].toString().contains('لم يحققها')) {
      q['Q'] = 'كم لاعباً في تاريخ NBA حقق رباعية مزدوجة أكثر من مرة؟';
      q['R'] = 'صفر (ولا لاعب)';
      q['W1'] = 'لاعبان اثنان';
      q['W2'] = 'ثلاثة لاعبين';
      q['W3'] = 'لاعب واحد فقط';
    } else if (q['Q'].toString().contains('19-18 التاريخية')) {
      q['R'] = 'بيستونز وليكرز';
      q['W1'] = 'سلتكس ونيكس';
      q['W2'] = 'سيراكيوز وروتشستر';
      q['W3'] = 'فيلادلفيا وشيكاغو';
    } else if (q['W3'].toString().contains('تراي سيتيز')) {
      q['W3'] = 'تراي سيتيز';
    } else if (q['Q'].toString().contains('من دوري الـ ABA عام 1976')) {
      q['R'] = 'سبيرز وباسرز ونتس';
      q['W1'] = 'روكتس ومافريكس وممفيس';
      q['W2'] = 'جاز وكينغز وكليبرز';
      q['W3'] = 'ماجيك وهورنتس وميامي';
    } else if (q['Q'].toString().contains('تصويبته الأخيرة الخالدة')) {
      q['R'] = 'قبل 5 ثوانٍ';
      q['W1'] = 'قبل ثانيتين';
      q['W2'] = 'قبل 8 ثوانٍ';
      q['W3'] = 'مع الصافرة مباشرة';
    } else if (q['Q'].toString().contains('غوبير')) {
      q['R'] = 'يوتا ومينيسوتا';
      q['W1'] = 'يوتا ودنفر';
      q['W2'] = 'مينيسوتا ودالاس';
      q['W3'] = 'يوتا وكليبرز';
    }
  }

  // ==========================================
  // 3. دراما سورية
  // ==========================================
  final syrianFile = File('assets/questions_syrian_drama_300.json');
  final syrianList = jsonDecode(syrianFile.readAsStringSync()) as List;

  for (var q in syrianList) {
    q['R'] = cleanSimple(q['R']);
    q['W1'] = cleanSimple(q['W1']);
    q['W2'] = cleanSimple(q['W2']);
    q['W3'] = cleanSimple(q['W3']);

    if (q['Q'].toString().contains('ضيعة ضايعة') && q['R'].toString().contains('أسعد')) {
      q['R'] = 'أسعد وجودة';
      q['W1'] = 'سلنغو وأبو نادر';
      q['W2'] = 'صالح وحسان';
      q['W3'] = 'غوار وحسني';
    } else if (q['Q'].toString().contains('المدير العام الذي تنكر')) {
      q['R'] = 'أحمد عبدالحق';
      q['W1'] = 'سعيد النايحة';
      q['W2'] = 'جميل الحمصي';
      q['W3'] = 'مفيد الوحش';
    } else if (q['Q'].toString().contains('حسني البورظان في مسلسل صح النوم')) {
      q['Q'] = 'ما الدولة اللاتينية التي كررها حسني البورظان: يجب أن نعرف ماذا في...؟';
      q['R'] = 'البرازيل';
      q['W1'] = 'الأرجنتين';
      q['W2'] = 'المكسيك';
      q['W3'] = 'كولومبيا';
    } else if (q['Q'].toString().contains('بقعة ضوء الكوميدية')) {
      q['R'] = 'أيمن رضا وياخور';
      q['W1'] = 'ياسر العظمة ولحام';
      q['W2'] = 'أحمد ومحمد حداقي';
      q['W3'] = 'فارس وأندريه سكاف';
    } else if (q['W3'].toString().contains('الموت القادم')) {
      q['W3'] = 'الموت القادم للشرق';
    } else if (q['Q'].toString().contains('سعيد النايحة عام 1999')) {
      q['R'] = 'بطل هذا الزمان';
      q['W1'] = 'يوميات مدير عام';
      q['W2'] = 'جميل وهناء';
      q['W3'] = 'أنت عمري';
    } else if (q['Q'].toString().contains('مهنة الموظف سعيد النايحة')) {
      q['R'] = 'موظف أرشيف حكومي';
      q['W1'] = 'طبيب في عيادة';
      q['W2'] = 'مهندس بناء';
      q['W3'] = 'سائق أجرة';
    } else if (q['Q'].toString().contains('أخرجه هيثم حقي عام 1991')) {
      q['R'] = 'هجرة القلوب';
      q['W1'] = 'خان الحرير';
      q['W2'] = 'الدغري';
      q['W3'] = 'أيام شامية';
    } else if (q['Q'].toString().contains('مهنة بطل العمل عبدو في مسلسل العربجي')) {
      q['R'] = 'سائق عربة خيل';
      q['W1'] = 'حداد الحارة';
      q['W2'] = 'نجار الخشب';
      q['W3'] = 'قصاب اللحوم';
    } else if (q['Q'].toString().contains('أبو عمر في مسلسل أحلام كبيرة')) {
      q['R'] = 'خياط أقمشة';
      q['W1'] = 'معلم مدرسة';
      q['W2'] = 'سائق شاحنة';
      q['W3'] = 'بقال في الحي';
    } else if (q['Q'].toString().contains('يوميات جميل وهناء وألو جميل')) {
      q['R'] = 'زياد نعيم الريس';
      q['W1'] = 'ممدوح حمادة';
      q['W2'] = 'حكم البابا';
      q['W3'] = 'داوود شيخاني';
    } else if (q['Q'].toString().contains('غدا نلتقي أين كانت تعيش')) {
      q['R'] = 'مدرسة قديمة مهجورة';
      q['W1'] = 'فندق شعبي قديم';
      q['W2'] = 'ورشة بناء مهجورة';
      q['W3'] = 'مخيم على الحدود';
    } else if (q['Q'].toString().contains('عائلة الحجار') && q['Q'].toString().contains('صفيح ساخن')) {
      q['R'] = 'تجارة مكبات النفايات';
      q['W1'] = 'تهريب السلاح';
      q['W2'] = 'تزوير العملات';
      q['W3'] = 'تجارة المخدرات';
    } else if (q['Q'].toString().contains('ليس سراباً ما القضية')) {
      q['R'] = 'الزواج المدني';
      q['W1'] = 'الصراع الطبقي';
      q['W2'] = 'الهجرة غير الشرعية';
      q['W3'] = 'غسيل الأموال';
    } else if (q['Q'].toString().contains('ولاد بديعة') && q['R'].toString().contains('علي وجيه')) {
      q['R'] = 'علي ويامن الحجلي';
      q['W1'] = 'حسن سامي ونجيب';
      q['W2'] = 'ممدوح عدوان وحاتم';
      q['W3'] = 'فادي وسامر رضوان';
    } else if (q['Q'].toString().contains('الخربة الكوميدي ما هما العائلتان')) {
      q['R'] = 'بو مالحة وبو قعقور';
      q['W1'] = 'بو نايف وبو راشد';
      q['W2'] = 'الكبش والضبع';
      q['W3'] = 'العطار والدباغ';
    } else if (q['Q'].toString().contains('أبو عنتر') && q['Q'].toString().contains('مسلسلات غوار')) {
      q['Q'] = 'ما اليمين التهديدي الشهير الذي كان يحلفه أبو عنتر في مسلسلات غوار؟';
      q['R'] = 'وقاطع إيدي';
      q['W1'] = 'وحياة شواربي';
      q['W2'] = 'وعهد الله';
      q['W3'] = 'ودم عيني';
    } else if (q['W1'].toString().contains('بصمات على جدار')) {
      q['W1'] = 'بصمات جدار الزمن';
    } else if (q['W2'].toString().contains('هجرة القلوب')) {
      q['W2'] = 'هجرة القلوب';
    } else if (q['W1'].toString().contains('ألو جميل ألو هناء')) {
      q['W1'] = 'ألو جميل';
    } else if (q['W2'].toString().contains('بطل من هذا الزمان')) {
      q['W2'] = 'بطل الزمان';
    }
  }

  // Save standalone files
  uclFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(uclList));
  nbaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(nbaList));
  syrianFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(syrianList));

  print('=== Verification after fixes: ===');
  int uclLong = 0, nbaLong = 0, syrianLong = 0;
  for (var q in uclList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) uclLong++;
  }
  for (var q in nbaList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) nbaLong++;
  }
  for (var q in syrianList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) syrianLong++;
  }

  print('دوري أبطال أوروبا long answers: $uclLong');
  print('NBA long answers: $nbaLong');
  print('دراما سورية long answers: $syrianLong');

  // Update in mainList
  int replacedCount = 0;
  for (int i = 0; i < mainList.length; i++) {
    final cat = mainList[i]['Category'];
    if (cat == 'دوري أبطال أوروبا') {
      final qText = mainList[i]['Q'];
      final match = uclList.firstWhere((item) => item['Q'] == qText, orElse: () => null);
      if (match != null) {
        mainList[i] = match;
        replacedCount++;
      }
    } else if (cat == 'NBA') {
      final qText = mainList[i]['Q'];
      final match = nbaList.firstWhere((item) => item['Q'] == qText, orElse: () => null);
      if (match != null) {
        mainList[i] = match;
        replacedCount++;
      }
    } else if (cat == 'دراما سورية') {
      final qText = mainList[i]['Q'];
      final match = syrianList.firstWhere((item) => item['Q'] == qText, orElse: () => null);
      if (match != null) {
        mainList[i] = match;
        replacedCount++;
      }
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Successfully updated main questions.json (replaced $replacedCount entries)');
}
