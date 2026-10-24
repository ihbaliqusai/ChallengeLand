import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final maskImg = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;

  final categories = [
    'دوري أبطال أوروبا',
    'NBA',
    'بنات وبس',
    'باب الحارة',
    'مسلسلات تركية',
  ];

  for (final name in categories) {
    final file = File('assets/categories/$name.png');
    final src = img.decodePng(file.readAsBytesSync())!;

    final result = img.Image(width: 352, height: 352, numChannels: 4);

    // Card colors:
    // Mint green: #ADDCCC -> R=173, G=220, B=204
    // Dark teal:  #1A5A59 -> R=26, G=90, B=89
    // Bottom bar starts around y = 265-270

    for (int y = 0; y < 352; y++) {
      for (int x = 0; x < 352; x++) {
        final ma = maskImg.getPixel(x, y).a;
        final sp = src.getPixel(x, y);

        if (ma == 0) {
          result.setPixelRgba(x, y, 0, 0, 0, 0);
        } else if (ma < 255) {
          // Edge anti-aliasing:
          // If the source pixel was blended with white (sp.r, sp.g, sp.b > 200),
          // blend between the true card background and transparent, avoiding white fringe.
          final isTop = y < 268;
          final cardR = isTop ? 173 : 26;
          final cardG = isTop ? 220 : 90;
          final cardB = isTop ? 204 : 89;

          // If the source pixel is significantly whitish compared to card color, use card color
          final isWhitish = sp.r > 210 && sp.g > 210 && sp.b > 210;
          final r = isWhitish ? cardR : sp.r;
          final g = isWhitish ? cardG : sp.g;
          final b = isWhitish ? cardB : sp.b;

          result.setPixelRgba(x, y, r, g, b, ma);
        } else {
          // ma == 255: fully inside mask
          // Just in case the generated card squircle was 1px smaller than mask:
          // Check if it's in the extreme corner zone and completely white
          final isCornerZone = (x < 30 || x > 321) && (y < 30 || y > 321);
          final isPureWhite = sp.r > 248 && sp.g > 248 && sp.b > 248;
          if (isCornerZone && isPureWhite) {
            // It's the white outside of a slightly smaller squircle
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

    final outPath = 'tools/preview_$name.png';
    File(outPath).writeAsBytesSync(img.encodePng(result));
    print('Generated $outPath');
  }
}
