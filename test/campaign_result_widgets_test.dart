import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/campaign/widgets/result_bottom_actions.dart';
import 'package:challenge_land/screens/campaign/widgets/animated_result_stars.dart';
import 'package:challenge_land/screens/campaign/widgets/result_replay_goal_card.dart';
import 'package:challenge_land/screens/campaign/widgets/result_reward_panel.dart';
import 'package:challenge_land/screens/campaign/widgets/result_ribbon_header.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StageSubmissionResult _result({
  bool completed = false,
  int attemptStars = 0,
  int bestStars = 3,
  int score = 300,
  int previousScore = 700,
  int coins = 0,
}) {
  final stage = CampaignDefaults.stages().first;
  final previous = StageProgress.empty().copyWith(
    stageId: stage.id,
    bestScore: previousScore,
    stars: bestStars,
    attempts: 1,
  );
  return StageSubmissionResult(
    attempt: StageAttempt.fromMap({
      'attemptId': 'attempt-test',
      'stageId': stage.id,
      'uid': 'user-test',
      'score': score,
      'completed': completed,
      'stars': attemptStars,
    }),
    previousProgress: previous,
    updatedProgress: previous.copyWith(bestScore: score, attempts: 2),
    previousStars: bestStars,
    newStars: bestStars,
    isFirstCompletion: false,
    improvedBestScore: score > previousScore,
    improvedStars: false,
    leaderboardUpdated: completed,
    rewardGranted: coins > 0,
    rewardCoinsGranted: coins,
    rewardGemsGranted: 0,
    rewardXpGranted: 0,
    motivationalMessage: '',
  );
}

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('failed replay still shows settled gameplay XP and trophy loss',
      (tester) async {
    await tester.pumpWidget(_host(ResultRewardPanel(
      result: _result(completed: false),
      currencyRewardApplied: false,
      gameplayXp: 53,
      trophyDelta: -18,
    )));
    expect(find.textContaining('+53 XP من اللعب', findRichText: true), findsOneWidget);
    expect(find.textContaining('-18 كأس', findRichText: true), findsOneWidget);
    expect(find.text('تقدم اللعب المحتسب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed replay keeps attempt stars separate from best stars',
      (tester) async {
    await tester.pumpWidget(_host(ResultReplayGoalCard(
      stage: CampaignDefaults.stages().first,
      result: _result(),
    )));
    expect(find.text('نجوم المحاولة: 0 / 3'), findsOneWidget);
    expect(find.text('أفضل نجوم: 3 / 3'), findsOneWidget);
    expect(find.textContaining('بقيت'), findsOneWidget);
    expect(find.textContaining('أتقنت المرحلة'), findsNothing);
  });

  testWidgets('personal record shows the previous score and improvement',
      (tester) async {
    await tester.pumpWidget(_host(ResultReplayGoalCard(
      stage: CampaignDefaults.stages().first,
      result: _result(
          completed: true,
          attemptStars: 2,
          bestStars: 2,
          score: 1000,
          previousScore: 800),
    )));
    expect(find.text('رقم شخصي جديد!'), findsOneWidget);
    expect(find.text('أفضل رقم سابق: 800'), findsOneWidget);
    expect(find.text('تحسّن النقاط: +200'), findsOneWidget);
    expect(find.textContaining('إلى 3 نجوم'), findsOneWidget);
  });

  testWidgets('boss failure gives a win goal instead of a score shortcut',
      (tester) async {
    await tester.pumpWidget(_host(ResultReplayGoalCard(
      stage: CampaignDefaults.stages()[9],
      result: _result(score: 3000),
    )));
    expect(find.text('هدفك القادم: المركز الأول أمام جميع الزعماء.'),
        findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('result cards fit narrow RTL screens with larger text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_host(
        Column(children: [
          ResultReplayGoalCard(
              stage: CampaignDefaults.stages().first,
              result: _result(
                  completed: true,
                  attemptStars: 2,
                  bestStars: 2,
                  score: 1000,
                  previousScore: 800)),
          ResultRewardPanel(
              result: _result(coins: 100),
              currencyRewardApplied: true,
              onDoubleReward: () {}),
          ResultBottomActions(onMap: () {}, onRetry: () {}, onNext: () {}),
        ]),
        textScale: 1.8));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('next-stage button opens next while replay remains available',
      (tester) async {
    var next = 0;
    var retry = 0;
    await tester.pumpWidget(_host(ResultBottomActions(
      onMap: () {},
      onRetry: () => retry++,
      onNext: () => next++,
    )));
    await tester.tap(find.text('المرحلة التالية'));
    await tester.tap(find.text('تحسين النجوم'));
    expect(next, 1);
    expect(retry, 1);
  });

  testWidgets('reward doubling waits for the base currency to be applied',
      (tester) async {
    await tester.pumpWidget(_host(ResultRewardPanel(
      result: _result(coins: 100),
      currencyRewardApplied: false,
      onDoubleReward: () {},
    )));
    expect(find.textContaining('ضاعف العملات'), findsNothing);
    expect(find.text('محفوظة'), findsOneWidget);
  });

  testWidgets('stars use the result card width on a tablet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_host(const Center(
      child: SizedBox(
          width: 580,
          child: ResultRibbonHeader(child: AnimatedResultStars(stars: 3))),
    )));
    await tester.pump(const Duration(seconds: 2));
    final stars = find.descendant(
        of: find.byType(AnimatedResultStars),
        matching: find.byWidgetPredicate((widget) =>
            widget is Positioned &&
            widget.right == null &&
            widget.bottom == null));
    expect(stars, findsNWidgets(3));
    final center = tester.widget<Positioned>(stars.at(1));
    expect(center.left, 580 / 2 - 108 / 2);
    expect(tester.takeException(), isNull);
  });
}
