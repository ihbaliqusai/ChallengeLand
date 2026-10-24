import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

String cleanAnswer(String text) {
  var s = text.trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  if (s.contains('/')) {
    s = s.split('/')[0].trim();
  }
  s = s.replaceAll(RegExp(r'[.!؟:;]+$'), '').trim();

  // Strip common leading action/causal prepositions if it helps make it <= 3 words
  final prefixes = [
    'باستخدام ', 'عن طريق ', 'بواسطة ', 'من خلال ', 'بإطلاق ', 'بإلقاء ',
    'بقطع ', 'بطعن ', 'بحبس ', 'بضرب ', 'بقتل ', 'بزرع ', 'بتناول ', 'بشرب ',
    'بفضل ', 'بسبب ', 'لأنه ', 'لأنها ', 'عبر ', 'في ', 'من ', 'على '
  ];
  for (var p in prefixes) {
    if (s.startsWith(p)) {
      final stripped = s.substring(p.length).trim();
      if (countWords(stripped) <= 3 && countWords(stripped) > 0) {
        return stripped;
      }
    }
  }

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
  print('Category | Total | Remained > 3 words after prefix stripping');
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
