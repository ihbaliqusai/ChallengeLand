import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final turk = img.decodePng(File('assets/categories/مسلسلات تركية.png').readAsBytesSync())!;

  // Left word "تركية" is roughly x <= 160
  int tMinX = 999, tMaxX = 0, tMinY = 999, tMaxY = 0;
  for (int y = 280; y <= 330; y++) {
    for (int x = 50; x <= 165; x++) {
      final p = turk.getPixel(x, y);
      if (p.r > 200 && p.g > 200 && p.b > 200) {
        if (x < tMinX) tMinX = x;
        if (x > tMaxX) tMaxX = x;
        if (y < tMinY) tMinY = y;
        if (y > tMaxY) tMaxY = y;
      }
    }
  }
  print('Word "تركية" bounding box: X=[$tMinX, $tMaxX], Y=[$tMinY, $tMaxY] (width: ${tMaxX - tMinX + 1}, height: ${tMaxY - tMinY + 1})');
}
