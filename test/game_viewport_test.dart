import 'dart:math' as math;

import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const controlKey = ValueKey('canvas-control');
  const screenKey = ValueKey('full-screen');

  Widget app({
    required ValueChanged<MediaQueryData> onMedia,
    EdgeInsets safe = EdgeInsets.zero,
    EdgeInsets keyboard = EdgeInsets.zero,
  }) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.5),
            viewPadding: safe,
            padding: EdgeInsets.fromLTRB(safe.left, safe.top, safe.right,
                math.max(0, safe.bottom - keyboard.bottom)),
            viewInsets: keyboard,
          ),
          child: GameViewport(child: child!),
        ),
        home: Builder(builder: (context) {
          onMedia(MediaQuery.of(context));
          return Scaffold(
            key: screenKey,
            backgroundColor: Colors.teal,
            body: SafeArea(
                child: Stack(children: [
              Positioned(
                left: 64,
                top: 72,
                width: 160,
                height: 48,
                child: FilledButton(
                  key: controlKey,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (context) {
                      onMedia(MediaQuery.of(context));
                      return Scaffold(
                        body: Center(
                          child: TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) {
                                onMedia(MediaQuery.of(context));
                                return const AlertDialog(
                                  content: Text('dialog'),
                                );
                              },
                            ),
                            child: const Text('open dialog'),
                          ),
                        ),
                      );
                    }),
                  ),
                  child: const Text('next'),
                ),
              ),
            ])),
          );
        }),
      );

  void setDisplay(WidgetTester tester, Size pixels, double pixelRatio) {
    tester.view.devicePixelRatio = pixelRatio;
    tester.view.physicalSize = pixels;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final display in <(Size, double)>[
    (const Size(640, 360), 1),
    (const Size(800, 360), 1),
    (const Size(1280, 720), 1),
    (const Size(2340, 1080), 3),
    (const Size(2560, 1600), 2),
    (const Size(1592, 826), 1), // Reported phone screenshot.
    (const Size(1920, 1080), 2.5),
    (const Size(360, 640), 1),
  ]) {
    testWidgets('preserves layout and taps on ${display.$1} at ${display.$2}x',
        (tester) async {
      setDisplay(tester, display.$1, display.$2);
      late MediaQueryData media;
      await tester.pumpWidget(app(onMedia: (value) => media = value));

      final screen = display.$1 / display.$2;
      final scale = math.min(screen.width / 960, screen.height / 540);
      final canvas = screen / scale;
      final rect = tester.getRect(find.byKey(controlKey));
      expect(rect.left, closeTo(64 * scale, .01));
      expect(rect.top, closeTo(72 * scale, .01));
      expect(rect.width, closeTo(160 * scale, .01));
      expect(rect.height, closeTo(48 * scale, .01));
      expect(tester.getRect(find.byKey(screenKey)),
          rectMoreOrLessEquals(Offset.zero & screen, epsilon: .01));
      expect(media.size, canvas);
      expect(media.textScaler.scale(20), 20);
      expect(media.devicePixelRatio, closeTo(display.$2 * scale, .001));
      expect(tester.takeException(), isNull);

      // Navigation and dialog overlays inherit the same canvas and tap mapping.
      await tester.tap(find.byKey(controlKey));
      await tester.pumpAndSettle();
      expect(find.text('open dialog'), findsOneWidget);
      expect(media.size, canvas);
      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      expect(media.size, canvas);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('background fills cutout edges while controls remain safe',
      (tester) async {
    setDisplay(tester, const Size(800, 360), 1);
    late MediaQueryData media;
    await tester.pumpWidget(app(
      safe: const EdgeInsets.only(left: 32, right: 12),
      onMedia: (value) => media = value,
    ));
    final rect = tester.getRect(find.byKey(controlKey));
    expect(rect.left, closeTo(32 + 64 * 2 / 3, .01));
    expect(rect.top, closeTo(72 * 2 / 3, .01));
    expect(tester.getRect(find.byKey(screenKey)),
        const Rect.fromLTWH(0, 0, 800, 360));
    expect(media.padding.left, closeTo(48, .01));
    expect(media.viewPadding.right, closeTo(18, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard insets use canvas coordinates without zooming the game',
      (tester) async {
    setDisplay(tester, const Size(1280, 800), 1);
    late MediaQueryData media;
    await tester.pumpWidget(app(onMedia: (value) => media = value));
    final before = tester.getRect(find.byKey(controlKey));
    await tester.pumpWidget(app(
      keyboard: const EdgeInsets.only(bottom: 300),
      onMedia: (value) => media = value,
    ));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(controlKey)), before);
    expect(media.viewInsets.bottom, closeTo(225, .01));
    expect(media.size, const Size(960, 600));
    expect(tester.takeException(), isNull);
  });
}
