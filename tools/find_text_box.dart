import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodePng(File('assets/categories/مسلسلات عربية.png').readAsBytesSync())!;
  print('Image dimensions: ${image.width}x${image.height}');

  int minX = 999, maxX = 0, minY = 999, maxY = 0;
  for (int y = 250; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      // Text is white (R>220, G>220, B>220)
      if (p.r > 220 && p.g > 220 && p.b > 220) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('White text bounding box: X=[$minX, $maxX], Y=[$minY, $maxY]');
  print('Width: ${maxX - minX + 1}, Height: ${maxY - minY + 1}');
  print('Center: X=${(minX + maxX)/2}, Y=${(minY + maxY)/2}');
}
