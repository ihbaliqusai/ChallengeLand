import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/models/campaign_daily_progress.dart';
import 'package:challenge_land/screens/campaign/widgets/campaign_journey_panel.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();
  final stage = CampaignDefaults.stages()[2];
  const daily = CampaignDailyProgress(
    dayKey: '2026-10-03',
    attempts: 1,
    wins: 1,
    stars: 2,
    activityDays: ['2026-09-29', '2026-10-01', '2026-10-03'],
  );

  setUpAll(() async {
    final font = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Widget harness(Widget child, {double textScale = 1}) => MaterialApp(
        theme: ThemeData(
            fontFamily: 'NotoSansArabic',
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF10283E))),
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                    backgroundColor: const Color(0xFF10283E),
                    body: RepaintBoundary(
                        key: boundaryKey,
                        child: ColoredBox(
                            color: const Color(0xFF10283E), child: child))))),
      );

  for (final scenario in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'small', size: const Size(320, 568), scale: 1.0),
    (name: 'landscape', size: const Size(760, 360), scale: 1.0),
    (name: 'large_text', size: const Size(320, 640), scale: 1.8),
  ]) {
    testWidgets('daily journey remains usable on ${scenario.name}',
        (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var launched = false;
      await tester.pumpWidget(harness(
          CampaignJourneySheet(
            daily: daily,
            worldName: 'غابة البداية',
            worldStars: 12,
            worldMaxStars: 30,
            recommendedStage: stage,
            now: DateTime(2026, 10, 3),
            onRecommendedTap: () => launched = true,
          ),
          textScale: scenario.scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('العب جولتين'), findsOneWidget);
      final start = find.text('ابدأ تحدي اليوم');
      await tester.ensureVisible(start);
      await tester.tap(start);
      expect(launched, isTrue);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAMPAIGN_PREVIEW')) {
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, 1800));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final snapshot = await boundary.toImage(pixelRatio: 2);
          final bytes =
              await snapshot.toByteData(format: ui.ImageByteFormat.png);
          final file =
              File('build/campaign_review/journey_${scenario.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          snapshot.dispose();
        });
      }
    });
  }

  testWidgets('continue and daily buttons remain separate and reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var continued = 0;
    var openedDaily = 0;
    await tester.pumpWidget(harness(
        Padding(
            padding: const EdgeInsets.all(14),
            child: CampaignJourneyBar(
                daily: daily,
                continueStage: stage,
                onContinue: () => continued++,
                onDailyTap: () => openedDaily++)),
        textScale: 1.8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('العب المرحلة 3'));
    await tester.tap(find.text('رحلة اليوم 1/3'));
    expect(continued, 1);
    expect(openedDaily, 1);
  });
}
