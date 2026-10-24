import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

String cleanAnswer(String text) {
  var s = text.trim();
  // 1. Remove quotes around
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }
  // 2. Remove parenthetical remarks: (....)
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  // 3. Remove English slash alternative: e.g. "حب / Love"
  if (s.contains('/')) {
    s = s.split('/')[0].trim();
  }
  // 4. Remove ellipsis or trailing punctuation
  s = s.replaceAll(RegExp(r'[.!؟:;]+$'), '').trim();
  return s;
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
    'Breaking Bad',
    'Harry Potter',
    'Demon Slayer',
    'Hunter × Hunter',
    'One Piece',
    'Attack on Titan',
    'Naruto',
  ];

  int totalRemaining = 0;
  print('Category | Total | Remained > 3 words after base cleaning');
  print('---|---|---');

  for (var cat in newCategories) {
    final catQuestions = list.where((item) => item['Category'] == cat).toList();
    int rem = 0;
    for (var q in catQuestions) {
      final r = cleanAnswer(q['R']?.toString() ?? '');
      final w1 = cleanAnswer(q['W1']?.toString() ?? '');
      final w2 = cleanAnswer(q['W2']?.toString() ?? '');
      final w3 = cleanAnswer(q['W3']?.toString() ?? '');

      final maxW = [countWords(r), countWords(w1), countWords(w2), countWords(w3)].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) rem++;
    }
    totalRemaining += rem;
    print('$cat | ${catQuestions.length} | $rem');
  }

  print('\nTotal remaining needing custom rephrasing: $totalRemaining');
}
