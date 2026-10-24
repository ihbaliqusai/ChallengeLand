import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const artworkDisplays = [
  (Size(640, 360), EdgeInsets.zero),
  (Size(1592, 826), EdgeInsets.only(left: 116)),
  (Size(1600, 720), EdgeInsets.only(left: 102)),
  (Size(2340, 1080), EdgeInsets.only(right: 133)),
  (Size(2560, 1600), EdgeInsets.zero),
  (Size(1440, 1080), EdgeInsets.zero),
];

/// Inspect rendered pixels so an unpainted margin cannot pass a bounds check.
Future<void> checkArtworkEdges(
    WidgetTester tester, GlobalKey boundaryKey, String name) async {
  final context = boundaryKey.currentContext!;
  final images = tester
      .widgetList<Image>(find.descendant(
          of: find.byKey(boundaryKey), matching: find.byType(Image)))
      .map((image) => image.image)
      .toSet();
  await tester.runAsync(
      () => Future.wait(images.map((image) => precacheImage(image, context))));
  await tester.pump();
  final boundary = context.findRenderObject()! as RenderRepaintBoundary;
  boundary.markNeedsPaint();
  await tester.pump();
  await tester.runAsync(() async {
    final snapshot = await boundary.toImage(
        pixelRatio: tester.view.physicalSize.width / boundary.size.width);
    try {
      final pixels = (await snapshot.toByteData())!;
      for (final x in [0, snapshot.width - 1]) {
        final colors = <int>{};
        for (var sample = 1; sample < 12; sample++) {
          final y = snapshot.height * sample ~/ 12;
          final offset = (y * snapshot.width + x) * 4;
          expect(pixels.getUint8(offset + 3), 255,
              reason: '$name must paint an opaque image at both edges');
          colors.add(pixels.getUint32(offset));
        }
        expect(colors.length, greaterThan(3),
            reason: '$name must not leave a solid vertical side bar');
      }
      if (const bool.fromEnvironment('ARTWORK_PREVIEW')) {
        final png = await snapshot.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/full-screen-artwork/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      }
    } finally {
      snapshot.dispose();
    }
  });
}
