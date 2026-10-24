import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = [
    'assets/categories/رياضة.png',
    'assets/categories/مسلسلات عربية.png',
    'assets/categories/مسيرة لاعب.png',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final image = img.decodePng(bytes);
    if (image == null) continue;

    print('File: $path');
    print('  Dimensions: ${image.width} x ${image.height}');

    // Sample top background color at (x: 176, y: 50)
    final pBg = image.getPixel(176, 50);
    print('  Top BG Color: R=${pBg.r.toInt()}, G=${pBg.g.toInt()}, B=${pBg.b.toInt()}');

    // Sample bottom bar color at (x: 176, y: image.height - 30)
    final pBar = image.getPixel(176, image.height - 30);
    print('  Bottom Bar Color: R=${pBar.r.toInt()}, G=${pBar.g.toInt()}, B=${pBar.b.toInt()}');

    // Find where bottom bar starts
    for (int y = (image.height * 0.6).toInt(); y < image.height; y++) {
      final p = image.getPixel(176, y);
      if ((p.r.toInt() - pBar.r.toInt()).abs() < 5 &&
          (p.g.toInt() - pBar.g.toInt()).abs() < 5 &&
          (p.b.toInt() - pBar.b.toInt()).abs() < 5) {
        print('  Bottom Bar Y start: $y (ratio: ${(y / image.height).toStringAsFixed(3)})');
        break;
      }
    }
  }
}
