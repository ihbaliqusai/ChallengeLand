import 'dart:convert';
import 'dart:io';

void main() {
  final mainFile = File('assets/questions.json');
  final mainContent = mainFile.readAsStringSync(encoding: utf8);
  final List<dynamic> questions = jsonDecode(mainContent);

  final syrian = questions.where((q) => q['Category']?.toString().trim() == 'دراما سورية').toList();
  print('Total Syrian Drama questions in questions.json: ${syrian.length}');

  final Map<String, int> levels = {};
  for (var q in syrian) {
    final lvl = q['Level']?.toString() ?? 'unknown';
    levels[lvl] = (levels[lvl] ?? 0) + 1;
  }

  print('Distribution in questions.json:');
  for (int i = 0; i <= 8; i++) {
    print('  Level $i: ${levels[i.toString()]}');
  }

  if (syrian.length != 300) {
    throw Exception('Expected 300 questions, got ${syrian.length}');
  }
  print('ALL CHECKS PASSED FOR SYRIAN DRAMA QUESTIONS IN questions.json!');
}
