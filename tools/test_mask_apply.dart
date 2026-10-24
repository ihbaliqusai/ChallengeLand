import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final maskImg = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;
  final target = img.decodePng(File('assets/categories/دوري أبطال أوروبا.png').readAsBytesSync())!;

  print('Mask: ${maskImg.width}x${maskImg.height}, Target: ${target.width}x${target.height}');

  // Clone target
  final result = img.Image.from(target);

  // Apply alpha mask
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final ma = maskImg.getPixel(x, y).a;
      final tp = result.getPixel(x, y);

      // If mask is completely transparent, set alpha to 0
      if (ma == 0) {
        result.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (ma < 255) {
        // Anti-aliased border: blend alpha
        final newA = (tp.a * (ma / 255.0)).toInt().clamp(0, 255);
        result.setPixelRgba(x, y, tp.r, tp.g, tp.b, newA);
      }
    }
  }

  // Also, let's check corner pixels
  print('Result (0,0): R=${result.getPixel(0,0).r}, A=${result.getPixel(0,0).a}');
  print('Result (351,0): R=${result.getPixel(351,0).r}, A=${result.getPixel(351,0).a}');
  print('Result (176,50): R=${result.getPixel(176,50).r}, A=${result.getPixel(176,50).a}');

  File('tools/test_transparent_ucl.png').writeAsBytesSync(img.encodePng(result));
  print('Saved tools/test_transparent_ucl.png');
}
