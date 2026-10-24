import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final maskImg = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;

  final targets = [
    'assets/categories/دوري أبطال أوروبا.png',
    'assets/categories/NBA.png',
    'assets/categories/بنات وبس.png',
    'assets/categories/باب الحارة.png',
    'assets/categories/مسلسلات تركية.png',
  ];

  for (final path in targets) {
    final bytes = File(path).readAsBytesSync();
    final target = img.decodePng(bytes)!;

    // Check corners and perimeter
    int whiteOutsideMask = 0;
    int whiteInsideMaskEdge = 0;

    for (int y = 0; y < target.height; y++) {
      for (int x = 0; x < target.width; x++) {
        final ma = maskImg.getPixel(x, y).a;
        final tp = target.getPixel(x, y);
        final isWhite = tp.r > 240 && tp.g > 240 && tp.b > 240;

        if (ma == 0 && isWhite) {
          whiteOutsideMask++;
        } else if (ma > 0 && ma < 255 && isWhite) {
          whiteInsideMaskEdge++;
        }
      }
    }

    print('$path:');
    print('  White pixels outside mask: $whiteOutsideMask');
    print('  White pixels along edge: $whiteInsideMaskEdge');
  }
}
