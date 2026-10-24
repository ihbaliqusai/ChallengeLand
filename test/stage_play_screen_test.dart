import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/campaign/stage_play_screen.dart';
import 'package:challenge_land/screens/campaign/stage_result_screen.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends ChangeNotifier implements AppState {
  @override
  User? get currentUser => null;
  @override
  int get coins => 100;
  @override
  Future<void> loadEconomy() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final stage = CampaignDefaults.stages()[8];
  late List<MethodCall> launches;
  Map<String, dynamic>? result;
  bool failLaunch = false;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await (FontLoader('Baloo')
          ..addFont(SharedAssets.bundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(
              SharedAssets.bundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launches = [];
    result = null;
    failLaunch = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launchCampaignStage') {
        launches.add(call);
        if (failLaunch) throw PlatformException(code: 'LAUNCH_FAILED');
        return true;
      }
      if (call.method == 'consumePendingCampaignStageResult') {
        final pending = result;
        result = null;
        return pending;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> openStage(WidgetTester tester,
      {int attempts = 0, bool continuingJourney = false}) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _Wallet()),
        Provider<NativeBridgeService>(create: (_) => NativeBridgeService()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Baloo', fontFamilyFallback: const ['NotoSansArabic']),
        home: Builder(builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => StagePlayScreen(
                  stage: stage,
                  progress: StageProgress.empty().copyWith(attempts: attempts),
                  continuingJourney: continuingJourney,
                ),
              )),
              child: const Text('المرحلة'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('المرحلة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> returnFromNative(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stage tap starts native play once without stage details',
      (tester) async {
    await openStage(tester);
    expect(launches, hasLength(1));
    final config = launches.single.arguments as Map;
    expect(config['campaignEntry'], 'stage');
    expect(config['stageId'], stage.id);
    expect(config['campaignMode'], 'board');
    expect(config['boardTargetScore'], stage.boardTargetScore);
    expect(config['boardAllowRevealOptions'], stage.boardAllowRevealOptions);
    expect(config['boardSoloPicks'], stage.boardSoloPicks);
    expect(config['timeLimitSeconds'], stage.timeLimitSeconds);
    expect(find.text('ابدأ المرحلة'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(launches, hasLength(1));
  });

  testWidgets('replaying a stage preserves retry entry', (tester) async {
    await openStage(tester, attempts: 3);
    expect((launches.single.arguments as Map)['campaignEntry'], 'retry');
  });

  testWidgets('continuing starts the next stage immediately', (tester) async {
    await openStage(tester, continuingJourney: true);
    expect((launches.single.arguments as Map)['campaignEntry'], 'next');
    expect(find.text('ابدأ المرحلة'), findsNothing);
  });

  testWidgets('launch failure returns to map with an error', (tester) async {
    failLaunch = true;
    await openStage(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StagePlayScreen), findsNothing);
    expect(find.text('تعذر بدء المرحلة. حاول مرة أخرى.'), findsOneWidget);
  });

  testWidgets('missing native result returns to map instead of hanging',
      (tester) async {
    await openStage(tester);
    await returnFromNative(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StagePlayScreen), findsNothing);
    expect(find.text('لم تصل نتيجة المرحلة. حاول بدء المرحلة مرة أخرى.'),
        findsOneWidget);
  });

  testWidgets('native result replaces the launch route with stage result',
      (tester) async {
    await openStage(tester);
    result = {
      'mode': 'campaign',
      'accountUid': 'guest_local',
      'campaignId': stage.campaignId,
      'stageId': stage.id,
      'attemptId': 'direct-play-result',
      'campaignBoard': true,
      'completed': true,
      'score': stage.boardTargetScore,
      'correctAnswers': 5,
      'wrongAnswers': 0,
      'timeMs': 10000,
    };
    await returnFromNative(tester);
    expect(find.byType(StageResultScreen), findsOneWidget);
    expect(find.byType(StagePlayScreen), findsNothing);
    expect(launches, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
