import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Applying Transparent Rounded Squircle Masks to All 5 Categories ===');

  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  if (!maskFile.existsSync()) {
    throw Exception('Mask reference file not found at ${maskFile.path}');
  }
  final maskImg = img.decodePng(maskFile.readAsBytesSync())!;

  final categories = [
    'دوري أبطال أوروبا',
    'NBA',
    'بنات وبس',
    'باب الحارة',
    'مسلسلات تركية',
  ];

  for (final name in categories) {
    print('\nProcessing: $name ...');
    final srcFile = File('assets/categories/$name.png');
    final src = img.decodePng(srcFile.readAsBytesSync())!;

    final result = img.Image(width: 352, height: 352, numChannels: 4);

    for (int y = 0; y < 352; y++) {
      for (int x = 0; x < 352; x++) {
        final ma = maskImg.getPixel(x, y).a;
        final sp = src.getPixel(x, y);

        if (ma == 0) {
          result.setPixelRgba(x, y, 0, 0, 0, 0);
        } else if (ma < 255) {
          // Edge anti-aliasing
          final isTop = y < 268;
          final cardR = isTop ? 173 : 26;
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
            final cardR = isTop ? 173 : 26;
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

    // Save to Flutter asset path
    final f1 = File('assets/categories/$name.png');
    f1.writeAsBytesSync(pngBytes);

    // Save to Android asset path
    final f2 = File('android/app/src/main/assets/categories/$name.png');
    f2.writeAsBytesSync(pngBytes);

    print('  Saved Flutter asset: ${f1.path} (${f1.lengthSync()} bytes)');
    print('  Saved Android asset: ${f2.path} (${f2.lengthSync()} bytes)');

    // Verify corners
    final checkImg = img.decodePng(pngBytes)!;
    final c00 = checkImg.getPixel(0, 0).a;
    final c3510 = checkImg.getPixel(351, 0).a;
    final c0351 = checkImg.getPixel(0, 351).a;
    final c351351 = checkImg.getPixel(351, 351).a;

    if (c00 != 0 || c3510 != 0 || c0351 != 0 || c351351 != 0) {
      throw Exception('Corner alpha check failed for $name: c00=$c00, c3510=$c3510, c0351=$c0351, c351351=$c351351');
    }
    print('  Corner Alpha Check: PASSED (all corners alpha = 0)');
  }

  print('\n>>> ALL 5 CATEGORIES SUCCESSFULLY APPLIED WITH TRANSPARENT BACKGROUNDS! <<<');
}
