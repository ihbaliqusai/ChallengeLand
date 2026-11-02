import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:challenge_land/widgets/currency_reward_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> mount(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    bool reduced = false,
    bool accessible = false,
    double textScale = 1,
    TextDirection direction = TextDirection.rtl,
    ValueNotifier<bool>? routeEnabled,
    VoidCallback? onBackgroundTap,
    GlobalKey? boundaryKey,
    ThemeData? theme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late BuildContext source;
    final notifier = routeEnabled ?? ValueNotifier(true);
    if (routeEnabled == null) addTearDown(notifier.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      builder: (context, child) => RepaintBoundary(
        key: boundaryKey,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            accessibleNavigation: accessible,
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
          ),
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF06112D),
        body: ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (context, enabled, child) => TickerMode(
            enabled: enabled,
            child: Builder(builder: (context) {
              source = context;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBackgroundTap,
                child: const SizedBox.expand(),
              );
            }),
          ),
        ),
      ),
    ));
    return source;
  }

  const overlay = ValueKey('currency-reward-overlay');
  const card = ValueKey('currency-reward-card');

  testWidgets('nonpositive inputs do not create a reward or timer',
      (tester) async {
    final context = await mount(tester);
    for (final values in [(0, 0), (-10, 0), (0, -2), (-10, -2)]) {
      showCurrencyRewardOverlay(context, coins: values.$1, gems: values.$2);
    }
    await tester.pump();
    expect(find.byKey(overlay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows exact credited amounts and does not consume taps',
      (tester) async {
    var taps = 0;
    final context = await mount(tester, onBackgroundTap: () => taps++);
    showCurrencyRewardOverlay(context, coins: 1250, gems: 7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('+1250'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-reward-coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-reward-gems')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(card)).dy, greaterThanOrEqualTo(24));
    await tester.tapAt(const Offset(100, 80));
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(overlay), findsNothing);
  });

  testWidgets('only positive currencies appear and normal animation cleans up',
      (tester) async {
    final context = await mount(tester, direction: TextDirection.ltr);
    showCurrencyRewardOverlay(context, coins: -50, gems: 3);
    await tester.pump();
    expect(find.text('Reward added to your balance'), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-reward-coins')), findsNothing);
    expect(find.text('+3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.byKey(overlay), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(overlay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion is stationary and still has finite cleanup',
      (tester) async {
    final context = await mount(tester, reduced: true);
    showCurrencyRewardOverlay(context, coins: 90, gems: 0);
    await tester.pump();
    final position = tester.getTopLeft(find.byKey(card));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.byKey(card)), position);
    expect(find.text('+90'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(overlay), findsNothing);
  });

  testWidgets(
      'accessible navigation announces amounts with a longer static hold',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final context = await mount(tester, accessible: true);
    showCurrencyRewardOverlay(context, coins: 600, gems: 4);
    await tester.pump();
    expect(find.bySemanticsLabel('تمت إضافة 600 عملة و4 جوهرة إلى رصيدك'),
        findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.byKey(card), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(overlay), findsNothing);
    semantics.dispose();
  });

  testWidgets('hidden origin route pauses presentation and expires offscreen',
      (tester) async {
    final route = ValueNotifier(true);
    addTearDown(route.dispose);
    final context = await mount(tester, routeEnabled: route);
    showCurrencyRewardOverlay(context, coins: 60, gems: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    route.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(card), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    route.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(card), findsOneWidget);
    route.value = false;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(overlay, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background app pauses and resume restores the current reward',
      (tester) async {
    final context = await mount(tester);
    showCurrencyRewardOverlay(context, coins: 10, gems: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(card), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(card), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(overlay), findsNothing);
  });

  testWidgets('removing the source route removes its reward immediately',
      (tester) async {
    final home = await mount(tester, reduced: true);
    late BuildContext source;
    final route = PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          Scaffold(body: Builder(builder: (context) {
        source = context;
        return const SizedBox.expand();
      })),
    );
    Navigator.of(home).push(route);
    await tester.pumpAndSettle();
    showCurrencyRewardOverlay(source, coins: 35, gems: 0);
    await tester.pump();
    expect(find.byKey(card), findsOneWidget);
    Navigator.of(source).removeRoute(route);
    await tester.pumpAndSettle();
    expect(find.byKey(overlay, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source page removed before first overlay build is safe',
      (tester) async {
    final home = await mount(tester, reduced: true);
    late BuildContext source;
    final route = PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          Scaffold(body: Builder(builder: (context) {
        source = context;
        return const SizedBox.expand();
      })),
    );
    Navigator.of(home).push(route);
    await tester.pumpAndSettle();
    showCurrencyRewardOverlay(source, coins: 35, gems: 0);
    Navigator.of(source).removeRoute(route);
    await tester.pumpAndSettle();
    expect(find.byKey(overlay, skipOffstage: false), findsNothing);
    await tester.pump(const Duration(seconds: 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim dialog reward survives its immediate dialog close',
      (tester) async {
    final home = await mount(tester, reduced: true);
    late BuildContext source;
    showDialog<void>(
      context: home,
      builder: (context) {
        source = context;
        return const AlertDialog(content: Text('Claim'));
      },
    );
    await tester.pumpAndSettle();
    showCurrencyRewardOverlay(source, coins: 80, gems: 1);
    Navigator.of(source).pop();
    await tester.pumpAndSettle();
    expect(find.text('+80'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(overlay), findsNothing);
  });

  testWidgets('overlay host removed before first reward build is safe',
      (tester) async {
    final context = await mount(tester);
    showCurrencyRewardOverlay(context, coins: 25, gems: 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount cancels timers, ticker listeners and animation',
      (tester) async {
    final context = await mount(tester);
    showCurrencyRewardOverlay(context, coins: 1, gems: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'large text and long RTL amounts fit narrow and landscape windows',
      (tester) async {
    for (final size in [const Size(240, 640), const Size(640, 240)]) {
      final context =
          await mount(tester, size: size, textScale: 3, reduced: true);
      showCurrencyRewardOverlay(context, coins: 900000000000, gems: 88888888);
      await tester.pump();
      expect(find.text('+900000000000'), findsOneWidget);
      expect(find.text('+88888888'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(card));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      await tester.pump(const Duration(seconds: 5));
    }
  });
  testWidgets('exports the original coded reward preview', (tester) async {
    final loader = FontLoader('RewardPreviewArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await loader.load();
    final key = GlobalKey();
    final context = await mount(tester,
        size: const Size(440, 280),
        boundaryKey: key,
        theme: ThemeData(fontFamily: 'RewardPreviewArabic'));
    showCurrencyRewardOverlay(context, coins: 250, gems: 12);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = File('docs/original_motion_20261102/reward_preview.png');
      await path.parent.create(recursive: true);
      await path.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('WRITE_REWARD_PREVIEW'));
}
