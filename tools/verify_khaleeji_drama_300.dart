import 'dart:convert';
import 'dart:io';

void main() {
  print('=== Verifying 300 Questions for Khaleeji Drama ===');

  final file = File('assets/questions_khaleeji_drama_300.json');
  if (!file.existsSync()) {
    throw Exception('Error: assets/questions_khaleeji_drama_300.json does not exist');
  }

  final content = file.readAsStringSync(encoding: utf8);
  final List<dynamic> questions = jsonDecode(content);
  print('Total parsed questions: ${questions.length}');

  if (questions.length != 300) {
    throw Exception('Expected 300 questions, got ${questions.length}');
  }

  final expectedCounts = {
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

  final Map<String, int> actualCounts = {};
  final Set<String> questionTexts = {};
  int errors = 0;

  for (int i = 0; i < questions.length; i++) {
    final q = questions[i] as Map<String, dynamic>;
    final level = q['Level']?.toString();
    final qText = q['Q']?.toString().trim() ?? '';
    final r = q['R']?.toString().trim() ?? '';
    final w1 = q['W1']?.toString().trim() ?? '';
    final w2 = q['W2']?.toString().trim() ?? '';
    final w3 = q['W3']?.toString().trim() ?? '';
    final cat = q['Category']?.toString().trim() ?? '';

    if (level == null || qText.isEmpty || r.isEmpty || w1.isEmpty || w2.isEmpty || w3.isEmpty || cat.isEmpty) {
      print('ERROR: Missing field in #$i');
      errors++;
    }

    if (cat != 'دراما خليجية') {
      print('ERROR: Category mismatch in #$i: expected "دراما خليجية", got "$cat"');
      errors++;
    }

    actualCounts[level!] = (actualCounts[level] ?? 0) + 1;

    if (!qText.endsWith('؟')) {
      print('ERROR: Question #$i does not end with "؟": $qText');
      errors++;
    }

    // Check duplicate questions
    final normQ = qText.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (questionTexts.contains(normQ)) {
      print('ERROR: Duplicate question text in #$i: $qText');
      errors++;
    }
    questionTexts.add(normQ);

    // Check distinct options
    final options = [r, w1, w2, w3];
    final normOptions = options.map((o) => o.toLowerCase().trim()).toSet();
    if (normOptions.length != 4) {
      print('ERROR: Duplicate options in #$i: $options');
      errors++;
    }
  }

  print('\nLevel Distribution:');
  for (int l = 0; l <= 8; l++) {
    final key = l.toString();
    final count = actualCounts[key] ?? 0;
    final exp = expectedCounts[key] ?? 0;
    final match = count == exp ? 'MATCH' : 'MISMATCH';
    print('  Level $key: $count / $exp ($match)');
    if (count != exp) {
      errors++;
    }
  }

  if (errors > 0) {
    throw Exception('Verification FAILED with $errors errors.');
  }

  print('\n>>> VERIFICATION PASSED: All 300 questions are valid, distinct, and properly formatted! <<<');
}
