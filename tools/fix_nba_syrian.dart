import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final mainFile = File('assets/questions.json');
  final List<dynamic> allQuestions = jsonDecode(mainFile.readAsStringSync());

  final nbaFile = File('assets/questions_nba_300.json');
  final List<dynamic> nbaQuestions = jsonDecode(nbaFile.readAsStringSync());

  final syrianFile = File('assets/questions_syrian_drama_300.json');
  final List<dynamic> syrianQuestions = jsonDecode(syrianFile.readAsStringSync());

  // Fix NBA:
  // 1. Larry Bird quote
  void fixNBA(dynamic q) {
    if ((q['Q'] as String).contains('لاري بيرد عن مايكل جوردن')) {
      q['Q'] = 'من اللاعب الذي وصفه لاري بيرد عام 1986 بقوله: "إنه الإله متنكراً"؟';
      q['R'] = 'مايكل جوردن';
      q['W1'] = 'ماجيك جونسون';
      q['W2'] = 'كريم عبد الجبار';
      q['W3'] = 'تشارلز باركلي';
    }
    // 2. Shaq free throws
    if ((q['Q'] as String).contains('شاكيل أونيل في مسيرته بالمقارنة مع معاناته')) {
      q['Q'] = 'كم عدد الرميات الحرة التي أهدرها شاكيل أونيل تقريباً في مسيرته؟';
      q['R'] = 'أكثر من 5000';
      q['W1'] = 'أكثر من 8000';
      q['W2'] = 'نحو 2000';
      q['W3'] = 'نحو 3000';
    }
    // 3. Quadruple double
    if ((q['Q'] as String).contains('رباعية مزدوجة (Quadruple-Double)')) {
      q['Q'] = 'كم لاعباً في تاريخ الـ NBA حقق رباعية مزدوجة أكثر من مرة؟';
      q['R'] = 'ولا لاعب';
      q['W1'] = 'لاعبان';
      q['W2'] = 'ثلاثة لاعبين';
      q['W3'] = 'أربعة لاعبين';
    }
  }

  // Fix Syrian Drama:
  void fixSyrian(dynamic q) {
    final qText = (q['Q'] ?? '').toString();
    final rText = (q['R'] ?? '').toString();
    if (qText.contains('حسني البورظان في مسلسل صح النوم') || rText.contains('إذا أردنا أن نعرف ماذا في إيطاليا')) {
      q['Q'] = 'من صاحب مقولة: "إذا أردنا أن نعرف ماذا في إيطاليا..." في صح النوم؟';
      q['R'] = 'حسني البورظان';
      q['W1'] = 'غوار الطوشة';
      q['W2'] = 'أبو عنتر';
      q['W3'] = 'أبو صياح';
    }
    if (qText.contains('أبو عنتر') || rText.contains('نذراً عليي وقاطع إيدي')) {
      q['Q'] = 'من صاحب عبارة "نذراً عليي وقاطع إيدي من هون لهون" في أعمال غوار؟';
      q['R'] = 'أبو عنتر';
      q['W1'] = 'أبو صياح';
      q['W2'] = 'بدري أبو كلبشة';
      q['W3'] = 'ياسينو';
    }
  }

  // Apply to standalone
  for (var q in nbaQuestions) fixNBA(q);
  for (var q in syrianQuestions) fixSyrian(q);

  nbaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(nbaQuestions));
  syrianFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(syrianQuestions));

  // Apply to main questions.json
  for (var q in allQuestions) {
    if (q['Category'] == 'NBA') fixNBA(q);
    if (q['Category'] == 'دراما سورية') fixSyrian(q);
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(allQuestions));
  print('NBA & Syrian Drama fixed successfully!');
}
