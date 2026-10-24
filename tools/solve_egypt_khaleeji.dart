import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String cleanSimple(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  t = t.replaceAll(RegExp(r'\s*/\s*.*$'), '');
  t = t.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
  return t.trim();
}

void main() {
  final egyptFile = File('assets/questions_egyptian_drama_300.json');
  final khaleejiFile = File('assets/questions_khaleeji_drama_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> egyptList = jsonDecode(egyptFile.readAsStringSync());
  final List<dynamic> khaleejiList = jsonDecode(khaleejiFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  void fixEgyptian(Map<String, dynamic> q) {
    // 1. Simple cleaning first
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    // Specific replacements for Egyptian drama:
    if (qText.contains('فرقة ناجي عطا الله')) {
      q['R'] = 'فرقة ناجي عطاالله';
    }
    if (qText.contains('فضة المعداوي')) {
      q['Q'] = 'ما الجملة الشهيرة التي كانت تنادي بها فضة المعداوي سائقها في الراية البيضا؟';
      q['R'] = 'التمساح ياللا';
      q['W1'] = 'عباس الضو بيقول';
      q['W2'] = 'أنا بابا يلا';
      q['W3'] = 'يا صلاة الزين';
    }
    if (qText.contains('محمد جلال عبد القوي')) {
      q['R'] = 'محمد جلال عبدالقوي';
      q['W1'] = 'أسامة أنور عكاشة';
      q['W2'] = 'مجدي صابر';
      q['W3'] = 'محسن زايد';
    }
    if (qText.contains('عمر بن عبد العزيز')) {
      q['R'] = 'عمر بن عبدالعزيز';
      q['W1'] = 'هارون الرشيد';
      q['W2'] = 'عمرو بن العاص';
      q['W3'] = 'طارق بن زياد';
    }
    if (qText.contains('الرجل الذي فقد ذاكرته مرتين')) {
      q['Q'] = 'ما اسم مسلسل أحمد زكي ونيللي عام 1981 عن فاقد الذاكرة مرتين؟';
      q['R'] = 'الرجل فاقد الذاكرة';
      q['W1'] = 'ألف ليلة وليلة';
      q['W2'] = 'هو وهي';
      q['W3'] = 'إلا الدمعة الحزينة';
    }
    if (qText.contains('الاختيار (رجال الظل)')) {
      q['Q'] = 'من بطلا الجزء الثاني من مسلسل الاختيار (رجال الظل) في رمضان 2021؟';
      q['R'] = 'كريم عبدالعزيز ومكي';
      q['W1'] = 'كرارة والسقا';
      q['W2'] = 'ياسر جلال والصاوي';
      q['W3'] = 'أحمد عز ولطفي';
    }
    if (qText.contains('الاختيار 3 (القرار)')) {
      q['Q'] = 'أي من هؤلاء النجوم شارك في بطولة الاختيار 3 (القرار)؟';
      q['R'] = 'أحمد السقا';
      q['W1'] = 'محمد رمضان';
      q['W2'] = 'عمرو يوسف';
      q['W3'] = 'آسر ياسين';
    }
    if (qText.contains('فندق ومحافظة تجري أحداث الغموض')) {
      q['Q'] = 'في أي فندق بمرسى مطروح تجري أحداث الغموض لمسلسل غرفة 207؟';
      q['R'] = 'فندق لونا';
      q['W1'] = 'فندق أوبروي';
      q['W2'] = 'فندق سان ستيفانو';
      q['W3'] = 'فندق فلسطين';
    }
    if (qText.contains('في كل أسبوع يوم جمعة')) {
      q['Q'] = 'ما اسم رواية إبراهيم عبد المجيد التي اقتبس منها مسلسل في كل أسبوع يوم جمعة؟';
      q['R'] = 'أسبوع يوم جمعة';
      q['W1'] = 'طيور العنبر';
      q['W2'] = 'بيت الياسمين';
      q['W3'] = 'الإسكندرية والغياب';
    }
    if (qText.contains('خالد نور وولده نور خالد')) {
      q['Q'] = 'ما اسم مسلسل شيكو وكريم محمود عبد العزيز الفانتازي عام 2024؟';
      q['R'] = 'خالد نور وولده';
      q['W1'] = 'الرجل العناب';
      q['W2'] = 'خلصانة بشياكة';
      q['W3'] = 'كوكب 14';
    }
    if (qText.contains('المال والبنون')) {
      q['R'] = 'الحجار وحنان ماضي';
      q['W1'] = 'الحلو وشيرين وجدي';
      q['W2'] = 'مدحت صالح وعمار';
      q['W3'] = 'الحجار وأنوشكا';
    }
    if (qText.contains('لن أعيش في جلباب أبي')) {
      q['Q'] = 'من صاحب رواية لن أعيش في جلباب أبي التي تحولت لمسلسل شهير؟';
      q['R'] = 'إحسان عبدالقدوس';
      q['W1'] = 'نجيب محفوظ';
      q['W2'] = 'يوسف إدريس';
      q['W3'] = 'توفيق الحكيم';
    }
    if (qText.contains('عائلة الحاج متولي والعطار والسبع بنات')) {
      q['W1'] = 'محمد جلال عبدالقوي';
    }
    if (qText.contains('الناس في كفر عسكر')) {
      q['R'] = 'كفر عسكر';
      q['W1'] = 'سوق العصر';
      q['W2'] = 'حلم الجنوبي';
      q['W3'] = 'الشارع الجديد';
    }
    if (qText.contains('تحفة ومغارة علي بابا')) {
      q['R'] = 'مغارة علي بابا';
      q['W1'] = 'السفينة التائهة';
      q['W2'] = 'خان الخليلي';
      q['W3'] = 'بين القصرين';
    }
    if (qText.contains('صابر يا عم صابر ومسلسل البخيل وأنا')) {
      q['R'] = 'فريد شوقي';
      q['W1'] = 'يوسف معاطي';
      q['W2'] = 'لينين الرملي';
      q['W3'] = 'فيصل ندا';
    }
  }

  void fixKhaleeji(Map<String, dynamic> q) {
    // 1. Simple cleaning first
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    // Specific replacements for Khaleeji drama:
    if (qText.contains('عبد الكريم عبد القادر')) {
      q['W3'] = 'عبدالكريم عبدالقادر';
    }
    if (qText.contains('جرح الزمن عام 2001')) {
      q['W3'] = 'عبدالكريم عبدالقادر';
      q['W1'] = 'عبدالله الرويشد';
    }
    if (qText.contains('الأقدار')) {
      q['R'] = 'عبدالحسين عبدالرضا';
      q['W3'] = 'عبدالأمير التركي';
    }
    if (qText.contains('ريح الشمال')) {
      q['Q'] = 'ما هي البيئة التراثية التي دار حولها المسلسل الإماراتي ريح الشمال؟';
      q['R'] = 'حياة البحر والغوص';
      q['W1'] = 'حياة البادية';
      q['W2'] = 'زراعة النخيل';
      q['W3'] = 'سكان الجبال';
    }
    if (qText.contains('سوق المقاصيص')) {
      q['Q'] = 'ما هي مهنة بو هباش التي جسدها عبد الحسين في سوق المقاصيص؟';
      q['R'] = 'بائع في الحراج';
      q['W1'] = 'صائغ ذهب';
      q['W2'] = 'نوخذة سفينة';
      q['W3'] = 'تاجر عقارات';
    }
    if (qText.contains('الجزء الثالث من مسلسل العاصوف')) {
      q['Q'] = 'في أي حقبة دارت أحداث الجزء الثالث من مسلسل العاصوف؟';
      q['R'] = 'حقبة التسعينات';
      q['W1'] = 'حقبة السبعينات';
      q['W2'] = 'حقبة الثمانينات';
      q['W3'] = 'الألفية الحديثة';
    }
    if (qText.contains('على الدنيا السلام وأدت للقبض عليهما')) {
      q['Q'] = 'ما المهنة الطريفة لمحظوظة ومبروكة في على الدنيا السلام وأدت للقبض عليهما؟';
      q['R'] = 'طقاقات بالأعراس';
      q['W1'] = 'مضيفات طيران';
      q['W2'] = 'سائقات حافلات';
      q['W3'] = 'بائعات ذهب';
    }
    if (qText.contains('خيوط المعازيب') && qText.contains('الكاتبان')) {
      q['Q'] = 'من كاتب سيناريو وقصة المسلسل السعودي خيوط المعازيب؟';
      q['R'] = 'حسن العبدي';
      q['W1'] = 'خلف الحربي';
      q['W2'] = 'بندر باجبع';
      q['W3'] = 'سعد المدهش';
    }
    if (qText.contains('سوالف طفاش') && qText.contains('كتب')) {
      q['Q'] = 'من كاتب ومخرج المسلسل الكوميدي البحريني سوالف طفاش؟';
      q['R'] = 'أحمد الكوهجي';
      q['W1'] = 'راشد المعاودة';
      q['W2'] = 'أمين صالح';
      q['W3'] = 'عيسى الحمر';
    }
    if (qText.contains('أحمد جوهر')) {
      q['W3'] = 'عبدالإمام عبدالله';
    }
    if (qText.contains('درب الزلق') && qText.contains('التثمين')) {
      q['Q'] = 'كم كان مبلغ التثمين الذي ناله حسين وسعد ثمناً لبيتهم في درب الزلق؟';
      q['R'] = '40 ألف دينار';
      q['W1'] = '20 ألف دينار';
      q['W2'] = '100 ألف دينار';
      q['W3'] = '50 ألف دينار';
    }
    if (qText.contains('الحيالة الكوميدية')) {
      q['R'] = 'دعيج الخليفة الصباح';
      q['W2'] = 'عبداللطيف البناي';
    }
    if (qText.contains('ثمن عمري')) {
      q['R'] = 'صباح الناصر الصباح';
      q['W3'] = 'دعيج الخليفة الصباح';
    }
    if (qText.contains('سعدون') && qText.contains('الشاعر البحريني')) {
      q['R'] = 'علي عبدالله خليفة';
      q['W3'] = 'عبدالرحمن رفيع';
    }
    if (qText.contains('والد صديق حسين')) {
      q['R'] = 'التاجر بو فهد';
      q['W1'] = 'بو صالح';
      q['W2'] = 'بو ناشي';
      q['W3'] = 'المطوع';
    }
    if (qText.contains('قاصد خير') && qText.contains('السبب التاريخي')) {
      q['Q'] = 'ما سبب إعادة تصوير مسلسل قاصد خير بعد إنتاجه الأول عام 1990؟';
      q['R'] = 'فقدان أشرطته بالغزو';
      q['W1'] = 'احتراق استوديو المونتاج';
      q['W2'] = 'خلاف مالي حاد';
      q['W3'] = 'اعتذار بطل العمل';
    }
    if (qText.contains('النسخة الأصلية المفقودة لمسلسل قاصد خير')) {
      q['Q'] = 'من بطل النسخة الأصلية المفقودة لمسلسل قاصد خير التي صُورت قبل الغزو؟';
      q['R'] = 'غانم الصالح';
      q['W1'] = 'خالد النفيسي';
      q['W2'] = 'أحمد الصالح';
      q['W3'] = 'محمد المنصور';
    }
    if (qText.contains('الحيالة') && qText.contains('دكان ومحل الأعشاب')) {
      q['Q'] = 'ما اسم محل الأعشاب الذي افتتحه دواس في الحيالة للطب البديل؟';
      q['R'] = 'دكان دواس للتداوي';
      q['W1'] = 'مؤسسة علف';
      q['W2'] = 'صيدلية الحيالة';
      q['W3'] = 'عطارة المرقاب';
    }
    if (qText.contains('كف ودفوف') && qText.contains('فرقة الطقاقات')) {
      q['R'] = 'فرقة أم سامي';
      q['W1'] = 'فرقة الدانة';
      q['W2'] = 'فرقة نجد التراثية';
      q['W3'] = 'فرقة الرياحين';
    }
    if (qText.contains('العاصوف') && qText.contains('استوديو التصوير')) {
      q['Q'] = 'في أي إمارة تم بناء قرية استوديو التصوير المفتوح لمسلسل العاصوف؟';
      q['R'] = 'أبوظبي Twofour54';
      q['W1'] = 'دبي للإعلام';
      q['W2'] = 'عجمان التراثية';
      q['W3'] = 'الشارقة للإنتاج';
    }
    if (qText.contains('خيوط المعازيب') && qText.contains('مشغل وخياطة البشوت')) {
      q['Q'] = 'ما اسم مشغل خياطة البشوت للمعزب أبو عيسى في خيوط المعازيب؟';
      q['R'] = 'مشلح أبو عيسى';
      q['W1'] = 'مصنع الأحساء';
      q['W2'] = 'دار البشت الملكي';
      q['W3'] = 'خيوط الهفوف';
    }
    if (qText.contains('سوالف طفاش 3')) {
      q['Q'] = 'ما اسم النسخة والجزء الثالث من السلسلة البحرينية سوالف طفاش؟';
      q['R'] = 'جزيرة الهنود';
      q['W1'] = 'طفاش في باريس';
      q['W2'] = 'زمن الكورونا';
      q['W3'] = 'عودة طفاش الكبرى';
    }
    if (qText.contains('درب الزلق') && qText.contains('السهرة التلفزيونية')) {
      q['Q'] = 'ما اسم السهرة التلفزيونية الكوميدية التي سبقت درب الزلق عام 1975؟';
      q['R'] = 'شباب يعترض';
      q['W1'] = 'شروة ميت';
      q['W2'] = 'مجنون بأثر رجعي';
      q['W3'] = 'حبابة';
    }
  }

  // Also general pass to convert common 4-word patterns:
  // e.g. "عبد الحسين عبد الرضا" -> "عبدالحسين عبدالرضا"
  // "عبد الكريم عبد القادر" -> "عبدالكريم عبدالقادر"
  void cleanupStrings(Map<String, dynamic> q) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString();
      s = s.replaceAll('عبد الحسين', 'عبدالحسين');
      s = s.replaceAll('عبد الرضا', 'عبدالرضا');
      s = s.replaceAll('عبد الكريم', 'عبدالكريم');
      s = s.replaceAll('عبد القادر', 'عبدالقادر');
      s = s.replaceAll('عبد العزيز', 'عبدالعزيز');
      s = s.replaceAll('عبد اللطيف', 'عبداللطيف');
      s = s.replaceAll('عبد الرحمن', 'عبدالرحمن');
      s = s.replaceAll('عبد الله', 'عبدالله');
      s = s.replaceAll('عبد الإمام', 'عبدالإمام');
      s = s.replaceAll('عبد القدوس', 'عبدالقدوس');
      s = s.replaceAll('علي بابا', 'علي‌بابا');
      q[key] = s;
    }
  }

  for (var q in egyptList) {
    fixEgyptian(q);
    cleanupStrings(q);
  }

  for (var q in khaleejiList) {
    fixKhaleeji(q);
    cleanupStrings(q);
  }

  egyptFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(egyptList));
  khaleejiFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(khaleejiList));

  // Sync to main questions.json
  int egIdx = 0, khIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'دراما مصرية') {
      if (egIdx < egyptList.length) {
        mainList[i] = egyptList[egIdx++];
      }
    } else if (mainList[i]['Category'] == 'دراما خليجية') {
      if (khIdx < khaleejiList.length) {
        mainList[i] = khaleejiList[khIdx++];
      }
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Egypt & Khaleeji updated and synced!');
}
