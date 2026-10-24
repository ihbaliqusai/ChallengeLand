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
  final opFile = File('assets/questions_one_piece_300.json');
  final hxhFile = File('assets/questions_hunter_hunter_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> opList = jsonDecode(opFile.readAsStringSync());
  final List<dynamic> hxhList = jsonDecode(hxhFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  // 1. One Piece specific handling
  for (var q in opList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    // Remove " نو مي" from devil fruit answers
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString();
      s = s.replaceAll(' نو مي', '');
      s = s.replaceAll('فاكهة الـ ', 'فاكهة ');
      s = s.replaceAll('فاكهة ', ''); // Just fruit name e.g. غومو غومو
      q[key] = s;
    }

    if (qText.contains('الحلم الأكبر والهدف الأساسي لمونكي دي لوفي')) {
      q['R'] = 'أن يصبح ملك القراصنة';
      q['W1'] = 'أن يصبح أميرالاً بالبحرية';
      q['W2'] = 'رسم خريطة بحار العالم';
      q['W3'] = 'أن يصبح أعظم سياف';
    }
    if (qText.contains('حلم سانجي الأسطوري')) {
      q['R'] = 'البحر الأزرق الكامل';
      q['W1'] = 'أقوى ملاكم بالعالم';
      q['W2'] = 'تأليف كتاب الوصفات';
      q['W3'] = 'شراء مطعم باراتي';
    }
    if (qText.contains('النقيصة أو اللعنة الأبدية المشتركة')) {
      q['R'] = 'فقدان القدرة على السباحة';
      q['W1'] = 'فقدان القدرة على النطق';
      q['W2'] = 'قصر العمر الافتراضي';
      q['W3'] = 'عدم تناول اللحوم';
    }
    if (qText.contains('التقى لوفي بزورو لأول مرة في مدينة شيلز تاون')) {
      q['Q'] = 'كيف وجد لوفي زورو لأول مرة في قاعدة البحرية بشيلز تاون؟';
      q['R'] = 'مقيداً إلى صليب خشبي';
      q['W1'] = 'مسجوناً في زنزانة مظلمة';
      q['W2'] = 'مبارزاً في حانة المدينة';
      q['W3'] = 'نائماً في قارب صغير';
    }
    if (qText.contains('الكابتن مورغان ذو اليد الفأس')) {
      q['R'] = 'الكابتن مورغان';
    }
  }

  // 2. Hunter x Hunter specific handling
  for (var q in hxhList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('دفع غون لمغادرة جزيرة الحوت')) {
      q['R'] = 'البحث عن والده جينغ';
      q['W1'] = 'الانتقام لمقتل عائلته';
      q['W2'] = 'شراء جزيرة الحوت';
      q['W3'] = 'أن يصبح أقوى مقاتل';
    }
    if (qText.contains('قبيلة كوروتا')) {
      q['R'] = 'تحول عيونهم للون القرمزي';
      q['W1'] = 'أجنحة خفية من النين';
      q['W2'] = 'قراءة الأفكار باللمس';
      q['W3'] = 'المناعة الكاملة ضد السموم';
    }
    if (qText.contains('الدافع الحقيقي لليوريو بارادينايت')) {
      q['R'] = 'أن يصبح طبيباً للفقراء';
      q['W1'] = 'شراء قصر فخم بالبحر';
      q['W2'] = 'تأسيس شركة أدوية احتكارية';
      q['W3'] = 'دفع فدية لتحرير عائلته';
    }
    if (qText.contains('صنارة الصيد الخاصة بوالده')) {
      q['R'] = 'صنارة صيد والده';
    }
    if (qText.contains('تومبا تقديمه لغون وكيلوا')) {
      q['R'] = 'عصير ممزوج بمسهل ومخدر';
    }
    if (qText.contains('لماذا لم يتأثر كيلوا على الإطلاق بالعصير المسموم')) {
      q['Q'] = 'لماذا لم يتأثر كيلوا بالعصير المسموم الذي قدمه تومبا؟';
      q['R'] = 'تدربه على مقاومة السموم';
      q['W1'] = 'استخدامه لتقنية النين';
      q['W2'] = 'نسيان تومبا وضع السم';
      q['W3'] = 'شربه للترياق مسبقاً';
    }
    if (qText.contains('فئة \'التعزيز\'') || qText.contains('فئة التعزيز')) {
      q['R'] = 'يفيض الماء خارج الكأس';
      q['W1'] = 'يتغير طعم الماء للحلول';
      q['W2'] = 'تتحرك ورقة الشجر بالسطح';
      q['W3'] = 'تظهر رواسب بقاع الكأس';
    }
  }

  // General pass for both: safely trim any options > 3 words:
  for (var q in opList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  for (var q in hxhList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  opFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(opList));
  hxhFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(hxhList));

  // Sync to main
  int opIdx = 0, hxhIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'One Piece') {
      if (opIdx < opList.length) mainList[i] = opList[opIdx++];
    } else if (mainList[i]['Category'] == 'Hunter × Hunter') {
      if (hxhIdx < hxhList.length) mainList[i] = hxhList[hxhIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('One Piece & Hunter x Hunter updated and synced!');
}
