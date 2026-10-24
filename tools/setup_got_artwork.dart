import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Processing Game Of Thrones Artwork with Transparent Mask ===');

  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  final maskImg = img.decodePng(maskFile.readAsBytesSync())!;

  final srcFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_got_raw.png');
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

  final name = 'Game Of Thrones';
  final f1 = File('assets/categories/$name.png');
  f1.writeAsBytesSync(pngBytes);

  final f2 = File('android/app/src/main/assets/categories/$name.png');
  f2.writeAsBytesSync(pngBytes);

  final brainFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\game_of_thrones_transparent.png');
  brainFile.writeAsBytesSync(pngBytes);

  print('Saved Flutter asset: ${f1.path} (${f1.lengthSync()} bytes)');
  print('Saved Android asset: ${f2.path} (${f2.lengthSync()} bytes)');
  print('Saved Artifact asset: ${brainFile.path} (${brainFile.lengthSync()} bytes)');

  // Verify corners
  final check = img.decodePng(pngBytes)!;
  final c00 = check.getPixel(0, 0).a;
  final c3510 = check.getPixel(351, 0).a;
  final c0351 = check.getPixel(0, 351).a;
  final c351351 = check.getPixel(351, 351).a;

  if (c00 != 0 || c3510 != 0 || c0351 != 0 || c351351 != 0) {
    throw Exception('Corner alpha check failed: c00=$c00, c3510=$c3510, c0351=$c0351, c351351=$c351351');
  }
  print('Corner Alpha Check: PASSED (all 4 corners alpha = 0)');
}
