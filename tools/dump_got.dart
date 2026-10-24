import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final file = File('assets/questions_game_of_thrones_300.json');
  final List<dynamic> list = jsonDecode(file.readAsStringSync());

  print('=== Game Of Thrones Remaining Questions > 3 words ===');
  int count = 0;
  for (int i = 0; i < list.length; i++) {
    final q = list[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      count++;
      print('[$i] L${q['Level']} Q: ${q['Q']}');
      print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
    }
  }
  print('Total long in GOT: $count');
}
