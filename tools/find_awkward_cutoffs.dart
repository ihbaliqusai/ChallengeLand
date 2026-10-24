import 'dart:convert';
import 'dart:io';

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

  final trailingIncomplete = ['من', 'في', 'إلى', 'على', 'عن', 'مع', 'أو', 'أن', 'لا', 'هو', 'هي'];

  print('=== Searching for incomplete/awkward answers ===');
  for (final path in files) {
    final file = File(path);
    final List<dynamic> list = jsonDecode(file.readAsStringSync());
    for (int i = 0; i < list.length; i++) {
      final q = list[i];
      for (final key in ['R', 'W1', 'W2', 'W3']) {
        final val = (q[key] ?? '').toString().trim();
        // check unclosed quotes
        final singleQuotes = val.split("'").length - 1;
        final doubleQuotes = val.split('"').length - 1;
        if (singleQuotes % 2 != 0 || doubleQuotes % 2 != 0) {
          print('Unclosed quote in $path [$i] $key: "$val" (Q: ${q['Q']})');
        }
        // check trailing preposition
        final words = val.split(RegExp(r'\s+'));
        if (words.isNotEmpty && trailingIncomplete.contains(words.last)) {
          print('Trailing incomplete in $path [$i] $key: "$val" (Q: ${q['Q']})');
        }
      }
    }
  }
}
