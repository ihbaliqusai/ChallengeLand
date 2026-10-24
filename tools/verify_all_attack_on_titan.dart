import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=======================================================');
  print('   VERIFICATION: Attack on Titan Category & Assets     ');
  print('=======================================================');

  int passedChecks = 0;
  final totalChecks = 10;

  // Check 1: Flutter artwork file & corners
  final flutterArt = File('assets/categories/Attack on Titan.png');
  if (!flutterArt.existsSync()) {
    print('❌ Check 1 FAILED: assets/categories/Attack on Titan.png missing');
  } else {
    final bytes = flutterArt.readAsBytesSync();
    final decoded = img.decodePng(bytes);
    if (decoded == null || decoded.width != 352 || decoded.height != 352) {
      print('❌ Check 1 FAILED: image not 352x352');
    } else {
      final tl = decoded.getPixel(0, 0).a;
      final tr = decoded.getPixel(351, 0).a;
      final bl = decoded.getPixel(0, 351).a;
      final br = decoded.getPixel(351, 351).a;
      int transparentCount = 0;
      for (int y = 0; y < 352; y++) {
        for (int x = 0; x < 352; x++) {
          if (decoded.getPixel(x, y).a == 0) transparentCount++;
        }
      }
      if (tl == 0 && tr == 0 && bl == 0 && br == 0 && transparentCount == 24541) {
        print('✅ Check 1 PASSED: assets/categories/Attack on Titan.png (352x352, corners Alpha=0, transparentCount=24541)');
        passedChecks++;
      } else {
        print('❌ Check 1 FAILED: corners/alpha mismatch: tl=$tl, tr=$tr, bl=$bl, br=$br, count=$transparentCount');
      }
    }
  }

  // Check 2: Android asset file
  final androidArt = File('android/app/src/main/assets/categories/Attack on Titan.png');
  if (androidArt.existsSync() && androidArt.lengthSync() == flutterArt.lengthSync()) {
    print('✅ Check 2 PASSED: android/app/src/main/assets/categories/Attack on Titan.png matches Flutter asset (${androidArt.lengthSync()} bytes)');
    passedChecks++;
  } else {
    print('❌ Check 2 FAILED: Android asset missing or size mismatch');
  }

  // Check 3: game_category.dart
  final gameCategoryStr = File('lib/models/game_category.dart').readAsStringSync();
  if (gameCategoryStr.contains("GameCategory(name: 'Attack on Titan', isPremium: true)")) {
    print('✅ Check 3 PASSED: Registered in lib/models/game_category.dart');
    passedChecks++;
  } else {
    print('❌ Check 3 FAILED: lib/models/game_category.dart missing entry');
  }

  // Check 4: shared_assets.json
  final sharedAssetsStr = File('tools/shared_assets.json').readAsStringSync();
  if (sharedAssetsStr.contains('"assets/categories/Attack on Titan.png": "android/app/src/main/assets/categories/Attack on Titan.png"')) {
    print('✅ Check 4 PASSED: Registered in tools/shared_assets.json');
    passedChecks++;
  } else {
    print('❌ Check 4 FAILED: tools/shared_assets.json missing entry');
  }

  // Check 5: shared_android_assets.g.dart
  final sharedAndroidAssetsStr = File('lib/core/shared_android_assets.g.dart').readAsStringSync();
  if (sharedAndroidAssetsStr.contains('"assets/categories/Attack on Titan.png": "android/app/src/main/assets/categories/Attack on Titan.png"')) {
    print('✅ Check 5 PASSED: Registered in lib/core/shared_android_assets.g.dart');
    passedChecks++;
  } else {
    print('❌ Check 5 FAILED: lib/core/shared_android_assets.g.dart missing entry');
  }

  // Check 6: artwork_sizes.g.dart
  final artworkSizesStr = File('lib/core/artwork_sizes.g.dart').readAsStringSync();
  if (artworkSizesStr.contains('"assets/categories/Attack on Titan.png": Size(352, 352)')) {
    print('✅ Check 6 PASSED: Registered in lib/core/artwork_sizes.g.dart with Size(352, 352)');
    passedChecks++;
  } else {
    print('❌ Check 6 FAILED: lib/core/artwork_sizes.g.dart missing entry');
  }

  // Check 7: SharedAssetStore.java
  final javaStoreStr = File('android/app/src/main/java/com/Qi7bali/challengeland/SharedAssetStore.java').readAsStringSync();
  if (javaStoreStr.contains('case "assets/categories/Attack on Titan.png": return context.getAssets().open("categories/Attack on Titan.png");')) {
    print('✅ Check 7 PASSED: Registered in SharedAssetStore.java');
    passedChecks++;
  } else {
    print('❌ Check 7 FAILED: SharedAssetStore.java missing case');
  }

  // Check 8: Attack on Titan 300 questions file
  final aot300File = File('assets/questions_attack_on_titan_300.json');
  if (!aot300File.existsSync()) {
    print('❌ Check 8 FAILED: assets/questions_attack_on_titan_300.json missing');
  } else {
    final aotList = jsonDecode(aot300File.readAsStringSync()) as List;
    final lvlCounts = <String, int>{};
    for (var q in aotList) {
      final lvl = q['Level'].toString();
      lvlCounts[lvl] = (lvlCounts[lvl] ?? 0) + 1;
    }
    bool lvlCheck = true;
    for (int l = 0; l <= 8; l++) {
      final expected = (l <= 2) ? 34 : 33;
      if (lvlCounts[l.toString()] != expected) {
        lvlCheck = false;
        break;
      }
    }
    if (aotList.length == 300 && lvlCheck) {
      print('✅ Check 8 PASSED: questions_attack_on_titan_300.json has 300 questions with exact level distribution (34,34,34,33,33,33,33,33,33)');
      passedChecks++;
    } else {
      print('❌ Check 8 FAILED: invalid count or level distribution');
    }
  }

  // Check 9: Backup file before merge
  final backupFile = File('assets/questions.backup_before_attack_on_titan.json');
  if (backupFile.existsSync() && backupFile.lengthSync() > 5000000) {
    print('✅ Check 9 PASSED: Backup file exists (${backupFile.lengthSync()} bytes)');
    passedChecks++;
  } else {
    print('❌ Check 9 FAILED: Backup file missing or corrupted');
  }

  // Check 10: Merged questions.json
  final mainQuestionsFile = File('assets/questions.json');
  final mainQuestionsList = jsonDecode(mainQuestionsFile.readAsStringSync()) as List;
  final aotInMain = mainQuestionsList.where((q) => q['Category'] == 'Attack on Titan').toList();
  if (mainQuestionsList.length == 20827 && aotInMain.length == 300) {
    print('✅ Check 10 PASSED: questions.json total = 20827, Attack on Titan = 300');
    passedChecks++;
  } else {
    print('❌ Check 10 FAILED: questions.json total = ${mainQuestionsList.length} (expected 20827), AoT = ${aotInMain.length} (expected 300)');
  }

  print('=======================================================');
  print('Result: $passedChecks / $totalChecks checks passed');
  if (passedChecks == totalChecks) {
    print('🎉 ALL VERIFICATIONS COMPLETED SUCCESSFULLY!');
  } else {
    print('⚠️ SOME CHECKS FAILED!');
    exit(1);
  }
}
