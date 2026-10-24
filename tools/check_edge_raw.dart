import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_raw.png');
  final image = img.decodePng(file.readAsBytesSync())!;
  print('edge_raw.png is ${image.width}x${image.height}');
}
