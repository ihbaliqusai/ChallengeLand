import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final ref1 = img.decodePng(File('assets/categories/لاعبين كرة قدم.png').readAsBytesSync())!;
  
  final testFiles = [
    'assets/categories/تقنية.png',
    'assets/categories/حيوانات.png',
    'assets/categories/جغرافيا.png',
    'assets/categories/طعام وشراب.png',
  ];

  for (final path in testFiles) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final other = img.decodePng(file.readAsBytesSync());
    if (other == null) continue;

    int diffCount = 0;
    if (other.width != ref1.width || other.height != ref1.height) {
      print('$path size differs: ${other.width} x ${other.height}');
      continue;
    }

    for (int y = 0; y < ref1.height; y++) {
      for (int x = 0; x < ref1.width; x++) {
        final a1 = ref1.getPixel(x, y).a;
        final a2 = other.getPixel(x, y).a;
        if ((a1 - a2).abs() > 10) {
          diffCount++;
        }
      }
    }
    print('$path: alpha diff pixels = $diffCount');
  }
}
