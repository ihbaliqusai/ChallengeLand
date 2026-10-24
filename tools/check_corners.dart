import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = [
    'assets/categories/دوري أبطال أوروبا.png',
    'assets/categories/NBA.png',
    'assets/categories/بنات وبس.png',
    'assets/categories/باب الحارة.png',
    'assets/categories/مسلسلات تركية.png',
    'assets/categories/دراما خليجية.png',
    'android/app/src/main/assets/categories/دوري أبطال أوروبا.png',
    'android/app/src/main/assets/categories/NBA.png',
    'android/app/src/main/assets/categories/بنات وبس.png',
    'android/app/src/main/assets/categories/باب الحارة.png',
    'android/app/src/main/assets/categories/مسلسلات تركية.png',
    'android/app/src/main/assets/categories/دراما خليجية.png',
  ];

  print('=== Verifying Final Transparency on All 12 Asset Files ===');
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      print('MISSING: $path');
      continue;
    }
    final image = img.decodePng(file.readAsBytesSync())!;
    final p00 = image.getPixel(0, 0);
    final pTopRight = image.getPixel(image.width - 1, 0);
    final pBottomLeft = image.getPixel(0, image.height - 1);
    final pBottomRight = image.getPixel(image.width - 1, image.height - 1);

    final allCornersZero = p00.a == 0 && pTopRight.a == 0 && pBottomLeft.a == 0 && pBottomRight.a == 0;
    print('$path (${image.width}x${image.height}): ${allCornersZero ? "PASS (Corners A=0)" : "FAIL"}');
    if (!allCornersZero) {
      print('  c(0,0).a=${p00.a}, c(w-1,0).a=${pTopRight.a}, c(0,h-1).a=${pBottomLeft.a}, c(w-1,h-1).a=${pBottomRight.a}');
    }
  }
}
