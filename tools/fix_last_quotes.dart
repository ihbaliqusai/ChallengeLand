import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final files = [
    'assets/questions_hunter_hunter_300.json',
    'assets/questions_one_piece_300.json',
    'assets/questions_naruto_300.json',
    'assets/questions_attack_on_titan_300.json',
    'assets/questions_demon_slayer_300.json',
    'assets/questions_breaking_bad_300.json',
    'assets/questions_harry_potter_300.json',
    'assets/questions_game_of_thrones_300.json',
    'assets/questions_turkish_series_300.json',
    'assets/questions_bab_alhara_300.json',
  ];

  final mainFile = File('assets/questions.json');
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  for (final path in files) {
    final file = File(path);
    final List<dynamic> list = jsonDecode(file.readAsStringSync());

    for (var q in list) {
      final qText = (q['Q'] ?? '').toString();

      // HxH Razor
      if (qText.contains('أنهى هيسوكا مباراة كرة المراوغة')) {
        q['R'] = 'علكة البانجي';
      }
      // HxH Greed Island healing
      if (qText.contains('استعاد غون وكيلوا جسديهما وأطرافهما السليمة بعد انتهاء المعارك في Greed Island')) {
        q['R'] = 'بطاقة أنفاس الملاك';
      }
      // HxH Welfin
      if (qText.contains('الذئب ويلفين (Welfin) أمام الملك ميريوم')) {
        q['Q'] = 'ما الكلمة التي نطقها الذئب ويلفين أمام ميريوم وأنقذت حياته وأعادت ذكريات الملك؟';
        q['R'] = 'كوموغي!';
        q['W1'] = 'نيفيربيتو!';
        q['W2'] = 'القنبلة!';
        q['W3'] = 'بوف!';
      }
      // HxH Ging meeting place
      if (qText.contains('أين حدد جينغ مكان لقائه الفردي الخاص مع غون')) {
        q['R'] = 'قمة شجرة العالم';
      }
      // HxH Hisoka resurrection
      if (qText.contains('كيف عاد هيسوكا إلى الحياة بعد موته')) {
        q['R'] = 'النين بعد الموت';
      }
      // OP Zoro breath
      if (qText.contains('حققه زورو في نزاله ضد مستر 1')) {
        q['R'] = 'قطع الفولاذ';
      }
      // OP Rayleigh awakening Luffy
      if (qText.contains('كيف أيقظ سيلفرز رايلي وعي لوفي المنهار')) {
        q['Q'] = 'بماذا ذكّر سيلفرز رايلي لوفي المنهار ليعيد إليه الأمل بعد حرب المارينفورد؟';
        q['R'] = 'برفاقه في الطاقم';
        q['W1'] = 'بحلم ملك القراصنة';
        q['W2'] = 'بقبعة القش الثمينة';
        q['W3'] = 'بوالده دراغون الثوري';
      }

      // Remove single quotes from inside answers if not an apostrophe in English
      for (final key in ['R', 'W1', 'W2', 'W3']) {
        var s = (q[key] ?? '').toString().trim();
        // If has arabic and single quote, remove the quote
        if (RegExp(r'[\u0600-\u06FF]').hasMatch(s)) {
          s = s.replaceAll("'", '').replaceAll('"', '').trim();
        }
        q[key] = s;
      }
    }

    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));

    final catName = list.first['Category'];
    int catIdx = 0;
    for (int i = 0; i < mainList.length; i++) {
      if (mainList[i]['Category'] == catName) {
        if (catIdx < list.length) {
          mainList[i] = list[catIdx++];
        }
      }
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Fixed all last quotes and synchronized!');
}
