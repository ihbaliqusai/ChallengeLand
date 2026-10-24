import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

void main() {
  final file = File('assets/questions.json');
  final list = jsonDecode(file.readAsStringSync()) as List;

  final categoryLongCount = <String, int>{};
  final categoryTotalCount = <String, int>{};
  final sampleLong = <String, List<Map<String, dynamic>>>{};

  for (var item in list) {
    final cat = item['Category']?.toString() ?? 'Unknown';
    categoryTotalCount[cat] = (categoryTotalCount[cat] ?? 0) + 1;

    final r = item['R']?.toString() ?? '';
    final w1 = item['W1']?.toString() ?? '';
    final w2 = item['W2']?.toString() ?? '';
    final w3 = item['W3']?.toString() ?? '';

    final rWords = countWords(r);
    final w1Words = countWords(w1);
    final w2Words = countWords(w2);
    final w3Words = countWords(w3);

    final maxWords = [rWords, w1Words, w2Words, w3Words].reduce((a, b) => a > b ? a : b);

    if (maxWords > 3) {
      categoryLongCount[cat] = (categoryLongCount[cat] ?? 0) + 1;
      sampleLong.putIfAbsent(cat, () => []);
      if (sampleLong[cat]!.length < 3) {
        sampleLong[cat]!.add({
          'Q': item['Q'],
          'R': r,
          'W1': w1,
          'W2': w2,
          'W3': w3,
          'maxWords': maxWords,
        });
      }
    }
  }

  print('=== Categories with answers > 3 words ===');
  final sortedCats = categoryLongCount.keys.toList()
    ..sort((a, b) => (categoryLongCount[b] ?? 0).compareTo(categoryLongCount[a] ?? 0));

  for (var cat in sortedCats) {
    final longCount = categoryLongCount[cat] ?? 0;
    final total = categoryTotalCount[cat] ?? 0;
    print('$cat: $longCount / $total questions have answers > 3 words');
  }

  print('\n=== Sample long answers per category ===');
  for (var cat in sortedCats) {
    print('\n--- $cat ---');
    for (var sample in sampleLong[cat]!) {
      print('Q: ${sample['Q']}');
      print('  R (${countWords(sample['R'].toString())}): ${sample['R']}');
      print('  W1 (${countWords(sample['W1'].toString())}): ${sample['W1']}');
      print('  W2 (${countWords(sample['W2'].toString())}): ${sample['W2']}');
      print('  W3 (${countWords(sample['W3'].toString())}): ${sample['W3']}');
    }
  }
}
