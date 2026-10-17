import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:challenge_land/widgets/home_menu_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Baloo')
          ..addFont(rootBundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  final calls = <String>[];
  setUp(calls.clear);
  Future<void> mount(WidgetTester tester,
      {Size size = const Size(800, 360),
      bool online = true,
      bool badges = false,
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Baloo',
              fontFamilyFallback: const ['NotoSansArabic'])),
      home: MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
            backgroundColor: const Color(0xFF100B36),
            body: Center(
                child: SizedBox(
                    width: math.min(size.width - 24,
                        (size.height - 24) * HomeMenuArtwork.aspectRatio),
                    child: HomeMenuArtwork(
                      username: 'لاعب التحدي',
                      rankTitle: 'مستكشف',
                      rankColor: const Color(0xFF94A3B8),
                      photoUrl: null,
                      isOnline: online,
                      dailyReady: online && badges,
                      pendingRewards: badges ? 12 : 0,
                      ratingEntry: const SizedBox.shrink(),
                      onProfile: () => calls.add('profile'),
                      onClose: () => calls.add('close'),
                      onLeaderboard: () => calls.add('leaderboard'),
                      onRewards: () => calls.add('rewards'),
                      onStats: () => calls.add('stats'),
                      onAchievements: () => calls.add('achievements'),
                      onSettings: () => calls.add('settings'),
                      onUnavailable: () => calls.add('offline'),
                    )))),
      ),
    ));
    await tester.runAsync(() => precacheImage(
        const AssetImage(HomeMenuArtwork.asset),
        tester.element(find.byType(HomeMenuArtwork))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('all supplied menu controls retain their own actions',
      (tester) async {
    await mount(tester);
    for (final entry in {
      'الملف الشخصي': 'profile',
      'إغلاق': 'close',
      'الصدارة': 'leaderboard',
      'المكافآت': 'rewards',
      'الإحصائيات': 'stats',
      'الإنجازات': 'achievements',
      'الإعدادات': 'settings',
    }.entries) {
      await tester.tap(find.byTooltip(entry.key));
      expect(calls.last, entry.value);
    }
    expect(calls.length, 7);
    expect(find.text('لاعب التحدي'), findsOneWidget);
    expect(find.text('مستكشف'), findsOneWidget);
    expect(find.text('Qusai'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline menu gates online actions and retains reward badges',
      (tester) async {
    await mount(tester, online: false, badges: true);
    await tester.tap(find.byTooltip('الصدارة'));
    await tester.tap(find.byTooltip('المكافآت'));
    expect(calls, ['offline', 'offline']);
    await tester.tap(find.byTooltip('الإحصائيات'));
    expect(calls.last, 'stats');
    expect(find.text('9+'), findsOneWidget);
    await mount(tester, badges: true);
    expect(find.text('!'), findsOneWidget);
  });

  for (final size in [
    const Size(800, 360),
    const Size(640, 320),
    const Size(390, 780)
  ]) {
    testWidgets('menu fits $size with live profile data', (tester) async {
      await mount(tester, size: size, textScale: size.width == 640 ? 1.5 : 1);
      final artwork = find.byKey(const ValueKey('home-menu-artwork'));
      final bounds = tester.getRect(artwork);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      for (final label in [
        'إغلاق',
        'الصدارة',
        'المكافآت',
        'الإحصائيات',
        'الإنجازات',
        'الإعدادات'
      ]) {
        final target = tester.getRect(find.byTooltip(label));
        expect(bounds.contains(target.center), isTrue);
        expect(target.shortestSide, greaterThanOrEqualTo(48));
      }
      if (size.width != 640) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(artwork);
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          final name = size.width == 800 ? 'landscape' : 'mobile';
          await Directory('build').create(recursive: true);
          await File('build/home-menu-$name-ar.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.tap(find.byTooltip('إغلاق'));
      expect(calls, ['close']);
    });
  }
}
