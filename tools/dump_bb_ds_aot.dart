import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final bbFile = File('assets/questions_breaking_bad_300.json');
  final dsFile = File('assets/questions_demon_slayer_300.json');
  final aotFile = File('assets/questions_attack_on_titan_300.json');

  final List<dynamic> bbList = jsonDecode(bbFile.readAsStringSync());
  final List<dynamic> dsList = jsonDecode(dsFile.readAsStringSync());
  final List<dynamic> aotList = jsonDecode(aotFile.readAsStringSync());

  print('=== Breaking Bad sample > 3 words ===');
  int bbCount = 0;
  for (int i = 0; i < bbList.length; i++) {
    final q = bbList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      bbCount++;
      if (bbCount <= 5) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in BB: $bbCount');

  print('=== Demon Slayer sample > 3 words ===');
  int dsCount = 0;
  for (int i = 0; i < dsList.length; i++) {
    final q = dsList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      dsCount++;
      if (dsCount <= 5) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in DS: $dsCount');

  print('=== Attack on Titan sample > 3 words ===');
  int aotCount = 0;
  for (int i = 0; i < aotList.length; i++) {
    final q = aotList[i];
    final opts = [q['R'] ?? '', q['W1'] ?? '', q['W2'] ?? '', q['W3'] ?? ''];
    if (opts.any((o) => countWords(o.toString()) > 3)) {
      aotCount++;
      if (aotCount <= 5) {
        print('[$i] L${q['Level']} Q: ${q['Q']}');
        print('    R: "${q['R']}" | W1: "${q['W1']}" | W2: "${q['W2']}" | W3: "${q['W3']}"');
      }
    }
  }
  print('Total long in AOT: $aotCount');
}
