import 'dart:convert';
import 'dart:io';

import 'build_egyptian_part1.dart';
import 'build_egyptian_part2.dart';
import 'build_egyptian_part3.dart';

void main() {
  print('=== Assembling 300 Questions for Egyptian Drama ===');

  final allQuestions = <Map<String, String>>[
    ...egyptianPart1,
    ...egyptianPart2,
    ...egyptianPart3,
  ];

  print('Part 1 count: ${egyptianPart1.length}');
  print('Part 2 count: ${egyptianPart2.length}');
  print('Part 3 count: ${egyptianPart3.length}');
  print('Total combined questions: ${allQuestions.length}');

  if (allQuestions.length != 300) {
    throw Exception('Expected 300 questions, got ${allQuestions.length}');
  }

  // Distribution verification
  final Map<String, int> levelCounts = {};
  final Set<String> seenQuestions = {};
  final List<String> duplicates = [];
  final List<String> errors = [];

  for (int i = 0; i < allQuestions.length; i++) {
    final q = allQuestions[i];
    final questionText = q['Q'] ?? '';
    final r = q['R'] ?? '';
    final w1 = q['W1'] ?? '';
    final w2 = q['W2'] ?? '';
    final w3 = q['W3'] ?? '';
    final category = q['Category'] ?? '';
    final level = q['Level'] ?? '';

    levelCounts[level] = (levelCounts[level] ?? 0) + 1;

    if (seenQuestions.contains(questionText.trim())) {
      duplicates.add('Index $i: $questionText');
    }
    seenQuestions.add(questionText.trim());

    if (category != 'دراما مصرية') {
      errors.add('Index $i: Invalid category "$category"');
    }
    if (questionText.trim().isEmpty) {
      errors.add('Index $i: Empty question');
    }

    final options = [r, w1, w2, w3];
    final optSet = options.map((e) => e.trim()).toSet();
    if (optSet.length != 4) {
      errors.add('Index $i: Duplicate options in question "$questionText" -> $options');
    }
  }

  print('\n--- Level Distribution ---');
  for (int lvl = 0; lvl <= 8; lvl++) {
    final key = lvl.toString();
    print('Level $key: ${levelCounts[key] ?? 0}');
  }

  if (duplicates.isNotEmpty) {
    print('\nWARNING: Found ${duplicates.length} duplicate questions:');
    for (final d in duplicates) {
      print(' - $d');
    }
  }

  if (errors.isNotEmpty) {
    print('\nERRORS FOUND:');
    for (final e in errors) {
      print(' - $e');
    }
    exit(1);
  }

  final expected = {
    '0': 34,
    '1': 34,
    '2': 34,
    '3': 33,
    '4': 33,
    '5': 33,
    '6': 33,
    '7': 33,
    '8': 33,
  };

  bool match = true;
  for (final entry in expected.entries) {
    if ((levelCounts[entry.key] ?? 0) != entry.value) {
      print('Mismatch in Level ${entry.key}: expected ${entry.value}, got ${levelCounts[entry.key]}');
      match = false;
    }
  }

  if (!match) {
    print('Level counts do not match expected standard!');
    exit(1);
  }

  final outFile = File('assets/questions_egyptian_drama_300.json');
  final jsonStr = JsonEncoder.withIndent('  ').convert(allQuestions);
  outFile.writeAsStringSync(jsonStr, encoding: utf8);

  print('\nSUCCESS: Generated ${allQuestions.length} Egyptian Drama questions in ${outFile.path} (${outFile.lengthSync()} bytes)');
}
