import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodePng(File('tools/test_transparent_ucl.png').readAsBytesSync())!;
  print('test_transparent_ucl: ${image.width}x${image.height}');

  int whiteVisiblePixels = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.a > 0 && p.r > 245 && p.g > 245 && p.b > 245) {
        // Check if this pixel is in the trophy or in the background corner/edge
        // Trophy is roughly in x: 100..250, y: 70..240
        final isCorner = (x < 50 || x > 300) && (y < 50 || y > 300);
        if (isCorner) {
          whiteVisiblePixels++;
          if (whiteVisiblePixels <= 10) {
            print('White visible pixel at ($x, $y): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}');
          }
        }
      }
    }
  }

  print('Total white visible pixels in corners: $whiteVisiblePixels');
}
