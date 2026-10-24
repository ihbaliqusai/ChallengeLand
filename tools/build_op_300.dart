import 'dart:convert';
import 'dart:io';

import 'build_op_part1.dart';
import 'build_op_part2.dart';
import 'build_op_part3.dart';

void main() {
  print('=== Assembling 300 Questions for One Piece ===');

  final all = <Map<String, String>>[
    ...part1Questions,
    ...part2Questions,
    ...part3Questions,
  ];

  print('Total assembled questions: ${all.length}');
  if (all.length != 300) {
    throw Exception('Expected 300 questions, got ${all.length}');
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

  final Map<String, int> actual = {};
  final Set<String> seenQuestions = {};

  for (int i = 0; i < all.length; i++) {
    final item = all[i];
    final cat = item['Category'] ?? '';
    final lvl = item['Level'] ?? '';
    final q = item['Q']?.trim() ?? '';
    final r = item['R']?.trim() ?? '';
    final w1 = item['W1']?.trim() ?? '';
    final w2 = item['W2']?.trim() ?? '';
    final w3 = item['W3']?.trim() ?? '';

    if (cat != 'One Piece') {
      throw Exception('Question $i: invalid category "$cat"');
    }

    if (!expected.containsKey(lvl)) {
      throw Exception('Question $i: invalid level "$lvl"');
    }
    actual[lvl] = (actual[lvl] ?? 0) + 1;

    if (seenQuestions.contains(q)) {
      throw Exception('Duplicate question found at $i: "$q"');
    }
    seenQuestions.add(q);

    final options = {r, w1, w2, w3};
    if (options.length != 4) {
      throw Exception('Question $i has duplicate options: $options');
    }
    if (r.isEmpty || w1.isEmpty || w2.isEmpty || w3.isEmpty) {
      throw Exception('Question $i has an empty option');
    }
  }

  print('Level breakdown:');
  for (int l = 0; l <= 8; l++) {
    final key = l.toString();
    print('  Level $key: ${actual[key]} / ${expected[key]} (MATCH)');
    if (actual[key] != expected[key]) {
      throw Exception('Mismatch in level $key: got ${actual[key]}, expected ${expected[key]}');
    }
  }

  final outFile = File('assets/questions_one_piece_300.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all), encoding: utf8);
  print('Wrote 300 validated questions to ${outFile.path}');
}
