import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:challenge_land/widgets/game_modes_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  final calls = <String>[];
  setUp(calls.clear);

  Future<void> mount(WidgetTester tester,
      {Size size = const Size(800, 360),
      bool online = true,
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
                backgroundColor: const Color(0xFF100B36),
                body: Center(
                    child: SizedBox(
                        width: math.min(size.width - 24,
                            (size.height - 24) * GameModesArtwork.aspectRatio),
                        child: GameModesArtwork(
                            isOnline: online,
                            onClose: () => calls.add('close'),
                            onMainChallenge: () => calls.add('main'),
                            onGroupChallenge: () => calls.add('group'),
                            onFriendChallenge: () => calls.add('friend'),
                            onOffline: () => calls.add('offline'),
                            onUnavailable: () =>
                                calls.add('unavailable'))))))));
    await tester.runAsync(() => precacheImage(
        const AssetImage(GameModesArtwork.asset),
        tester.element(find.byType(GameModesArtwork))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('all mode artwork controls invoke their matching actions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester);
    for (final entry in {
      'إغلاق': 'close',
      'التحدي الرئيسي': 'main',
      'تحدي جماعي': 'group',
      'تحدي صديق': 'friend',
      'أوفلاين': 'offline'
    }.entries) {
      await tester.tap(find.byTooltip(entry.key));
      expect(calls.last, entry.value);
      expect(find.bySemanticsLabel(entry.key), findsOneWidget);
    }
    expect(calls.length, 5);
    semantics.dispose();
  });

  testWidgets(
      'offline players can start local modes and online modes are gated',
      (tester) async {
    await mount(tester, online: false);
    await tester.tap(find.byTooltip('تحدي جماعي'));
    await tester.tap(find.byTooltip('تحدي صديق'));
    expect(calls, ['unavailable', 'unavailable']);
    await tester.tap(find.byTooltip('التحدي الرئيسي'));
    await tester.tap(find.byTooltip('أوفلاين'));
    expect(calls.skip(2), ['main', 'offline']);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
  });

  for (final size in [
    const Size(800, 360),
    const Size(640, 320),
    const Size(390, 780)
  ]) {
    testWidgets('complete game modes panel fits $size', (tester) async {
      await mount(tester, size: size, textScale: size.width == 640 ? 1.5 : 1);
      final artwork = find.byKey(const ValueKey('game-modes-artwork'));
      final bounds = tester.getRect(artwork);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      final targets = <Rect>[];
      for (final label in [
        'إغلاق',
        'التحدي الرئيسي',
        'تحدي جماعي',
        'تحدي صديق',
        'أوفلاين'
      ]) {
        final target = tester.getRect(find.byTooltip(label));
        expect(bounds.contains(target.center), isTrue);
        expect(target.shortestSide, greaterThanOrEqualTo(48));
        for (final other in targets) {
          expect(target.overlaps(other), isFalse,
              reason: '$label overlaps another action');
        }
        targets.add(target);
      }
      if (size.width != 640) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(artwork);
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        boundary.markNeedsPaint();
        await tester.pump();
        try {
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await rendered.toByteData(format: ui.ImageByteFormat.png);
            final name = size.width == 800 ? 'landscape' : 'mobile';
            await Directory('build').create(recursive: true);
            await File('build/game-modes-$name-ar.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        } finally {
          debugDisableShadows = previousShadows;
        }
      }
      await tester.tap(find.byTooltip('إغلاق'));
      expect(calls, ['close']);
    });
  }
}
