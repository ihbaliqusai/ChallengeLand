import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String cleanSimple(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  t = t.replaceAll(RegExp(r'\s*/\s*.*$'), '');
  t = t.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
  return t.trim();
}

void main() {
  final file = File('assets/questions.json');
  final List<dynamic> allQuestions = jsonDecode(file.readAsStringSync());

  for (final cat in ['دراما مصرية']) {
    print('============================== $cat ==============================');
    for (int i = 0; i < allQuestions.length; i++) {
      final q = allQuestions[i];
      if (q['Category'] == cat) {
        final r = cleanSimple(q['R'] ?? '');
        final w1 = cleanSimple(q['W1'] ?? '');
        final w2 = cleanSimple(q['W2'] ?? '');
        final w3 = cleanSimple(q['W3'] ?? '');
        if ([r, w1, w2, w3].any((o) => countWords(o) > 3)) {
          print('[$i] L${q['Level']} Q: ${q['Q']}');
          print('    R: "$r" | W1: "$w1" | W2: "$w2" | W3: "$w3"');
        }
      }
    }
  }
}
