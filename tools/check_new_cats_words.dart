import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

void main() {
  final file = File('assets/questions.json');
  final list = jsonDecode(file.readAsStringSync()) as List;

  final newCategories = [
    'دوري أبطال أوروبا',
    'NBA',
    'بنات',
    'باب الحارة',
    'مسلسلات تركية',
    'دراما خليجية',
    'دراما سورية',
    'دراما مصرية',
    'Game Of Thrones',
    'Breaking Bad',
    'Harry Potter',
    'Pokémon',
    'Demon Slayer',
    'Hunter × Hunter',
    'One Piece',
    'Attack on Titan',
    'Naruto',
  ];

  print('=== Summary of answers > 3 words in new categories ===\n');

  for (var cat in newCategories) {
    final catQuestions = list.where((item) => item['Category'] == cat).toList();
    int longCount = 0;
    int maxWordsOverall = 0;

    for (var q in catQuestions) {
      final r = q['R']?.toString() ?? '';
      final w1 = q['W1']?.toString() ?? '';
      final w2 = q['W2']?.toString() ?? '';
      final w3 = q['W3']?.toString() ?? '';

      final rWords = countWords(r);
      final w1Words = countWords(w1);
      final w2Words = countWords(w2);
      final w3Words = countWords(w3);

      final maxW = [rWords, w1Words, w2Words, w3Words].reduce((a, b) => a > b ? a : b);
      if (maxW > maxWordsOverall) maxWordsOverall = maxW;
      if (maxW > 3) {
        longCount++;
      }
    }

    print('$cat: $longCount / ${catQuestions.length} questions have answers > 3 words (Max words in an answer: $maxWordsOverall)');
  }
}
