import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/campaign/stage_result_screen.dart';
import 'package:challenge_land/screens/campaign/widgets/result_score_counter.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Player implements User {
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
  int currencyClaims = 0;
  @override
  User? get currentUser => _Player();
  @override
  int get coins => 100;
  @override
  Future<bool> grantCampaignCurrency({
    required int coinsReward,
    required int gemsReward,
    String? claimId,
  }) async {
    currencyClaims++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Native extends NativeBridgeService {
  final haptics = <String>[];
  @override
  Future<bool> playHaptic({String style = 'light'}) async {
    haptics.add(style);
    return true;
  }
}

class _Campaign extends CampaignService {
  _Campaign() : super(firestore: FakeFirebaseFirestore());
  @override
  Future<List<CampaignStage>> loadStages(
          {String campaignId = 'main_campaign'}) async =>
      CampaignDefaults.stages(campaignId: campaignId).take(1).toList();
}

Widget _scoreHost({required int score, bool reducedMotion = false}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(body: ResultScoreCounter(score: score)),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('millionaire/native'),
            (call) async =>
                call.method == 'getCharacterState' ? {'selected': 1} : null);
  });

  testWidgets(
      'score respects reduced motion without scheduling count-up frames',
      (tester) async {
    await tester.pumpWidget(_scoreHost(score: 1400, reducedMotion: true));
    expect(find.text('1400'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_scoreHost(score: 2400, reducedMotion: true));
    expect(find.text('2400'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('score semantics announce the final value while digits count up',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_scoreHost(score: 1400));
    expect(find.text('0'), findsOneWidget);
    expect(find.bySemanticsLabel('النقاط: 1400'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel('النقاط: 1400'), findsOneWidget);
    expect(find.text('1400'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1400'), findsOneWidget);
    semantics.dispose();
  });

  for (final enabled in [false, true]) {
    testWidgets('settled reward collection respects haptic=$enabled once',
        (tester) async {
      final wallet = _Wallet();
      final native = _Native();
      final settings = AppSettings(native)..haptic = enabled;
      final platformHaptics = <MethodCall>[];
      // Catch a raw HapticFeedback call that bypasses AppSettings.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') platformHaptics.add(call);
        return null;
      });
      final stage = CampaignDefaults.stages().first;
      final result = StageSubmissionResult(
        attempt: StageAttempt.fromMap({
          'uid': 'player',
          'attemptId': 'collected-result',
          'stageId': stage.id,
          'completed': true,
          'stars': 1,
          'score': 1400,
        }),
        updatedProgress: StageProgress.empty().copyWith(stars: 1),
        previousStars: 0,
        newStars: 1,
        isFirstCompletion: true,
        improvedBestScore: true,
        improvedStars: true,
        leaderboardUpdated: false,
        rewardGranted: true,
        rewardCoinsGranted: 100,
        rewardGemsGranted: 5,
        rewardXpGranted: 30,
        motivationalMessage: '',
      );
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: wallet),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: StageResultScreen(
            stage: stage,
            submissionResult: result,
            currencyRewardApplied: true,
            campaignService: _Campaign(),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('victory-collect')));
      await tester.pump();
      expect(native.haptics, enabled ? ['medium'] : isEmpty);
      expect(platformHaptics, isEmpty);
      expect(wallet.currencyClaims, 0,
          reason: 'Already settled rewards are never paid a second time.');
      await tester.tap(find.byKey(const ValueKey('victory-collect')));
      await tester.pump();
      expect(native.haptics, enabled ? ['medium'] : isEmpty);
      expect(wallet.currencyClaims, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      settings.dispose();
      wallet.dispose();
      AppSettings.instance = null;
      expect(tester.takeException(), isNull);
    });
  }
}
