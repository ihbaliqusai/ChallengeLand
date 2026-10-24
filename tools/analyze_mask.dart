import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final orig = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;
  final newImg = img.decodePng(File('assets/categories/دوري أبطال أوروبا.png').readAsBytesSync())!;

  print('Orig size: ${orig.width} x ${orig.height}');
  print('New size: ${newImg.width} x ${newImg.height}');

  // In orig, let's trace diagonal from (0,0) towards center (176, 176) to see when alpha becomes > 0
  int origFirstOpaque = -1;
  for (int i = 0; i < 100; i++) {
    final p = orig.getPixel(i, i);
    if (p.a > 10) {
      origFirstOpaque = i;
      print('Orig first opaque pixel on diagonal at ($i, $i): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}');
      break;
    }
  }

  // In newImg, let's trace diagonal from (0,0) towards center (176, 176) to see when color changes from white to card background/border
  for (int i = 0; i < 100; i++) {
    final p = newImg.getPixel(i, i);
    // Is it not white? (white is R>245, G>245, B>245)
    if (p.r < 240 || p.g < 240 || p.b < 240) {
      print('NewImg first non-white pixel on diagonal at ($i, $i): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}');
      break;
    }
  }

  // Also check top edge (x=176, y=0..50)
  for (int y = 0; y < 50; y++) {
    final p = orig.getPixel(176, y);
    if (p.a > 10) {
      print('Orig top edge starts at y=$y (alpha=${p.a})');
      break;
    }
  }

  for (int y = 0; y < 50; y++) {
    final p = newImg.getPixel(176, y);
    if (p.r < 240 || p.g < 240 || p.b < 240) {
      print('NewImg top edge starts at y=$y (R=${p.r}, G=${p.g}, B=${p.b})');
      break;
    }
  }

  // Also check bottom edge (x=176, y=351..300)
  for (int y = 351; y > 300; y--) {
    final p = orig.getPixel(176, y);
    if (p.a > 10) {
      print('Orig bottom edge ends at y=$y (alpha=${p.a})');
      break;
    }
  }

  for (int y = 351; y > 300; y--) {
    final p = newImg.getPixel(176, y);
    if (p.r < 240 || p.g < 240 || p.b < 240) {
      print('NewImg bottom edge ends at y=$y (R=${p.r}, G=${p.g}, B=${p.b})');
      break;
    }
  }
}
