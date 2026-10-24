import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final khaleeji = img.decodePng(File('assets/categories/دراما خليجية.png').readAsBytesSync())!;
  final ucl = img.decodePng(File('assets/categories/دوري أبطال أوروبا.png').readAsBytesSync())!;
  final turk = img.decodePng(File('assets/categories/مسلسلات تركية.png').readAsBytesSync())!;

  print('Khaleeji: ${khaleeji.width}x${khaleeji.height}');
  print('UCL: ${ucl.width}x${ucl.height}');
  print('Turkish: ${turk.width}x${turk.height}');

  // Let's find bounding box of "دراما" in khaleeji (right side: x >= 170)
  int dMinX = 999, dMaxX = 0, dMinY = 999, dMaxY = 0;
  for (int y = 280; y <= 330; y++) {
    for (int x = 160; x <= 285; x++) {
      final p = khaleeji.getPixel(x, y);
      if (p.r > 200 && p.g > 200 && p.b > 200) {
        if (x < dMinX) dMinX = x;
        if (x > dMaxX) dMaxX = x;
        if (y < dMinY) dMinY = y;
        if (y > dMaxY) dMaxY = y;
      }
    }
  }
  print('Word "دراما" bounding box: X=[$dMinX, $dMaxX], Y=[$dMinY, $dMaxY] (width: ${dMaxX - dMinX + 1}, height: ${dMaxY - dMinY + 1})');

  // Let's find bounding box of "دوري" in UCL (right side of UCL title)
  int uMinX = 999, uMaxX = 0, uMinY = 999, uMaxY = 0;
  for (int y = 280; y <= 330; y++) {
    for (int x = 200; x <= 300; x++) {
      final p = ucl.getPixel(x, y);
      if (p.r > 200 && p.g > 200 && p.b > 200) {
        if (x < uMinX) uMinX = x;
        if (x > uMaxX) uMaxX = x;
        if (y < uMinY) uMinY = y;
        if (y > uMaxY) uMaxY = y;
      }
    }
  }
  print('Word "دوري" bounding box: X=[$uMinX, $uMaxX], Y=[$uMinY, $uMaxY] (width: ${uMaxX - uMinX + 1}, height: ${uMaxY - uMinY + 1})');
}
