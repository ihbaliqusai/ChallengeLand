import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Processing Demon Slayer Artwork with Transparent Mask ===');

  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  final maskImg = img.decodePng(maskFile.readAsBytesSync())!;

  final srcFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_demon_slayer_raw.png');
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

  final name = 'Demon Slayer';
  final f1 = File('assets/categories/$name.png');
  f1.writeAsBytesSync(pngBytes);
  print('Saved to Flutter assets: ${f1.path} (${f1.lengthSync()} bytes)');

  final f2 = File('android/app/src/main/assets/categories/$name.png');
  f2.writeAsBytesSync(pngBytes);
  print('Saved to Android assets: ${f2.path} (${f2.lengthSync()} bytes)');

  final brainCopy = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\demon_slayer_transparent.png');
  brainCopy.writeAsBytesSync(pngBytes);
  print('Saved to brain directory: ${brainCopy.path}');

  // Corner verification
  print('\nCorner Alpha values:');
  print('Top-Left (0,0): ${result.getPixel(0, 0).a}');
  print('Top-Right (351,0): ${result.getPixel(351, 0).a}');
  print('Bottom-Left (0,351): ${result.getPixel(0, 351).a}');
  print('Bottom-Right (351,351): ${result.getPixel(351, 351).a}');

  int transparentPixels = 0;
  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      if (result.getPixel(x, y).a == 0) transparentPixels++;
    }
  }
  print('Total 100% transparent pixels: $transparentPixels (expected ~24,541)');
}
