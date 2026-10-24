import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final opFile = File('assets/questions_one_piece_300.json');
  final hxhFile = File('assets/questions_hunter_hunter_300.json');

  final List<dynamic> opList = jsonDecode(opFile.readAsStringSync());
  final List<dynamic> hxhList = jsonDecode(hxhFile.readAsStringSync());

  print('=== One Piece sample > 3 words ===');
  int opCount = 0;
  for (int i = 0; i < opList.length; i++) {
    final q = opList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      opCount++;
      if (opCount <= 10) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in One Piece: $opCount');

  print('=== Hunter x Hunter sample > 3 words ===');
  int hxhCount = 0;
  for (int i = 0; i < hxhList.length; i++) {
    final q = hxhList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      hxhCount++;
      if (hxhCount <= 10) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in HxH: $hxhCount');
}
