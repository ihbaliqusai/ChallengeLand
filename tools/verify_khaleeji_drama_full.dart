import 'dart:convert';
import 'dart:io';

void main() {
  final mainFile = File('assets/questions.json');
  final mainContent = mainFile.readAsStringSync(encoding: utf8);
  final List<dynamic> questions = jsonDecode(mainContent);

  final khaleejiQuestions = questions.where((q) {
    return q['Category']?.toString().trim() == 'دراما خليجية';
  }).toList();

  print('Total questions in questions.json: ${questions.length}');
  print('Total "دراما خليجية" questions: ${khaleejiQuestions.length}');

  if (khaleejiQuestions.length != 300) {
    throw Exception('Expected 300 "دراما خليجية" questions, found ${khaleejiQuestions.length}');
  }

  final Map<String, int> levelCounts = {};
  for (final q in khaleejiQuestions) {
    final lvl = q['Level']?.toString() ?? 'unknown';
    levelCounts[lvl] = (levelCounts[lvl] ?? 0) + 1;
  }

  print('Levels in merged questions.json: $levelCounts');
  print('>>> ALL "دراما خليجية" QUESTIONS VERIFIED IN MAIN POOL! <<<');
}
