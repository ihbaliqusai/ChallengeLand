import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Running Comprehensive Verification for Syrian Drama ===\n');

  // 1. Verify Card Artwork
  final f1 = File('assets/categories/دراما سورية.png');
  final f2 = File('android/app/src/main/assets/categories/دراما سورية.png');

  if (!f1.existsSync()) throw Exception('Flutter asset missing');
  if (!f2.existsSync()) throw Exception('Android asset missing');

  final bytes1 = f1.readAsBytesSync();
  final bytes2 = f2.readAsBytesSync();

  if (bytes1.length != bytes2.length) {
    throw Exception('Asset byte length mismatch: ${bytes1.length} vs ${bytes2.length}');
  }
  print('Asset files present and match size: ${bytes1.length} bytes');

  final image = img.decodePng(bytes1)!;
  if (image.width != 352 || image.height != 352) {
    throw Exception('Expected 352x352, got ${image.width}x${image.height}');
  }
  print('Dimensions: 352x352 OK');

  // Verify corner pixels
  final c00 = image.getPixel(0, 0).a;
  final c3510 = image.getPixel(351, 0).a;
  final c0351 = image.getPixel(0, 351).a;
  final c351351 = image.getPixel(351, 351).a;

  if (c00 != 0 || c3510 != 0 || c0351 != 0 || c351351 != 0) {
    throw Exception('Corner alpha check failed: c00=$c00, c3510=$c3510, c0351=$c0351, c351351=$c351351');
  }
  print('Corner Alpha: PASSED (all 4 corners alpha = 0)');

  int zeroAlphaCount = 0;
  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      if (image.getPixel(x, y).a == 0) {
        zeroAlphaCount++;
      }
    }
  }
  print('Total transparent pixels: $zeroAlphaCount (expected ~24,541 for standard squircle)');
  if (zeroAlphaCount < 20000) {
    throw Exception('Insufficient transparent pixels: $zeroAlphaCount');
  }

  // 2. Verify questions in assets/questions.json
  final mainFile = File('assets/questions.json');
  final mainQuestions = jsonDecode(mainFile.readAsStringSync(encoding: utf8)) as List;

  final syrianQuestions = mainQuestions.where((q) => q['Category']?.toString().trim() == 'دراما سورية').toList();
  print('\nQuestions in questions.json: ${syrianQuestions.length}');

  if (syrianQuestions.length != 300) {
    throw Exception('Expected 300 questions, got ${syrianQuestions.length}');
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
  final Set<String> seen = {};

  for (int i = 0; i < syrianQuestions.length; i++) {
    final q = syrianQuestions[i];
    final lvl = q['Level']?.toString() ?? '';
    actual[lvl] = (actual[lvl] ?? 0) + 1;

    final qText = q['Q']?.toString().trim() ?? '';
    if (seen.contains(qText)) {
      throw Exception('Duplicate question: $qText');
    }
    seen.add(qText);

    final r = q['R']?.toString().trim() ?? '';
    final w1 = q['W1']?.toString().trim() ?? '';
    final w2 = q['W2']?.toString().trim() ?? '';
    final w3 = q['W3']?.toString().trim() ?? '';

    final opts = {r, w1, w2, w3};
    if (opts.length != 4) {
      throw Exception('Duplicate options in question $i: $opts');
    }
  }

  print('\nLevel Breakdown:');
  for (int l = 0; l <= 8; l++) {
    final key = l.toString();
    print('  Level $key: ${actual[key]} / ${expected[key]} (MATCH)');
    if (actual[key] != expected[key]) {
      throw Exception('Mismatch in level $key');
    }
  }

  print('\n>>> ALL 8 COMPREHENSIVE CHECKS PASSED FOR SYRIAN DRAMA! <<<');
}
