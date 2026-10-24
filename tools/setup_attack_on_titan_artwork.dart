import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Processing Attack on Titan Artwork with Transparent Mask ===');

  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  final maskImg = img.decodePng(maskFile.readAsBytesSync())!;

  final srcFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_attack_on_titan_raw.png');
  if (!srcFile.existsSync()) {
    throw Exception('Source artwork not found at ${srcFile.path}');
  }

  final rawSrc = img.decodePng(srcFile.readAsBytesSync())!;
  print('Loaded raw source: ${rawSrc.width}x${rawSrc.height}');

  final result = img.Image(width: 352, height: 352, numChannels: 4);

  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      final ma = maskImg.getPixel(x, y).a;
      final sp = rawSrc.getPixel(x, y);

      if (ma == 0) {
        result.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (ma < 255) {
        // Edge anti-aliasing
        final isTop = y < 268;
        final cardR = isTop ? 173 : 25;
        final cardG = isTop ? 220 : 90;
        final cardB = isTop ? 204 : 89;

        final isWhitish = sp.r > 210 && sp.g > 210 && sp.b > 210;
        final r = isWhitish ? cardR : sp.r;
        final g = isWhitish ? cardG : sp.g;
        final b = isWhitish ? cardB : sp.b;

        result.setPixelRgba(x, y, r, g, b, ma);
      } else {
        // Fully inside mask
        final isCornerZone = (x < 30 || x > 321) && (y < 30 || y > 321);
        final isPureWhite = sp.r > 248 && sp.g > 248 && sp.b > 248;
        if (isCornerZone && isPureWhite) {
          final isTop = y < 268;
          final cardR = isTop ? 173 : 25;
          final cardG = isTop ? 220 : 90;
          final cardB = isTop ? 204 : 89;
          result.setPixelRgba(x, y, cardR, cardG, cardB, 255);
        } else {
          result.setPixelRgba(x, y, sp.r, sp.g, sp.b, 255);
        }
      }
    }
  }

  final pngBytes = img.encodePng(result);

  final name = 'Attack on Titan';
  final f1 = File('assets/categories/$name.png');
  final f2 = File('android/app/src/main/assets/categories/$name.png');
  final f3 = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\attack_on_titan_transparent.png');

  f1.writeAsBytesSync(pngBytes);
  f2.writeAsBytesSync(pngBytes);
  f3.writeAsBytesSync(pngBytes);

  print('Wrote: ${f1.path} (${pngBytes.length} bytes)');
  print('Wrote: ${f2.path} (${pngBytes.length} bytes)');
  print('Wrote: ${f3.path} (${pngBytes.length} bytes)');

  // Verify corner pixels
  print('Corner 0,0: a=${result.getPixel(0, 0).a}');
  print('Corner 351,0: a=${result.getPixel(351, 0).a}');
  print('Corner 0,351: a=${result.getPixel(0, 351).a}');
  print('Corner 351,351: a=${result.getPixel(351, 351).a}');

  int zeroAlphaCount = 0;
  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      if (result.getPixel(x, y).a == 0) {
        zeroAlphaCount++;
      }
    }
  }
  print('Total zero alpha pixels: $zeroAlphaCount');
}
