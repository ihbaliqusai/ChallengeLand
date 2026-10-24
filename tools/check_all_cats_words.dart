import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final targetCats = [
    'دوري أبطال أوروبا',
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

  final file = File('assets/questions.json');
  final List<dynamic> allQuestions = jsonDecode(file.readAsStringSync());
  print('Total questions in assets/questions.json: ${allQuestions.length}');

  int grandTotalLong = 0;

  for (final cat in targetCats) {
    final catQuestions = allQuestions.where((q) => (q['Category'] ?? q['category']) == cat).toList();
    int longCount = 0;
    for (final q in catQuestions) {
      final rW = countWords(q['R'] ?? '');
      final w1W = countWords(q['W1'] ?? '');
      final w2W = countWords(q['W2'] ?? '');
      final w3W = countWords(q['W3'] ?? '');
      final maxW = [rW, w1W, w2W, w3W].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) {
        longCount++;
      }
    }
    grandTotalLong += longCount;
    print('${cat.padRight(20)}: ${catQuestions.length} total, $longCount long (>3 words)');
  }
  print('-----------------------------------------');
  print('Grand Total Long Questions in 16 categories: $grandTotalLong');
}


