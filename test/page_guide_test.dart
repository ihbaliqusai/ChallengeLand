import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/screens/campaign/campaign_map_screen.dart';
import 'package:challenge_land/screens/campaign/stage_play_screen.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:challenge_land/widgets/guide/home_guide_tour_overlay.dart';
import 'package:challenge_land/widgets/guide/page_guide.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MapState extends ChangeNotifier implements AppState {
  @override
  get currentUser => null;
  @override
  bool get economyLoaded => true;
  @override
  EconomyWallet get economyWallet => const EconomyWallet(dailyHearts: 3);
  @override
  Future<void> loadEconomy() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MapNative extends NativeBridgeService {
  @override
  Future<void> playCampaignMapMusic() async {}
  @override
  Future<void> stopCampaignMapMusic() async {}
  @override
  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async =>
      null;
}

Future<void> _settleStep(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GUIDE_PREVIEW')) return;
  await tester.tap(find.byKey(const ValueKey('guide-speech-bubble')));
  await tester.pump();
  final images = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toSet();
  await tester.runAsync(() => Future.wait(
      images.map((image) => precacheImage(image, key.currentContext!))));
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final snapshot = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    snapshot.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(SharedAssets.bundle.load(font.value)))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final id in ['modes', 'campaign', 'store', 'characters']) {
    testWidgets('$id introduction appears once and can be replayed',
        (tester) async {
      final guide = GlobalKey<PageGuideState>();
      Future<void> mount() => tester.pumpWidget(MaterialApp(
              home: PageGuide(
            key: guide,
            id: id,
            steps: const [
              GuideStep(
                  title: 'شرح الصفحة',
                  text: 'اختر الزر الذي تريد معرفة وظيفته.')
            ],
            child: Scaffold(
                body: Center(
                    child: PageGuideHelpButton(
                        onPressed: () => guide.currentState?.start()))),
          )));
      await mount();
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsOneWidget);
      expect(find.text('جرّب التحدي مجانًا'), findsNothing);
      expect(find.text('المتابعة بحساب Google'), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
          tester
              .widget<FadeTransition>(
                  find.byKey(const ValueKey('guide-speech-visibility')))
              .opacity
              .value,
          1);
      await tester.tap(find.text('ابدأ الاستكشاف'));
      await _settleStep(tester);
      expect(
          (await SharedPreferences.getInstance())
              .getBool(PageGuide.preferenceKey(id)),
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount();
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      await tester.tap(find.byTooltip('شرح الصفحة'));
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsOneWidget);
      await tester.tap(find.byTooltip('تخطي الجولة'));
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'campaign guide covers controls on phone and tablet without launching',
      (tester) async {
    for (final size in [
      const Size(960, 540),
      const Size(640, 360),
      const Size(390, 780)
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wallet = _MapState();
      SharedPreferences.setMockInitialValues(
          {PageGuide.preferenceKey('campaign'): true});
      final previewKey = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: wallet),
            Provider<NativeBridgeService>.value(value: _MapNative()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark()
                    .textTheme
                    .apply(fontFamily: 'NotoSansArabic')),
            builder: (_, child) => RepaintBoundary(
                key: previewKey, child: GameViewport(child: child!)),
            home: CampaignMapScreen(
                campaignService:
                    CampaignService(firestore: FakeFirebaseFirestore())),
          )));
      await _settleStep(tester);
      expect(find.byTooltip('شرح الصفحة'), findsNothing);
      tester.state<PageGuideState>(find.byType(PageGuide)).start();
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsOneWidget);
      final tour = tester
          .widget<HomeGuideTourOverlay>(find.byType(HomeGuideTourOverlay));
      for (var index = 0; index < tour.steps.length; index++) {
        await _settleStep(tester);
        expect(tester.takeException(), isNull, reason: tour.steps[index].title);
        final speechScroll = tester.state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('guide-speech-bubble')),
                matching: find.byType(Scrollable))
            .first);
        expect(speechScroll.position.maxScrollExtent, lessThanOrEqualTo(1),
            reason:
                '${tour.steps[index].title}: the short explanation must fit');
        final painter = tester
            .widget<CustomPaint>(find.byKey(const ValueKey('guide-spotlight')))
            .painter! as SpotlightPainter;
        if (tour.steps[index].targetKey != null) {
          expect(painter.targetRect, isNotNull,
              reason: tour.steps[index].title);
          final surface = tester.renderObject<RenderBox>(
              find.byKey(const ValueKey('guide-spotlight')));
          final visible = Rect.fromPoints(
              surface.localToGlobal(painter.targetRect!.topLeft),
              surface.localToGlobal(painter.targetRect!.bottomRight));
          expect(
              tester
                  .getRect(find.byKey(const ValueKey('guide-stage')))
                  .overlaps(visible),
              isFalse,
              reason: tour.steps[index].title);
        }
        await _capture(
            tester, previewKey, 'campaign-guide-${size.width.toInt()}-$index');
        await tester.tap(find.text(index == tour.steps.length - 1
            ? 'ابدأ رحلتك'
            : index == 0
                ? 'ابدأ الجولة'
                : 'التالي'));
        await tester.pump();
      }
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      expect(find.byType(StagePlayScreen), findsNothing);
      expect(find.byTooltip('شرح الصفحة'), findsNothing);
      tester.state<PageGuideState>(find.byType(PageGuide)).start();
      await _settleStep(tester);
      expect(find.byType(HomeGuideTourOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      wallet.dispose();
      expect(tester.takeException(), isNull);
    }
  });
}
