import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/campaign/stage_result_screen.dart';
import 'package:challenge_land/screens/campaign/widgets/animated_result_stars.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_result_handler.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User implements User {
  @override
  String get uid => 'player';
  @override
  String? get displayName => 'لاعب';
  @override
  String? get email => null;
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallet extends ChangeNotifier implements AppState {
  User? account = _User();
  final refresh = Completer<void>();
  int refreshes = 0;
  @override
  User? get currentUser => account;
  @override
  int get coins => 100;
  @override
  Future<void> loadEconomy() {
    refreshes++;
    return refresh.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Native extends NativeBridgeService {
  _Native(this.payload);
  Map<String, dynamic>? payload;
  @override
  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async {
    final result = payload;
    payload = null;
    return result;
  }
}

class _SlowCampaign extends CampaignService {
  _SlowCampaign() : super(firestore: FakeFirebaseFirestore());
  Completer<StageSubmissionResult> submission = Completer();
  int submissions = 0;
  int stageLoads = 0;
  @override
  Future<StageSubmissionResult> submitStageResult({
    required String uid,
    required CampaignStage stage,
    required Map<String, dynamic> nativeResult,
    String displayName = '',
    String? photoUrl,
  }) {
    submissions++;
    return submission.future;
  }

  @override
  Future<List<CampaignStage>> loadStages(
      {String campaignId = 'main_campaign'}) async {
    stageLoads++;
    return CampaignDefaults.stages(campaignId: campaignId);
  }
}

void main() {
  final stage = CampaignDefaults.stages().first;
  late _SlowCampaign campaign;
  late _Wallet wallet;
  late BuildContext launchContext;

  Map<String, dynamic> payload() => {
        'mode': 'campaign',
        'accountUid': 'player',
        'attemptId': 'attempt',
        'campaignId': stage.campaignId,
        'stageId': stage.id,
        'campaignBoard': true,
        'completed': true,
        'score': stage.boardTargetScore,
        'correctAnswers': 3,
        'wrongAnswers': 0,
        'timeMs': 10000,
      };

  StageSubmissionResult saved() => StageSubmissionResult(
        attempt:
            StageAttempt.fromMap({...payload(), 'uid': 'player', 'stars': 1}),
        updatedProgress: StageProgress.empty().copyWith(
          campaignId: stage.campaignId,
          stageId: stage.id,
          stars: 1,
          status: StageProgressStatus.completed,
        ),
        previousStars: 0,
        newStars: 1,
        isFirstCompletion: true,
        improvedBestScore: true,
        improvedStars: true,
        leaderboardUpdated: true,
        rewardGranted: false,
        rewardCoinsGranted: 0,
        rewardGemsGranted: 0,
        rewardXpGranted: 0,
        motivationalMessage: 'أحسنت!',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('millionaire/native'), (_) async => null);
  });

  Future<void> openResult(WidgetTester tester) async {
    campaign = _SlowCampaign();
    wallet = _Wallet();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: wallet),
        Provider<NativeBridgeService>.value(value: _Native(payload())),
      ],
      child: MaterialApp(home: Builder(builder: (context) {
        launchContext = context;
        return const Scaffold(body: Text('مرحلة'));
      })),
    ));
    expect(
        await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
          context: launchContext,
          knownStage: stage,
          service: campaign,
        ),
        isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> close(WidgetTester tester) async {
    if (!wallet.refresh.isCompleted) wallet.refresh.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    wallet.dispose();
  }

  testWidgets('result paints behind the cutout while keeping controls safe',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.padding = const FakeViewPadding(left: 102);
    tester.view.viewPadding = const FakeViewPadding(left: 102);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await openResult(tester);
    expect(tester.getRect(find.byKey(const ValueKey('victory-background'))),
        const Rect.fromLTWH(0, 0, 1600, 720));
    expect(tester.getRect(find.text('تفاصيل المرحلة')).left,
        greaterThanOrEqualTo(102));
    campaign.submission.complete(saved());
    await close(tester);
  });

  testWidgets('result appears before cloud save and wallet refresh finish',
      (tester) async {
    await openResult(tester);
    expect(find.byType(StageResultScreen), findsOneWidget);
    expect(find.byType(AnimatedResultStars), findsOneWidget);
    expect(find.text('جارٍ الحفظ...'), findsOneWidget);
    expect(find.text('جارٍ استلام نتيجة المرحلة...'), findsNothing);
    expect(campaign.stageLoads, 0,
        reason: 'the launched stage is already available');
    expect(campaign.submissions, 1);
    final starsState = tester.state(find.byType(AnimatedResultStars));
    campaign.submission.complete(saved());
    await tester.pump();
    await tester.pump();
    expect(find.text('جارٍ الحفظ...'), findsNothing);
    expect(find.text('المرحلة التالية'), findsOneWidget);
    expect(wallet.refreshes, 1);
    expect(wallet.refresh.isCompleted, isFalse);
    expect(tester.state(find.byType(AnimatedResultStars)), same(starsState));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('failed background save keeps result visible and allows retry',
      (tester) async {
    await openResult(tester);
    campaign.submission.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AnimatedResultStars), findsOneWidget);
    expect(find.text('جارٍ الحفظ...'), findsNothing);
    final retry = find.text('إعادة حفظ النتيجة');
    expect(retry, findsOneWidget);
    campaign.submission = Completer();
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(campaign.submissions, 2);
    campaign.submission.complete(saved());
    await tester.pump();
    expect(find.text('إعادة حفظ النتيجة'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('account change while saving prevents old wallet delivery',
      (tester) async {
    await openResult(tester);
    wallet.account = null;
    campaign.submission.complete(saved());
    await tester.pump();
    expect(wallet.refreshes, 0);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('leaving the result does not cancel its saved reward delivery',
      (tester) async {
    await openResult(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    campaign.submission.complete(saved());
    await tester.pump();
    expect(wallet.refreshes, 1);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
