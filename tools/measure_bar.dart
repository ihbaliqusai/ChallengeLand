import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\khaleeji_drama_transparent.png');
  final image = img.decodePng(file.readAsBytesSync())!;

  int minX = 999, maxX = -1, minY = 999, maxY = -1;
  for (int y = 260; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      final p = image.getPixel(x, y);
      // text is white
      if (p.r > 200 && p.g > 200 && p.b > 200 && p.a > 100) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Khaleeji text bounding box: X=[$minX, $maxX], Y=[$minY, $maxY], width=${maxX - minX + 1}, height=${maxY - minY + 1}');

  // Also sample teal bar color around the text
  final barColor = image.getPixel(176, 275);
  print('Teal bar color at (176, 275): R=${barColor.r}, G=${barColor.g}, B=${barColor.b}');
}
