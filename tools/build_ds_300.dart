import 'dart:convert';
import 'dart:io';

import 'build_ds_part1.dart';
import 'build_ds_part2.dart';
import 'build_ds_part3.dart';

void main() {
  final allQuestions = <Map<String, String>>[
    ...dsPart1,
    ...dsPart2,
    ...dsPart3,
  ];

  print('Total collected questions: ${allQuestions.length}');

  if (allQuestions.length != 300) {
    throw Exception('Expected 300 questions, got ${allQuestions.length}');
  }

  // Check level distribution
  final levelCounts = <String, int>{};
  final seenQ = <String>{};

  for (int i = 0; i < allQuestions.length; i++) {
    final q = allQuestions[i];
    final category = q['Category']?.trim();
    final level = q['Level']?.trim();
    final question = q['Q']?.trim();
    final r = q['R']?.trim();
    final w1 = q['W1']?.trim();
    final w2 = q['W2']?.trim();
    final w3 = q['W3']?.trim();

    if (category != 'Demon Slayer') {
      throw Exception('Question #$i has invalid category: $category');
    }
    if (level == null) throw Exception('Question #$i has null level');
    levelCounts[level] = (levelCounts[level] ?? 0) + 1;

    if (question == null || question.isEmpty) throw Exception('Question #$i has empty Q');
    if (r == null || r.isEmpty) throw Exception('Question #$i has empty R');
    if (w1 == null || w1.isEmpty) throw Exception('Question #$i has empty W1');
    if (w2 == null || w2.isEmpty) throw Exception('Question #$i has empty W2');
    if (w3 == null || w3.isEmpty) throw Exception('Question #$i has empty W3');

    // Distinct options check
    final options = {r, w1, w2, w3};
    if (options.length != 4) {
      throw Exception('Question #$i has duplicate choices: $options');
    }

    // Duplicate question check
    if (seenQ.contains(question)) {
      throw Exception('Duplicate question found at #$i: "$question"');
    }
    seenQ.add(question);
  }

  print('Level breakdown:');
  for (int lvl = 0; lvl <= 8; lvl++) {
    final count = levelCounts['$lvl'] ?? 0;
    print('  Level $lvl: $count');
    final expected = (lvl <= 2) ? 34 : 33;
    if (count != expected) {
      throw Exception('Level $lvl has $count questions, expected $expected');
    }
  }

  final outputFile = File('assets/questions_demon_slayer_300.json');
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(allQuestions),
    encoding: utf8,
  );
  print('Successfully wrote 300 validated questions to ${outputFile.path}');
}
