import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/questions_turkish_series_300.json');
  if (!file.existsSync()) {
    print('Error: assets/questions_turkish_series_300.json does not exist');
    exit(1);
  }

  final content = file.readAsStringSync(encoding: utf8);
  final List<dynamic> questions = jsonDecode(content);
  print('Total parsed questions: ${questions.length}');

  if (questions.length != 300) {
    throw Exception('Expected 300 questions, got ${questions.length}');
  }

  final expectedCounts = {
    '0': 34,
    '1': 33,
    '2': 33,
    '4': 33,
    '5': 33,
    '6': 34,
    '3': 33,
    '7': 33,
    '8': 34,
  };

  final Map<String, int> actualCounts = {};
  final Set<String> questionTexts = {};
  int leakCount = 0;
  int missingFieldCount = 0;
  int duplicateOptionCount = 0;

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
      missingFieldCount++;
      print('Missing field in #$i');
    }

    if (cat != 'مسلسلات تركية') {
      throw Exception('Category mismatch in #$i: expected "مسلسلات تركية", got "$cat"');
    }

    actualCounts[level!] = (actualCounts[level] ?? 0) + 1;

    if (!qText.endsWith('؟')) {
      throw Exception('Question #$i does not end with "؟": $qText');
    }

    if (questionTexts.contains(qText)) {
      throw Exception('Duplicate question at #$i: $qText');
    }
    questionTexts.add(qText);

    final options = {r, w1, w2, w3};
    if (options.length != 4) {
      duplicateOptionCount++;
      print('Duplicate option in #$i: R="$r", W1="$w1", W2="$w2", W3="$w3"');
    }

    // Leak check:
    if (r.length > 3 && qText.contains(r)) {
      leakCount++;
      print('Leak detected in #$i: Q="$qText" contains R="$r"');
    }
  }

  print('Actual level breakdown: $actualCounts');
  expectedCounts.forEach((lvl, exp) {
    final act = actualCounts[lvl] ?? 0;
    if (act != exp) {
      throw Exception('Level $lvl mismatch: expected $exp, got $act');
    }
  });

  final tier0 = (actualCounts['0'] ?? 0) + (actualCounts['1'] ?? 0) + (actualCounts['2'] ?? 0);
  final tier1 = (actualCounts['4'] ?? 0) + (actualCounts['5'] ?? 0) + (actualCounts['6'] ?? 0);
  final tier2 = (actualCounts['3'] ?? 0) + (actualCounts['7'] ?? 0) + (actualCounts['8'] ?? 0);

  print('Tier 0: $tier0 (expected 100)');
  print('Tier 1: $tier1 (expected 100)');
  print('Tier 2: $tier2 (expected 100)');

  if (tier0 != 100 || tier1 != 100 || tier2 != 100) {
    throw Exception('Tier sums do not match 100 each');
  }

  if (missingFieldCount > 0 || duplicateOptionCount > 0 || leakCount > 0) {
    throw Exception('Quality checks failed');
  }

  print('ALL TURKISH SERIES CHECKS PASSED PERFECTLY!');
}
