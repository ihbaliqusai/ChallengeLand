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

  print('=== Standalone Files Verification ===');
  int grandLong = 0;
  for (final path in files) {
    final file = File(path);
    final List<dynamic> list = jsonDecode(file.readAsStringSync());
    int longCount = 0;
    for (final q in list) {
      final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
      if (opts.any((o) => countWords(o.toString()) > 3)) {
        longCount++;
      }
    }
    grandLong += longCount;
    print('${file.uri.pathSegments.last.padRight(40)}: ${list.length} total, $longCount long (>3 words)');
  }
  print('----------------------------------------------------');
  print('Grand Total Long in all standalone files: $grandLong');
}
