import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

void main() {
  final cats = [
    {'name': 'دوري أبطال أوروبا', 'file': 'assets/questions_ucl_300.json'},
    {'name': 'NBA', 'file': 'assets/questions_nba_300.json'},
    {'name': 'دراما سورية', 'file': 'assets/questions_syrian_drama_300.json'},
    {'name': 'دراما مصرية', 'file': 'assets/questions_egyptian_drama_300.json'},
  ];

  for (var c in cats) {
    final list = jsonDecode(File(c['file']!).readAsStringSync()) as List;
    print('==============================');
    print('Category: ${c['name']} (${list.length} questions)');
    print('==============================');
    int idx = 0;
    for (var q in list) {
      final r = q['R']?.toString() ?? '';
      final w1 = q['W1']?.toString() ?? '';
      final w2 = q['W2']?.toString() ?? '';
      final w3 = q['W3']?.toString() ?? '';

      final maxW = [countWords(r), countWords(w1), countWords(w2), countWords(w3)].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) {
        print('[$idx] Q: ${q['Q']}');
        print('  R: "$r" (${countWords(r)})');
        print('  W1: "$w1" (${countWords(w1)})');
        print('  W2: "$w2" (${countWords(w2)})');
        print('  W3: "$w3" (${countWords(w3)})');
      }
      idx++;
    }
  }
}
