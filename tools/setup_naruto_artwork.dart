import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('=== Setting up Naruto Artwork Card ===');

  final rawPath = r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_naruto_raw.png';
  final rawFile = File(rawPath);
  if (!rawFile.existsSync()) {
    throw Exception('Raw image not found: $rawPath');
  }

  final rawImg = img.decodeImage(rawFile.readAsBytesSync())!;
  print('Raw image size: ${rawImg.width}x${rawImg.height}');

  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  final maskImg = img.decodeImage(maskFile.readAsBytesSync())!;
  print('Mask image size: ${maskImg.width}x${maskImg.height}');

  // Resize raw to 352x352 if needed
  img.Image baseImg = rawImg;
  if (rawImg.width != 352 || rawImg.height != 352) {
    baseImg = img.copyResize(rawImg, width: 352, height: 352, interpolation: img.Interpolation.linear);
  }

  // Apply squircle alpha mask
  final output = img.Image(width: 352, height: 352, numChannels: 4);
  int zeroAlphaCount = 0;

  for (int y = 0; y < 352; y++) {
    for (int x = 0; x < 352; x++) {
      final pBase = baseImg.getPixel(x, y);
      final pMask = maskImg.getPixel(x, y);
      final maskAlpha = pMask.a;

      output.setPixelRgba(
        x,
        y,
        pBase.r.toInt(),
        pBase.g.toInt(),
        pBase.b.toInt(),
        maskAlpha.toInt(),
      );

      if (maskAlpha == 0) {
        zeroAlphaCount++;
      }
    }
  }

  print('Zero alpha count: $zeroAlphaCount');
  print('Top-Left Alpha: ${output.getPixel(0, 0).a}');
  print('Top-Right Alpha: ${output.getPixel(351, 0).a}');
  print('Bottom-Left Alpha: ${output.getPixel(0, 351).a}');
  print('Bottom-Right Alpha: ${output.getPixel(351, 351).a}');

  if (zeroAlphaCount != 24541) {
    print('WARNING: Zero alpha count is $zeroAlphaCount, expected 24541');
  }

  final pngBytes = img.encodePng(output);

  // Save to assets/categories/Naruto.png
  final flutterAsset = File('assets/categories/Naruto.png');
  flutterAsset.writeAsBytesSync(pngBytes);
  print('Saved Flutter asset: ${flutterAsset.path} (${flutterAsset.lengthSync()} bytes)');

  // Save to android/app/src/main/assets/categories/Naruto.png
  final androidAsset = File('android/app/src/main/assets/categories/Naruto.png');
  androidAsset.writeAsBytesSync(pngBytes);
  print('Saved Android asset: ${androidAsset.path} (${androidAsset.lengthSync()} bytes)');

  // Save artifact copy
  final artifactCopy = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\naruto_transparent.png');
  artifactCopy.writeAsBytesSync(pngBytes);
  print('Saved artifact copy: ${artifactCopy.path} (${artifactCopy.lengthSync()} bytes)');

  print('=== Naruto Artwork Completed Successfully ===');
}
