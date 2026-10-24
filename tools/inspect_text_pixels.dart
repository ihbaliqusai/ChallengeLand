import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final khaleeji = img.decodePng(File('assets/categories/دراما خليجية.png').readAsBytesSync())!;
  print('Khaleeji card: ${khaleeji.width}x${khaleeji.height}');

  for (int y = 270; y <= 330; y += 5) {
    String row = '';
    for (int x = 60; x <= 290; x += 3) {
      final p = khaleeji.getPixel(x, y);
      row += (p.r > 200 && p.g > 200 && p.b > 200) ? '#' : '.';
    }
    print('$y: $row');
  }
}
