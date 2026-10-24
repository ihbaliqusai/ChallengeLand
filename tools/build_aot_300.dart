import 'dart:convert';
import 'dart:io';

void main() {
  print('Loading Attack on Titan parts...');

  final part1Raw = jsonDecode(File('tools/aot_part1_data.json').readAsStringSync()) as List;
  final part2Raw = jsonDecode(File('tools/aot_part2_data.json').readAsStringSync()) as List;
  final part3Raw = jsonDecode(File('tools/aot_part3_data.json').readAsStringSync()) as List;

  final List<Map<String, String>> allQuestions = [];

  // Part 1 is already in Category, Level, Q, R, W1, W2, W3 format
  for (var item in part1Raw) {
    allQuestions.add({
      'Category': 'Attack on Titan',
      'Level': item['Level'].toString(),
      'Q': item['Q'] as String,
      'R': item['R'] as String,
      'W1': item['W1'] as String,
      'W2': item['W2'] as String,
      'W3': item['W3'] as String,
    });
  }

  // Part 2 conversion
  for (var item in part2Raw) {
    final opts = (item['options'] as List).cast<String>();
    final ansIdx = item['answer_index'] as int;
    final r = opts[ansIdx];
    final wrongs = <String>[];
    for (int i = 0; i < opts.length; i++) {
      if (i != ansIdx) wrongs.add(opts[i]);
    }
    allQuestions.add({
      'Category': 'Attack on Titan',
      'Level': item['level'].toString(),
      'Q': item['question'] as String,
      'R': r,
      'W1': wrongs[0],
      'W2': wrongs[1],
      'W3': wrongs[2],
    });
  }

  // Part 3 conversion
  for (var item in part3Raw) {
    final opts = (item['options'] as List).cast<String>();
    final ansIdx = item['answer_index'] as int;
    final r = opts[ansIdx];
    final wrongs = <String>[];
    for (int i = 0; i < opts.length; i++) {
      if (i != ansIdx) wrongs.add(opts[i]);
    }
    allQuestions.add({
      'Category': 'Attack on Titan',
      'Level': item['level'].toString(),
      'Q': item['question'] as String,
      'R': r,
      'W1': wrongs[0],
      'W2': wrongs[1],
      'W3': wrongs[2],
    });
  }

  print('Total combined questions: ${allQuestions.length}');
  if (allQuestions.length != 300) {
    throw Exception('Expected exactly 300 questions, got ${allQuestions.length}');
  }

  // Validation
  final levelCounts = <String, int>{};
  final seenQuestions = <String>{};

  for (int i = 0; i < allQuestions.length; i++) {
    final q = allQuestions[i];
    final lvl = q['Level']!;
    final question = q['Q']!;
    final r = q['R']!;
    final w1 = q['W1']!;
    final w2 = q['W2']!;
    final w3 = q['W3']!;
    final cat = q['Category']!;

    levelCounts[lvl] = (levelCounts[lvl] ?? 0) + 1;

    if (cat != 'Attack on Titan') {
      throw Exception('Question $i: invalid Category $cat');
    }
    if (question.trim().isEmpty) {
      throw Exception('Question $i: empty question');
    }
    if (!question.trim().endsWith('؟') && !question.trim().endsWith('?')) {
      print('Warning: Question $i does not end with question mark: "$question"');
    }

    final allChoices = [r, w1, w2, w3];
    for (var c in allChoices) {
      if (c.trim().isEmpty) {
        throw Exception('Question $i: empty choice in "$question"');
      }
    }

    if (allChoices.toSet().length != 4) {
      throw Exception('Question $i: duplicate options in: $allChoices for Q: "$question"');
    }

    final normalizedQ = question.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (seenQuestions.contains(normalizedQ)) {
      throw Exception('Duplicate question found at $i: "$normalizedQ"');
    }
    seenQuestions.add(normalizedQ);
  }

  print('\nLevel distribution:');
  for (int lvl = 0; lvl <= 8; lvl++) {
    final count = levelCounts[lvl.toString()] ?? 0;
    print('  Level $lvl: $count questions');
    final expected = (lvl <= 2) ? 34 : 33;
    if (count != expected) {
      throw Exception('Level $lvl: expected $expected, got $count');
    }
  }

  // Write to assets/questions_attack_on_titan_300.json
  final outFile = File('assets/questions_attack_on_titan_300.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(allQuestions));
  print('\nSuccessfully written 300 Attack on Titan questions to ${outFile.path} (${outFile.lengthSync()} bytes)');
}
