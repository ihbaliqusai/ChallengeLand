import 'dart:convert';
import 'dart:io';

void main() {
  print('--- Verifying Category "بنات وبس" (Girls Only) ---');

  // 1. Check questions_girls_300.json
  final qFile = File('assets/questions_girls_300.json');
  if (!qFile.existsSync()) throw Exception('assets/questions_girls_300.json missing');
  final List<dynamic> qGirls = jsonDecode(qFile.readAsStringSync(encoding: utf8));
  print('1. questions_girls_300.json question count: ${qGirls.length} (expected 300)');
  if (qGirls.length != 300) throw Exception('Expected 300 questions in questions_girls_300.json');

  // 2. Check questions.json
  final mainFile = File('assets/questions.json');
  if (!mainFile.existsSync()) throw Exception('assets/questions.json missing');
  final List<dynamic> mainQuestions = jsonDecode(mainFile.readAsStringSync(encoding: utf8));
  print('2. questions.json total count: ${mainQuestions.length} (expected 16927)');

  final inMain = mainQuestions.where((q) => q['Category']?.toString().trim() == 'بنات وبس').toList();
  print('3. "بنات وبس" in main questions.json: ${inMain.length} (expected 300)');
  if (inMain.length != 300) throw Exception('Expected 300 questions of category in main dataset');

  final counts = <String, int>{};
  for (final q in inMain) {
    final lvl = q['Level'].toString();
    counts[lvl] = (counts[lvl] ?? 0) + 1;
  }
  print('4. Level breakdown: $counts');
  final expected = {'0': 34, '1': 33, '2': 33, '4': 33, '5': 33, '6': 34, '3': 33, '7': 33, '8': 34};
  expected.forEach((k, v) {
    if (counts[k] != v) throw Exception('Level $k count mismatch: expected $v, got ${counts[k]}');
  });

  // 5. Check GameCategory
  final catModel = File('lib/models/game_category.dart').readAsStringSync(encoding: utf8);
  if (!catModel.contains("GameCategory(name: 'بنات وبس', isPremium: true)")) {
    throw Exception('lib/models/game_category.dart does not register بنات وبس');
  }
  print('5. GameCategory model registration verified.');

  // 6. Check Artworks
  final art1 = File('assets/categories/بنات وبس.png');
  final art2 = File('android/app/src/main/assets/categories/بنات وبس.png');
  if (!art1.existsSync() || art1.lengthSync() < 1000) throw Exception('Flutter asset artwork missing or too small');
  if (!art2.existsSync() || art2.lengthSync() < 1000) throw Exception('Android asset artwork missing or too small');
  print('6. Category artworks verified: ${art1.lengthSync()} bytes.');

  // 7. Check Shared Assets
  final sharedDart = File('lib/core/shared_android_assets.g.dart').readAsStringSync(encoding: utf8);
  if (!sharedDart.contains('"assets/categories/بنات وبس.png"')) {
    throw Exception('shared_android_assets.g.dart missing mapping');
  }
  print('7. Shared Android assets bridge verified.');

  // 8. Check SharedAssetStore.java
  final javaFile = File('android/app/src/main/java/com/Qi7bali/challengeland/SharedAssetStore.java').readAsStringSync(encoding: utf8);
  if (!javaFile.contains('case "assets/categories/بنات وبس.png":')) {
    throw Exception('SharedAssetStore.java missing case');
  }
  print('8. Java SharedAssetStore verified.');

  print('\n>>> ALL 8 INTEGRATION CHECKS PASSED WITH 100% SUCCESS! <<<');
}
