import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/home/daily_streak_screen.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/daily_reward_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:challenge_land/widgets/weekly_reward_artwork.dart';

class _Rewards extends ChangeNotifier implements AppState {
  @override
  int streakDay = 7;
  @override
  bool claimedToday = false;
  @override
  bool claimingDailyReward = false;
  @override
  String? dailyRewardError;
  Completer<Map<String, int>?>? response;
  int requests = 0;

  @override
  Future<void> loadLevelData() async {}

  @override
  Future<Map<String, int>?> claimDailyStreak() async {
    requests++;
    final result = await response!.future;
    if (result != null) claimedToday = true;
    notifyListeners();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(_Rewards state, Widget child, {double textScale = 1}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider(
            create: (_) => AppSettings(NativeBridgeService())..haptic = false),
      ],
      child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true).copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Baloo',
                  fontFamilyFallback: const ['NotoSansArabic'])),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Baloo', 'assets/fonts/baloo.ttf'),
      ('NotoSansArabic', 'assets/fonts/NotoSansArabic.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  testWidgets('export weekly artwork with live days, rewards and claimed state',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final sample in [
      (size: const Size(1040, 650), day: 1, claimed: false, name: 'desktop'),
      (size: const Size(900, 400), day: 7, claimed: false, name: 'landscape'),
      (size: const Size(900, 400), day: 10, claimed: true, name: 'claimed'),
      (size: const Size(800, 400), day: 30, claimed: true, name: 'last-week'),
      (size: const Size(390, 780), day: 3, claimed: false, name: 'mobile'),
    ]) {
      tester.view.physicalSize = sample.size;
      final state = _Rewards()
        ..streakDay = sample.day
        ..claimedToday = sample.claimed;
      await tester.pumpWidget(_app(state, const DailyRewardDialog()));
      await tester.pump();
      await tester.runAsync(() => precacheImage(
          const AssetImage(weeklyRewardAsset),
          tester.element(find.byType(DailyRewardDialog))));
      await tester.pump();
      expect(find.text('مكافأة اليوم ${sample.day}'),
          sample.claimed ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('weekly-reward-artwork')));
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File('build/weekly-reward-${sample.name}-ar.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    }
  });
  testWidgets(
      'failure shows retry without revealing rewards; repeated taps claim once',
      (tester) async {
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, const DailyRewardDialog()));
    await tester.pump();
    await tester.tap(find.text('افتح واستلم'));
    await tester.pump();
    expect(find.text('جارٍ استلام المكافأة…'), findsOneWidget);
    await tester.tap(find.text('جارٍ استلام المكافأة…'));
    expect(state.requests, 1);
    state.dailyRewardError = 'فشل الاتصال';
    state.response!.complete(null);
    await tester.pump();
    expect(find.text('فشل الاتصال'), findsOneWidget);
    expect(find.text('أُضيفت المكافأة إلى رصيدك!'), findsNothing);
    state.response = Completer();
    await tester.tap(find.text('إعادة المحاولة'));
    state.response!.complete({'coins': 500, 'gems': 3});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('أُضيفت المكافأة إلى رصيدك!'), findsOneWidget);
    expect(find.text('رائع، متابعة'), findsOneWidget);
    expect(state.requests, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the last week shows only days 29 and 30', (tester) async {
    final state = _Rewards()
      ..streakDay = 30
      ..claimedToday = true;
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, const DailyRewardDialog()));
    await tester.pump();
    expect(find.text('اليوم 29'), findsOneWidget);
    expect(find.text('اليوم 30'), findsOneWidget);
    expect(find.text('اليوم 31'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('الصندوق التالي خلال'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 640), const Size(900, 400)]) {
    testWidgets('weekly dialog fits $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards();
      addTearDown(state.dispose);
      await tester
          .pumpWidget(_app(state, const DailyRewardDialog(), textScale: 1.5));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('reward dashboard fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards();
      addTearDown(state.dispose);
      await tester.pumpWidget(_app(state, const DailyStreakScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
