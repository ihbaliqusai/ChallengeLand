import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final file = File('assets/questions.json');
  final List<dynamic> allQuestions = jsonDecode(file.readAsStringSync());

  for (final cat in ['دراما مصرية', 'دراما خليجية']) {
    print('============================== $cat ==============================');
    for (int i = 0; i < allQuestions.length; i++) {
      final q = allQuestions[i];
      if (q['Category'] == cat) {
        final rW = countWords(q['R'] ?? '');
        final w1W = countWords(q['W1'] ?? '');
        final w2W = countWords(q['W2'] ?? '');
        final w3W = countWords(q['W3'] ?? '');
        if ([rW, w1W, w2W, w3W].any((o) => o > 3)) {
          print('[$i] L${q['Level']} Q: ${q['Q']}');
          print('    R: "${q['R']}" ($rW) | W1: "${q['W1']}" ($w1W) | W2: "${q['W2']}" ($w2W) | W3: "${q['W3']}" ($w3W)');
        }
      }
    }
  }
}
