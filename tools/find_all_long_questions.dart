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

  final report = <String, List<Map<String, dynamic>>>{};
  int totalLongAcrossAll = 0;

  for (var cat in newCategories) {
    report[cat] = [];
    final catQuestions = list.where((item) => item['Category'] == cat).toList();
    for (int i = 0; i < catQuestions.length; i++) {
      final q = catQuestions[i];
      final r = q['R']?.toString() ?? '';
      final w1 = q['W1']?.toString() ?? '';
      final w2 = q['W2']?.toString() ?? '';
      final w3 = q['W3']?.toString() ?? '';

      final rW = countWords(r);
      final w1W = countWords(w1);
      final w2W = countWords(w2);
      final w3W = countWords(w3);
      final maxW = [rW, w1W, w2W, w3W].reduce((a, b) => a > b ? a : b);

      if (maxW > 3) {
        totalLongAcrossAll++;
        report[cat]!.add({
          'index': i,
          'Level': q['Level'],
          'Q': q['Q'],
          'R': r,
          'W1': w1,
          'W2': w2,
          'W3': w3,
          'rW': rW,
          'w1W': w1W,
          'w2W': w2W,
          'w3W': w3W,
          'maxW': maxW,
        });
      }
    }
  }

  print('Total long questions across all 16 categories: $totalLongAcrossAll');
  for (var cat in newCategories) {
    print('  $cat: ${report[cat]!.length} questions');
  }

  final reportFile = File('tools/long_questions_report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  print('\nReport saved to: ${reportFile.path}');
}
