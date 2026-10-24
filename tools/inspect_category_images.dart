import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final f = File('assets/categories/مسلسلات عربية.png');
  if (f.existsSync()) {
    final i = img.decodePng(f.readAsBytesSync())!;
    print('مسلسلات عربية.png: ${i.width}x${i.height}, channels: ${i.numChannels}');
  } else {
    print('مسلسلات عربية.png not found');
  }

  final khaleeji = File('assets/categories/دراما خليجية.png');
  if (khaleeji.existsSync()) {
    final i = img.decodePng(khaleeji.readAsBytesSync())!;
    print('دراما خليجية.png: ${i.width}x${i.height}');
  }
}
