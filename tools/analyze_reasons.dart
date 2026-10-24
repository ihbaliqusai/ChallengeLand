import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String cleanAnswer(String ans) {
  var s = ans.trim();
  // Strip trailing or internal parenthesis containing english/notes e.g. (Totsuka Blade), (Season 1)
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  // Strip slash notes e.g. " / Love" or "/ ..."
  s = s.replaceAll(RegExp(r'\s*/\s*.*$'), '');
  // Strip quotes
  s = s.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
  return s.trim();
}

void main() {
  final file = File('assets/questions.json');
  final List<dynamic> allQuestions = jsonDecode(file.readAsStringSync());

  final targetCats = [
    'NBA',
    'دراما سورية',
    'دراما مصرية',
    'دراما خليجية',
    'مسلسلات تركية',
    'باب الحارة',
    'Pokémon',
    'Game Of Thrones',
    'Breaking Bad',
    'Harry Potter',
    'Demon Slayer',
    'Hunter × Hunter',
    'One Piece',
    'Attack on Titan',
    'Naruto',
  ];

  for (final cat in targetCats) {
    final catQuestions = allQuestions.where((q) => (q['Category'] ?? q['category']) == cat).toList();
    int before = 0;
    int after = 0;
    for (final q in catQuestions) {
      final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
      if (opts.any((o) => countWords(o) > 3)) {
        before++;
      }
      final cleanedOpts = opts.map((o) => cleanAnswer(o.toString())).toList();
      if (cleanedOpts.any((o) => countWords(o) > 3)) {
        after++;
      }
    }
    print('${cat.padRight(20)}: before = $before, after simple paren/slash cleaning = $after (reduced by ${before - after})');
  }
}
