import 'dart:convert';
import 'dart:io';

import 'build_khaleeji_part1.dart';
import 'build_khaleeji_part2.dart';
import 'build_khaleeji_part3.dart';

void main() {
  print('=== Assembling 300 Questions for Khaleeji Drama ===');

  final allQuestions = <Map<String, String>>[
    ...khaleejiPart1,
    ...khaleejiPart2,
    ...khaleejiPart3,
  ];

  print('Part 1 count: ${khaleejiPart1.length}');
  print('Part 2 count: ${khaleejiPart2.length}');
  print('Part 3 count: ${khaleejiPart3.length}');
  print('Total combined questions: ${allQuestions.length}');

  if (allQuestions.length != 300) {
    throw Exception('Expected 300 questions, got ${allQuestions.length}');
  }

  final outFile = File('assets/questions_khaleeji_drama_300.json');
  final jsonStr = JsonEncoder.withIndent('  ').convert(allQuestions);
  outFile.writeAsStringSync(jsonStr, encoding: utf8);

  print('Successfully wrote 300 questions to ${outFile.path} (${outFile.lengthSync()} bytes)');
}
