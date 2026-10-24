import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final maskImg = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;
  print('Mask image: ${maskImg.width} x ${maskImg.height}');

  int transparentPixels = 0;
  int opaquePixels = 0;
  int semiTransparentPixels = 0;

  for (int y = 0; y < maskImg.height; y++) {
    for (int x = 0; x < maskImg.width; x++) {
      final a = maskImg.getPixel(x, y).a;
      if (a == 0) {
        transparentPixels++;
      } else if (a == 255) {
        opaquePixels++;
      } else {
        semiTransparentPixels++;
      }
    }
  }

  print('Transparent (A=0): $transparentPixels');
  print('Opaque (A=255): $opaquePixels');
  print('Semi-transparent (0<A<255): $semiTransparentPixels');
  print('Total pixels: ${maskImg.width * maskImg.height}');
}
