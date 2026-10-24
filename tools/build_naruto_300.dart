import 'dart:convert';
import 'dart:io';

void main() {
  print('=== Assembling and Validating 300 Naruto Questions ===');

  final part1Raw = jsonDecode(File('tools/naruto_part1_data.json').readAsStringSync()) as List;
  final part2Raw = jsonDecode(File('tools/naruto_part2_data.json').readAsStringSync()) as List;
  final part3Raw = jsonDecode(File('tools/naruto_part3_data.json').readAsStringSync()) as List;

  final all = [...part1Raw, ...part2Raw, ...part3Raw];
  print('Total combined questions: ${all.length}');

  if (all.length != 300) {
    throw Exception('Expected 300 questions, got ${all.length}');
  }

  final levelCounts = <String, int>{};
  final seenQuestions = <String>{};

  for (int i = 0; i < all.length; i++) {
    final q = all[i] as Map<String, dynamic>;
    final lvl = q['Level'].toString();
    final cat = q['Category'] as String;
    final question = q['Q'] as String;
    final r = q['R'] as String;
    final w1 = q['W1'] as String;
    final w2 = q['W2'] as String;
    final w3 = q['W3'] as String;

    levelCounts[lvl] = (levelCounts[lvl] ?? 0) + 1;

    if (cat != 'Naruto') {
      throw Exception('Question $i: invalid category $cat');
    }

    if (question.trim().isEmpty) {
      throw Exception('Question $i: empty question text');
    }

    if (!question.trim().endsWith('؟') && !question.trim().endsWith('?')) {
      print('Warning: Question $i does not end with question mark: "$question"');
    }

    final choices = [r, w1, w2, w3];
    for (var c in choices) {
      if (c.trim().isEmpty) {
        throw Exception('Question $i: empty choice in "$question"');
      }
    }

    if (choices.toSet().length != 4) {
      throw Exception('Question $i: duplicate options in: $choices for question "$question"');
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

  final outFile = File('assets/questions_naruto_300.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all));
  print('\nSuccessfully written 300 Naruto questions to ${outFile.path} (${outFile.lengthSync()} bytes)');
}
