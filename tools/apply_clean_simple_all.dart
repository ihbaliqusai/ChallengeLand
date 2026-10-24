import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String cleanSimple(String s) {
  var t = s.trim();
  // Strip trailing or internal parenthesis containing english/notes e.g. (Totsuka Blade), (Season 1)
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  // Strip slash notes e.g. " / Love" or "/ ..."
  t = t.replaceAll(RegExp(r'\s*/\s*.*$'), '');
  // Strip quotes
  t = t.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
  return t.trim();
}

void main() {
  final remFiles = [
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

  for (final path in remFiles) {
    final file = File(path);
    final List<dynamic> list = jsonDecode(file.readAsStringSync());
    for (var q in list) {
      q['R'] = cleanSimple(q['R'] ?? '');
      q['W1'] = cleanSimple(q['W1'] ?? '');
      q['W2'] = cleanSimple(q['W2'] ?? '');
      q['W3'] = cleanSimple(q['W3'] ?? '');
    }
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));

    // Also update main list for matching questions
    final catName = list.first['Category'];
    print('Cleaned $catName in standalone file: $path');
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
  print('Synced cleanSimple across all remaining categories to assets/questions.json!');
}
