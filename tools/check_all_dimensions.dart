import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final dir = Directory('assets/categories');
  final map = <String, int>{};

  for (final f in dir.listSync()) {
    if (f is File && f.path.endsWith('.png')) {
      final bytes = f.readAsBytesSync();
      final image = img.decodePng(bytes);
      if (image != null) {
        final dim = '${image.width}x${image.height}';
        map[dim] = (map[dim] ?? 0) + 1;
        if (dim != '352x352' && dim != '352x311') {
          print('${f.path}: $dim');
        }
      }
    }
  }

  print('Dimension distribution: $map');
}
