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
  final babFile = File('assets/questions_bab_alhara_300.json');
  final narutoFile = File('assets/questions_naruto_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> babList = jsonDecode(babFile.readAsStringSync());
  final List<dynamic> narutoList = jsonDecode(narutoFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  // 1. Bab Al-Hara
  for (var q in babList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('زوج دلال ابنة الحكيم الوسطى')) {
      q['R'] = 'إبراهيم';
    }
    if (qText.contains('العاهة أو المرض الذي أصاب يد الإدعشري')) {
      q['R'] = 'غرغرينا من عضة';
      q['W1'] = 'حرق ناري شديد';
      q['W2'] = 'كسر مضاعف بالعظم';
      q['W3'] = 'شلل نصفي مفاجئ';
    }
    if (qText.contains('أين قام الإدعشري بدفن أكياس الذهب')) {
      q['R'] = 'بأرض ديار بيته';
      q['W1'] = 'تحت بلاط الجامع';
      q['W2'] = 'داخل مغارة الجبل';
      q['W3'] = 'بئر حارة النار';
    }
    if (qText.contains('تولى زعامة حارة الضبع بعد وفاة الزعيم أبو صالح')) {
      q['R'] = 'أبو عصام بالتوافق';
      q['W1'] = 'أبو النار بالقوة';
      q['W2'] = 'أبو جودت بالتعيين';
      q['W3'] = 'أبو غالب بالحيلة';
    }
    if (qText.contains('ماذا كان يعمل سعيد زوج بوران')) {
      q['R'] = 'تاجر أقمشة بالخان';
      q['W1'] = 'صانع أحذية جلدية';
      q['W2'] = 'بائع بهارات وتوابل';
      q['W3'] = 'كاتب عرائض بالمحكمة';
    }
    if (qText.contains('قتل مأمون بيك كاشفاً خيانته')) {
      q['R'] = 'أبو دياب';
      q['W1'] = 'أبو جودت بالمخفر';
      q['W2'] = 'أبو بدر دفاعاً';
      q['W3'] = 'أبو غالب بحارته';
    }
    if (qText.contains('دكان الأقمشة الذي اشتراه مأمون بيك')) {
      q['R'] = 'دكان بسوق الحميدية';
      q['W1'] = 'محل صرافة بالشاغور';
      q['W2'] = 'خان الحرير بحلب';
      q['W3'] = 'مستودع بباب توما';
    }
    if (qText.contains('القرابة بين معتز والعقيد أبي شهاب')) {
      q['R'] = 'أبو شهاب خاله';
      q['W1'] = 'أبو شهاب عمه';
      q['W2'] = 'أبو شهاب صهره';
      q['W3'] = 'أبو شهاب ابن‌خاله';
    }
  }

  // 2. Naruto
  for (var q in narutoList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('الحلم الأكبر والهدف الأساسي الذي كرّس ناروتو حياته لتحقيقه')) {
      q['R'] = 'أن يصبح الهوكاغي';
      q['W1'] = 'أن يصبح أغنى تاجر';
      q['W2'] = 'الانتقام من الأوتشيها';
      q['W3'] = 'جمع وحوش البيجو';
    }
    if (qText.contains('الوحش الأسطوري الكارثي المختوم داخل جسد ناروتو')) {
      q['R'] = 'ثعلب الذيول التسعة';
      q['W1'] = 'قط ذو ذيلين';
      q['W2'] = 'ثور ثمانية ذيول';
      q['W3'] = 'راكون ذيل واحد';
    }
    if (qText.contains('زميلا ناروتو أوزوماكي في الفريق السابع')) {
      q['R'] = 'ساسكي وساكورا';
      q['W1'] = 'شيكامارو وإينو';
      q['W2'] = 'نيجي وتين تين';
      q['W3'] = 'كيبا وهيناتا';
    }
    if (qText.contains('الطعام المفضل والمحبب جداً لناروتو')) {
      q['R'] = 'حساء الرامن';
      q['W1'] = 'كرات الأرز المشوية';
      q['W2'] = 'حلوى الدانغو الحلوة';
      q['W3'] = 'لحوم البقر المشوية';
    }
    if (qText.contains('أول تقنية محرمة مميزة سرق لفافتها ناروتو')) {
      q['R'] = 'نسخ الظل المتعددة';
      q['W1'] = 'تقنية الاستدعاء العكسي';
      q['W2'] = 'كرة النار العملاقة';
      q['W3'] = 'استبدال الجسد بالخشب';
    }
    if (qText.contains('صلة القرابة الحقيقية والبيولوجية بين الهوكاغي الرابع')) {
      q['R'] = 'ميناتو والده الحقيقي';
      q['W1'] = 'ميناتو هو عمه';
      q['W2'] = 'ميناتو شقيقه بالتبني';
      q['W3'] = 'لا تربطهما أي قرابة';
    }
    if (qText.contains('الكائنات الحية التي تعيش داخل جسد شينو أبورامي')) {
      q['R'] = 'حشرات الكيكاي الطفيلية';
      q['W1'] = 'العناكب السامة المشعة';
      q['W2'] = 'الديدان الأرضية العريضة';
      q['W3'] = 'الضفادع المجهرية المائية';
    }
  }

  // General pass: ensure all options <= 3 words:
  for (var q in babList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  for (var q in narutoList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  babFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(babList));
  narutoFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(narutoList));

  // Sync to main
  int bIdx = 0, nIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'باب الحارة') {
      if (bIdx < babList.length) mainList[i] = babList[bIdx++];
    } else if (mainList[i]['Category'] == 'Naruto') {
      if (nIdx < narutoList.length) mainList[i] = narutoList[nIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Bab Al-Hara & Naruto updated and synced!');
}
