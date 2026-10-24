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
  final bbFile = File('assets/questions_breaking_bad_300.json');
  final dsFile = File('assets/questions_demon_slayer_300.json');
  final aotFile = File('assets/questions_attack_on_titan_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> bbList = jsonDecode(bbFile.readAsStringSync());
  final List<dynamic> dsList = jsonDecode(dsFile.readAsStringSync());
  final List<dynamic> aotList = jsonDecode(aotFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  // 1. Breaking Bad
  for (var q in bbList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('مهنة والتر وايت الأساسية')) {
      q['R'] = 'معلم كيمياء ثانوية';
      q['W1'] = 'ضابط بمكافحة المخدرات';
      q['W2'] = 'محامي دفاع جنائي';
      q['W3'] = 'طبيب أورام سرطانية';
    }
    if (qText.contains('المرض الخطير الذي شُخّص به والتر وايت')) {
      q['R'] = 'سرطان الرئة المتقدم';
      q['W1'] = 'سرطان الدم الحاد';
      q['W2'] = 'فشل كلوي مزمن';
      q['W3'] = 'ورم بالدماغ';
    }
    if (qText.contains('اللون المميز والنقاء الاستثنائي')) {
      q['R'] = 'الميث الأزرق';
      q['W1'] = 'الميث الأبيض';
      q['W2'] = 'البلورات الوردية';
      q['W3'] = 'البلورات الخضراء';
    }
    if (qText.contains('الشعار الدعائي الأيقوني للمحامي سول غودمان')) {
      q['R'] = 'اتصل بسول!';
      q['W1'] = 'العدالة للجميع';
      q['W2'] = 'محاميك حتى البراءة';
      q['W3'] = 'لا تحدث الشرطة';
    }
    if (qText.contains('هيكتور سالامانكا المقعد')) {
      q['R'] = 'بقرع جرس كرسيه';
      q['W1'] = 'بالكتابة على لوح';
      q['W2'] = 'بإشارات اليد';
      q['W3'] = 'بهز رأسه بالإيجاب';
    }
  }

  // 2. Demon Slayer
  for (var q in dsList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('يضع تانجيرو شقيقته نيزوكو')) {
      q['R'] = 'بصندوق خشبي بظهره';
      q['W1'] = 'داخل حقيبة قماشية';
      q['W2'] = 'في عربة مغلقة';
      q['W3'] = 'تحت مظلة حديدية';
    }
    if (qText.contains('القناع الغريب الذي يرتديه المحارب الشرس عاري الصدر إينوسوكي')) {
      q['R'] = 'قناع رأس خنزير';
      q['W1'] = 'قناع ذئب أبيض';
      q['W2'] = 'قناع دب قطبي';
      q['W3'] = 'قناع نمر مرقط';
    }
    if (qText.contains('عدد سيوف النيتشيرين التي يحملها ويقاتل بها إينوسوكي')) {
      q['R'] = 'سيفان مسننان';
      q['W1'] = 'سيف واحد فقط';
      q['W2'] = 'ثلاثة سيوف';
      q['W3'] = 'أربعة خناجر';
    }
    if (qText.contains('الحاسة الخارقة الاستثنائية التي وُلد بها تانجيرو')) {
      q['R'] = 'حاسة الشم الخارقة';
      q['W1'] = 'حاسة السمع الخارق';
      q['W2'] = 'حاسة اللمس الفائق';
      q['W3'] = 'حدة البصر التلسكوبي';
    }
  }

  // 3. Attack on Titan
  for (var q in aotList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    // عتاد المناورة ثلاثي الأبعاد -> عتاد المناورة
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString();
      s = s.replaceAll('عتاد المناورة ثلاثي الأبعاد', 'عتاد المناورة');
      s = s.replaceAll('عتاد المناورة ثلاثية الأبعاد', 'عتاد المناورة');
      q[key] = s;
    }

    if (qText.contains('عتاد المناورة ثلاثي الأبعاد')) {
      q['R'] = 'عتاد المناورة';
    }
    if (qText.contains('الدفعة التدريبية العسكرية التي تخرج منها إيرين')) {
      q['R'] = 'الدفعة 104';
      q['W1'] = 'الدفعة 100';
      q['W2'] = 'الدفعة 105';
      q['W3'] = 'الدفعة 99';
    }
    if (qText.contains('الغاز المضغوط الذي يزود عتاد المناورة')) {
      q['R'] = 'غاز الخيزران الجليدي';
      q['W1'] = 'غاز الأكسجين السائل';
      q['W2'] = 'بخار الماء المغلي';
      q['W3'] = 'غاز الهيليوم المتطاير';
    }
    if (qText.contains('هدف العمالقة النقيين العاديين الأساسي')) {
      q['R'] = 'التهامهم بدافع غريزي';
      q['W1'] = 'امتصاص دمائهم واستعبادهم';
      q['W2'] = 'بناء قلاع صخرية';
      q['W3'] = 'سرقة عتاد المناورة';
    }
  }

  // General pass to enforce <= 3 words on all 3 categories:
  for (var q in bbList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  for (var q in dsList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  for (var q in aotList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  bbFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(bbList));
  dsFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(dsList));
  aotFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(aotList));

  // Sync to main
  int bbIdx = 0, dsIdx = 0, aotIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'Breaking Bad') {
      if (bbIdx < bbList.length) mainList[i] = bbList[bbIdx++];
    } else if (mainList[i]['Category'] == 'Demon Slayer') {
      if (dsIdx < dsList.length) mainList[i] = dsList[dsIdx++];
    } else if (mainList[i]['Category'] == 'Attack on Titan') {
      if (aotIdx < aotList.length) mainList[i] = aotList[aotIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Breaking Bad, Demon Slayer, and Attack on Titan updated and synced!');
}
