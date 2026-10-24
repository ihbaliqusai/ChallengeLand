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

  final inspectCats = [
    'دوري أبطال أوروبا',
    'NBA',
    'دراما سورية',
    'دراما مصرية',
    'دراما خليجية',
  ];

  for (var cat in inspectCats) {
    print('==============================');
    print('Category: $cat');
    print('==============================');
    final catQuestions = list.where((item) => item['Category'] == cat).toList();
    int idx = 0;
    for (var q in catQuestions) {
      final r = q['R']?.toString() ?? '';
      final w1 = q['W1']?.toString() ?? '';
      final w2 = q['W2']?.toString() ?? '';
      final w3 = q['W3']?.toString() ?? '';

      final maxW = [countWords(r), countWords(w1), countWords(w2), countWords(w3)].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) {
        print('[$idx] (L${q['Level']}) Q: ${q['Q']}');
        print('  R: "$r" (${countWords(r)})');
        print('  W1: "$w1" (${countWords(w1)})');
        print('  W2: "$w2" (${countWords(w2)})');
        print('  W3: "$w3" (${countWords(w3)})');
      }
      idx++;
    }
  }
}
