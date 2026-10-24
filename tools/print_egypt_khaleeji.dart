import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

String cleanSimple(String text) {
  var s = text.trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  if (s.contains('/')) {
    s = s.split('/')[0].trim();
  }
  s = s.replaceAll(RegExp(r'[.!؟:;]+$'), '').trim();
  return s;
}

void main() {
  final files = [
    'assets/questions_egyptian_drama_300.json',
    'assets/questions_khaleeji_drama_300.json',
  ];

  for (var f in files) {
    print('=== File: $f ===');
    final list = jsonDecode(File(f).readAsStringSync()) as List;
    for (int i = 0; i < list.length; i++) {
      final q = list[i];
      final r = cleanSimple(q['R']?.toString() ?? '');
      final w1 = cleanSimple(q['W1']?.toString() ?? '');
      final w2 = cleanSimple(q['W2']?.toString() ?? '');
      final w3 = cleanSimple(q['W3']?.toString() ?? '');

      final maxW = [countWords(r), countWords(w1), countWords(w2), countWords(w3)].reduce((a, b) => a > b ? a : b);
      if (maxW > 3) {
        print('[$i] Q: ${q['Q']}');
        print('  R: "$r" (${countWords(r)})');
        print('  W1: "$w1" (${countWords(w1)})');
        print('  W2: "$w2" (${countWords(w2)})');
        print('  W3: "$w3" (${countWords(w3)})');
      }
    }
  }
}
