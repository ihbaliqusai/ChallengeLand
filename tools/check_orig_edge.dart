import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final orig = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;
  print('Original image: ${orig.width}x${orig.height}');

  int count = 0;
  for (int y = 0; y < orig.height; y++) {
    for (int x = 0; x < orig.width; x++) {
      final p = orig.getPixel(x, y);
      if (p.a > 0 && p.a < 255) {
        count++;
        if (count <= 15) {
          print('Edge pixel ($x, $y): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}');
        }
      }
    }
  }
  print('Total edge pixels in original: $count');
}
