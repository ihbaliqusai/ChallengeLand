import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  final maskImg = img.decodePng(maskFile.readAsBytesSync())!;

  final srcFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\khaleeji_drama_v2_1792841715789.jpg');
  final rawSrc = img.decodeJpg(srcFile.readAsBytesSync())!;

  // Resize to 352x352
  final resized = img.copyResize(rawSrc, width: 352, height: 352, interpolation: img.Interpolation.cubic);

  final result = img.Image(width: 352, height: 352, numChannels: 4);

  // The bottom teal bar should start around y = 265 and extend to the bottom edge.
  // Dark teal color: R=26, G=90, B=89
  // Text "دراما خليجية" is white: R>220, G>220, B>220 in the central region (x: 60..290, y: 265..325)

  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      final ma = maskImg.getPixel(x, y).a;
      final sp = resized.getPixel(x, y);

      if (ma == 0) {
        result.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        // Pixel is inside card
        if (y >= 265) {
          // Bottom bar area
          // Check if this pixel is part of the white title text
          final isText = (x >= 65 && x <= 285 && y >= 265 && y <= 322) &&
                         (sp.r > 200 && sp.g > 200 && sp.b > 200);

          if (isText) {
            result.setPixelRgba(x, y, sp.r, sp.g, sp.b, ma);
          } else {
            // Fill entire bottom bar uniformly with the official dark teal
            // With subtle edge smoothing if ma < 255
            result.setPixelRgba(x, y, 26, 90, 89, ma);
          }
        } else {
          // Top area (mint background + illustration + 'i' icon)
          if (ma < 255) {
            final isWhitish = sp.r > 210 && sp.g > 210 && sp.b > 210;
            final r = isWhitish ? 173 : sp.r;
            final g = isWhitish ? 220 : sp.g;
            final b = isWhitish ? 204 : sp.b;
            result.setPixelRgba(x, y, r, g, b, ma);
          } else {
            final isCornerZone = (x < 30 || x > 321) && y < 30;
            final isPureWhite = sp.r > 248 && sp.g > 248 && sp.b > 248;
            if (isCornerZone && isPureWhite) {
              result.setPixelRgba(x, y, 173, 220, 204, 255);
            } else {
              result.setPixelRgba(x, y, sp.r, sp.g, sp.b, 255);
            }
          }
        }
      }
    }
  }

  final pngBytes = img.encodePng(result);
  File('tools/test_khaleeji_bar.png').writeAsBytesSync(pngBytes);
  print('Saved tools/test_khaleeji_bar.png');
}
