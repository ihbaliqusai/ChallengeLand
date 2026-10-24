import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

String removeParentheses(String text) {
  return text.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
}

void main() {
  final file = File('assets/questions.json');
  final list = jsonDecode(file.readAsStringSync()) as List;

  final newCategories = [
    'دوري أبطال أوروبا',
    'NBA',
    'دراما سورية',
    'دراما مصرية',
    'دراما خليجية',
    'مسلسلات تركية',
    'باب الحارة',
    'Pokémon',
    'Game Of Thrones',
    'Hunter × Hunter',
    'Naruto',
    'Harry Potter',
    'One Piece',
    'Attack on Titan',
    'Demon Slayer',
    'Breaking Bad',
  ];

  print('Category | Total Long (>3 words) | Long after removing parentheses');
  print('---|---|---');

  for (var cat in newCategories) {
    final catQuestions = list.where((item) => item['Category'] == cat).toList();
    int initialLong = 0;
    int afterParenLong = 0;

    for (var q in catQuestions) {
      final r = q['R']?.toString() ?? '';
      final w1 = q['W1']?.toString() ?? '';
      final w2 = q['W2']?.toString() ?? '';
      final w3 = q['W3']?.toString() ?? '';

      final maxW = [countWords(r), countWords(w1), countWords(w2), countWords(w3)].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) initialLong++;

      final rClean = removeParentheses(r);
      final w1Clean = removeParentheses(w1);
      final w2Clean = removeParentheses(w2);
      final w3Clean = removeParentheses(w3);

      final maxWClean = [countWords(rClean), countWords(w1Clean), countWords(w2Clean), countWords(w3Clean)].reduce((a, b) => a > b ? a : b);
      if (maxWClean > 3) afterParenLong++;
    }

    print('$cat | $initialLong | $afterParenLong');
  }
}
