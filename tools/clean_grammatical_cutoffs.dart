import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final files = [
    'assets/questions_ucl_300.json',
    'assets/questions_nba_300.json',
    'assets/questions_syrian_drama_300.json',
    'assets/questions_egyptian_drama_300.json',
    'assets/questions_khaleeji_drama_300.json',
    'assets/questions_turkish_series_300.json',
    'assets/questions_bab_alhara_300.json',
    'assets/questions_pokemon_300.json',
    'assets/questions_game_of_thrones_300.json',
    'assets/questions_breaking_bad_300.json',
    'assets/questions_harry_potter_300.json',
    'assets/questions_demon_slayer_300.json',
    'assets/questions_hunter_hunter_300.json',
    'assets/questions_one_piece_300.json',
    'assets/questions_attack_on_titan_300.json',
    'assets/questions_naruto_300.json',
  ];

  final mainFile = File('assets/questions.json');
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  final trailingIncomplete = {'من', 'في', 'إلى', 'على', 'عن', 'مع', 'أو', 'أن', 'لا', 'هو', 'هي', 'بـ', 'لـ'};

  for (final path in files) {
    final file = File(path);
    final List<dynamic> list = jsonDecode(file.readAsStringSync());

    for (var q in list) {
      final qText = (q['Q'] ?? '').toString();

      // Fix Kite slots specifically
      if (qText.contains('كايت في كل مرة يسحب فيها سلاحاً')) {
        q['R'] = 'سحبة سيئة ثانية!';
        q['W1'] = 'هذا سلاحي المفضل!';
        q['W2'] = 'استعد للموت الآن!';
        q['W3'] = 'سلاح غير مناسب!';
      }
      // Fix Chimera Queen
      if (qText.contains('ملكة نمل الكيميرا العملاقة إلى شواطئ')) {
        q['R'] = 'من القارة المظلمة';
        q['W1'] = 'من جزيرة الجشع';
        q['W2'] = 'من خندق ماريانا';
        q['W3'] = 'من كوكب فضائي';
      }

      for (final key in ['R', 'W1', 'W2', 'W3']) {
        var val = (q[key] ?? '').toString().trim();

        // 1. Remove lone leading or trailing quotes
        if (val.startsWith("'") || val.startsWith('"') || val.startsWith('«')) {
          val = val.substring(1).trim();
        }
        if (val.endsWith("'") || val.endsWith('"') || val.endsWith('»')) {
          val = val.substring(0, val.length - 1).trim();
        }

        // 2. Fix trailing prepositions
        var words = val.split(RegExp(r'\s+'));
        while (words.isNotEmpty && trailingIncomplete.contains(words.last)) {
          words.removeLast();
        }
        val = words.join(' ').trim();

        // 3. Remove leading prepositions if it makes it cleaner
        q[key] = val;
      }
    }

    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));

    // Update in main questions.json
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
  print('Cleaned all grammatical cutoffs and quotes across all 16 categories!');
}
