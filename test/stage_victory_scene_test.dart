import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/campaign/widgets/animated_result_stars.dart';
import 'package:challenge_land/screens/campaign/widgets/stage_victory_scene.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/full_screen_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final stage = CampaignDefaults.stages().first;
  final boundaryKey = GlobalKey();

  StageSubmissionResult result({Map<String, dynamic> values = const {}}) =>
      StageSubmissionResult(
        attempt: StageAttempt.fromMap({
          'attemptId': 'victory-preview',
          'uid': 'player',
          'completed': true,
          'stars': 3,
          'score': 1400,
          ...values,
        }),
        updatedProgress: StageProgress.empty().copyWith(stars: 3),
        previousStars: 0,
        newStars: 3,
        isFirstCompletion: true,
        improvedBestScore: true,
        improvedStars: true,
        leaderboardUpdated: true,
        rewardGranted: true,
        rewardCoinsGranted: 100,
        rewardGemsGranted: 5,
        rewardXpGranted: 30,
        motivationalMessage: '',
      );

  setUpAll(() async {
    for (final font in ['Baloo', 'NotoSansArabic', 'MaterialIcons']) {
      final asset = switch (font) {
        'Baloo' => 'assets/fonts/baloo.ttf',
        'NotoSansArabic' => 'assets/fonts/NotoSansArabic.ttf',
        _ => 'fonts/MaterialIcons-Regular.otf',
      };
      await (FontLoader(font)..addFont(SharedAssets.bundle.load(asset))).load();
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('millionaire/native'),
            (call) async =>
                call.method == 'getCharacterState' ? {'selected': 1} : null);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(960, 540),
    EdgeInsets safe = EdgeInsets.zero,
    bool saving = false,
    bool doubled = false,
    VoidCallback? onCollect,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'Baloo', fontFamilyFallback: const ['NotoSansArabic']),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: safe, viewPadding: safe),
        child: GameViewport(child: child!),
      ),
      home: Scaffold(
          body: RepaintBoundary(
        key: boundaryKey,
        child: StageVictoryScene(
          stage: stage,
          result: result(),
          playerName: 'msa3ed alfouzan',
          gameplayXp: 15,
          saving: saving,
          isDoubled: doubled,
          onCollect: onCollect ?? () {},
          onMap: () {},
          onRetry: () {},
          onDetails: () {},
          onNext: () {},
        ),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  for (final (size, safe) in [
    ...artworkDisplays,
    (const Size(360, 640), EdgeInsets.zero),
  ]) {
    testWidgets('victory artwork and controls fit $size', (tester) async {
      var collected = 0;
      await mount(tester, size: size, safe: safe, onCollect: () => collected++);
      expect(find.text('هدف المرحلة'), findsOneWidget);
      expect(find.byType(AnimatedResultStars), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('victory-background'))),
          rectMoreOrLessEquals(Offset.zero & size));
      final safeBounds = Rect.fromLTRB(safe.left, safe.top,
          size.width - safe.right, size.height - safe.bottom);
      final collect =
          tester.getRect(find.byKey(const ValueKey('victory-collect')));
      expect(safeBounds.contains(collect.topLeft), isTrue);
      expect(safeBounds.contains(collect.bottomRight), isTrue);
      await checkArtworkEdges(tester, boundaryKey,
          'victory-${size.width.toInt()}x${size.height.toInt()}');
      await tester.tap(find.byKey(const ValueKey('victory-collect')));
      expect(collected, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('saving prevents collection and doubling preserves XP',
      (tester) async {
    var collected = 0;
    await mount(tester, saving: true, onCollect: () => collected++);
    await tester.tap(find.byKey(const ValueKey('victory-collect')));
    expect(collected, 0);
    expect(find.text('جارٍ الحفظ...'), findsOneWidget);
    await mount(tester, doubled: true);
    expect(find.text('+200'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+45'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('score comparison uses each mode and never invents an opponent', () {
    final solo = VictoryScoreSummary(stage: stage, attempt: result().attempt);
    expect(solo.otherName, 'هدف المرحلة');
    expect(solo.otherScore, stage.boardTargetScore);
    expect(solo.isCompetition, isFalse);
    final series = VictoryScoreSummary(
        stage: stage,
        attempt: result(values: {
          'campaignMode': CampaignMode.series.value,
          'playerSeriesWins': 3,
          'opponentSeriesWins': 1,
          'opponentName': 'وسيم',
        }).attempt);
    expect((series.playerScore, series.otherScore, series.otherName),
        (3, 1, 'وسيم'));
    final team = VictoryScoreSummary(
        stage: stage,
        attempt: result(values: {
          'campaignMode': CampaignMode.teamBattle.value,
          'teamScore': 2700,
          'enemyTeamScore': 1800,
        }).attempt);
    expect((team.playerScore, team.otherScore), (2700, 1800));
    final boss = VictoryScoreSummary(
        stage: CampaignDefaults.stages()[9],
        attempt:
            result(values: {'bossScore': 800, 'bossName': 'الزعيم'}).attempt);
    expect(boss.otherScore, 800);
    expect(boss.isCompetition, isTrue);
  });

  testWidgets('render victory preview with the bundled artwork',
      (tester) async {
    final shadows = debugDisableShadows;
    if (const bool.fromEnvironment('VICTORY_PREVIEW')) {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = shadows);
    }
    await mount(tester);
    final context = boundaryKey.currentContext!;
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toSet();
    await tester.runAsync(() =>
        Future.wait(images.map((image) => precacheImage(image, context))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('VICTORY_PREVIEW')) {
      final boundary = context.findRenderObject()! as RenderRepaintBoundary;
      boundary.markNeedsPaint();
      await tester.pump();
      await tester.runAsync(() async {
        final snapshot = await boundary.toImage(pixelRatio: 2);
        final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/stage-victory-preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        snapshot.dispose();
      });
    }
    debugDisableShadows = shadows;
  });
}
