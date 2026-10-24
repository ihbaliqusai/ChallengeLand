import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render Syrian Drama card with TextPainter', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final fontData = File('assets/fonts/baloo.ttf').readAsBytesSync();
    final fontLoader = FontLoader('Baloo');
    fontLoader.addFont(Future.value(fontData.buffer.asByteData()));
    await fontLoader.load();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 352, 352));

    // Load background image
    final bgBytes = File('assets/categories/مسلسلات عربية.png').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bgBytes);
    final frame = await codec.getNextFrame();
    final bgImage = frame.image;

    // Draw background image
    canvas.drawImage(bgImage, Offset.zero, Paint());

    // Cover the bottom bar text area with solid dark teal #1A5A59
    final tealPaint = Paint()..color = const Color(0xFF1A5A59);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(20, 268, 312, 70),
        bottomLeft: const Radius.circular(30),
        bottomRight: const Radius.circular(30),
      ),
      tealPaint,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'دراما سورية',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Baloo',
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    print('Text dimensions: ${tp.width} x ${tp.height}');

    // The teal bar vertical center is: 268 + 70/2 = 303.
    final textY = 303 - (tp.height / 2) - 2; // subtle visual optical centering
    final textX = (352 - tp.width) / 2;

    tp.paint(canvas, Offset(textX, textY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(352, 352);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    File('tools/test_syrian_card.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('Rendered tools/test_syrian_card.png with TextPainter successfully!');
  });
}
