import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Diagnose TextPainter', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 352, 352));

    // Fill background with dark teal
    final tealPaint = Paint()..color = const Color(0xFF1A5A59);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 352, 352), tealPaint);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'دراما سورية',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'NotoSansArabic',
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    print('NotoSansArabic dimensions: ${tp.width} x ${tp.height}');

    // Draw text centered at y=176
    final x = (352 - tp.width) / 2;
    final y = 176 - (tp.height / 2);
    tp.paint(canvas, Offset(x, y));

    // Also draw a red rect around the text box
    final redPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(x, y, tp.width, tp.height), redPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(352, 352);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    File('tools/test_diag_text.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('Wrote tools/test_diag_text.png');
  });
}
