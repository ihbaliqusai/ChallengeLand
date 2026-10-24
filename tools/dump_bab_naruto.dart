import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final babFile = File('assets/questions_bab_alhara_300.json');
  final narutoFile = File('assets/questions_naruto_300.json');

  final List<dynamic> babList = jsonDecode(babFile.readAsStringSync());
  final List<dynamic> narutoList = jsonDecode(narutoFile.readAsStringSync());

  print('=== Bab Al-Hara sample > 3 words ===');
  int babCount = 0;
  for (int i = 0; i < babList.length; i++) {
    final q = babList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      babCount++;
      if (babCount <= 10) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in Bab Al-Hara: $babCount');

  print('=== Naruto sample > 3 words ===');
  int narutoCount = 0;
  for (int i = 0; i < narutoList.length; i++) {
    final q = narutoList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      narutoCount++;
      if (narutoCount <= 10) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in Naruto: $narutoCount');
}
