import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/screens/auth/login_bottom_sheet.dart';
import 'package:challenge_land/screens/campaign/stage_result_screen.dart';
import 'package:challenge_land/screens/campaign/widgets/save_guest_progress_dialog.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/widgets/sign_in_required_action.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Player implements User {
  @override
  String get uid => 'demo-player';
  @override
  String get displayName => 'لاعب';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Wallet extends ChangeNotifier implements AppState {
  User? account;
  Object? signInError;
  int logins = 0, balance = 0, earnedXp = 0;
  final currencyClaims = <String?>{}, xpClaims = <String?>{};
  @override
  User? get user => account;
  @override
  User? get currentUser => account;
  @override
  bool get isOnline => true;
  @override
  bool get isBusy => false;
  @override
  int get coins => balance;
  @override
  Future<void> signInWithGoogle() async {
    logins++;
    if (signInError != null) throw signInError!;
    account = _Player();
    notifyListeners();
  }

  @override
  Future<void> loadEconomy() async {}
  @override
  Future<bool> grantCampaignCurrency(
      {required int coinsReward,
      required int gemsReward,
      String? claimId}) async {
    if (currencyClaims.add(claimId)) balance += coinsReward;
    return true;
  }

  @override
  Future<bool> grantCampaignXp({required int xpReward, String? claimId}) async {
    if (xpClaims.add(claimId)) earnedXp += xpReward;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _stage = CampaignDefaults.stages().first;
final _payload = <String, dynamic>{
  'attemptId': 'demo-attempt',
  'completed': true,
  'campaignId': _stage.campaignId,
  'stageId': _stage.id,
  'score': 1400,
  'stars': 1
};

StageSubmissionResult _result(String uid) => StageSubmissionResult(
    attempt: StageAttempt.fromMap({..._payload, 'uid': uid}),
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
    motivationalMessage: 'أحسنت!',
    rewardClaimId: uid.isEmpty ? null : 'demo-reward');

class _Campaign extends CampaignService {
  _Campaign() : this._(FakeFirebaseFirestore());
  _Campaign._(this.database) : super(firestore: database);
  final FakeFirebaseFirestore database;
  int saves = 0;
  Map<String, dynamic>? savedPayload;
  @override
  Future<StageSubmissionResult> submitStageResult(
      {required String uid,
      required CampaignStage stage,
      required Map<String, dynamic> nativeResult,
      String displayName = '',
      String? photoUrl}) async {
    saves++;
    savedPayload = Map.from(nativeResult);
    await database.doc('users/$uid/campaignRewardClaims/demo-reward').set({
      'uid': uid,
      'campaignId': stage.campaignId,
      'stageId': stage.id,
      'status': 'pending',
      'coins': 100,
      'gems': 5,
      'xp': 30,
      'currencyClaimed': false,
      'xpClaimed': false,
    });
    return _result(uid);
  }

  @override
  Future<List<CampaignStage>> loadStages(
          {String campaignId = 'main_campaign'}) async =>
      [_stage];
}

void main() {
  final previewKey = GlobalKey();
  late _Wallet wallet;
  late _Campaign campaign;
  setUpAll(() async {
    for (final font in {
      'Baloo': 'assets/fonts/baloo.ttf',
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(SharedAssets.bundle.load(font.value)))
          .load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('millionaire/native'),
            (call) async =>
                call.method == 'getCharacterState' ? {'selected': 1} : null);
    wallet = _Wallet();
    campaign = _Campaign();
  });
  tearDown(() => wallet.dispose());

  Future<void> openRewards(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: wallet,
        child: MaterialApp(
            theme: ThemeData(
                fontFamily: 'Baloo',
                fontFamilyFallback: const ['NotoSansArabic']),
            builder: (_, child) =>
                RepaintBoundary(key: previewKey, child: child!),
            home: StageResultScreen(
                stage: _stage,
                submissionResult: _result(''),
                rawNativeResult: _payload,
                campaignService: campaign))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('victory-collect')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('returning without collecting opens sign-in from a home action',
      (tester) async {
    var actions = 0;
    await tester.binding.setSurfaceSize(const Size(800, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: wallet,
        child: MaterialApp(
            theme: ThemeData(
                fontFamily: 'Baloo',
                fontFamilyFallback: const ['NotoSansArabic']),
            home: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      const Text('الشاشة الرئيسية'),
                      SignInRequiredAction(
                          child: TextButton(
                              onPressed: () => actions++,
                              child: const Text('المتجر'))),
                      TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => StageResultScreen(
                                      stage: _stage,
                                      submissionResult: _result(''),
                                      rawNativeResult: _payload,
                                      campaignService: campaign))),
                          child: const Text('نتيجة التجربة')),
                    ]))))));
    await tester.tap(find.text('نتيجة التجربة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('victory-collect')), findsOneWidget);
    await tester.tap(find.text('الخريطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('متابعة دون حفظ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StageResultScreen), findsNothing);
    expect(find.byType(LoginBottomSheet), findsNothing);
    expect(campaign.saves, 0);
    await tester.tapAt(tester.getCenter(find.text('المتجر')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginBottomSheet), findsOneWidget);
    expect(find.byType(SaveGuestProgressDialog), findsNothing);
    expect(find.text('جرّب التحدي مجانًا'), findsNothing);
    expect(find.text('المتابعة بحساب Google'), findsNothing);
    expect(
        find.byKey(const ValueKey('login-privacy-checkbox')), findsOneWidget);
    expect(actions, 0);
    expect(wallet.balance, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'collecting demo rewards opens the original Google and privacy sheet',
      (tester) async {
    await openRewards(tester);
    expect(find.byType(LoginBottomSheet), findsOneWidget);
    expect(find.byType(SaveGuestProgressDialog), findsNothing);
    expect(find.text('تسجيل دخول بواسطة جوجل'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('login-privacy-checkbox')), findsOneWidget);
    await tester.runAsync(() => precacheImage(
        AssetImage('assets/ui/google.png', bundle: SharedAssets.bundle),
        tester.element(find.byType(LoginBottomSheet))));
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/demo-reward-login.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(wallet.logins, 0);
    expect(campaign.saves, 0);
    expect(find.text('يرجى الموافقة على سياسة الخصوصية أولاً'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-login-sheet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StageResultScreen), findsOneWidget);
    expect(find.byType(LoginBottomSheet), findsNothing);
    expect(campaign.saves, 0);
    await tester.tap(find.byKey(const ValueKey('victory-collect')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginBottomSheet), findsOneWidget);
    expect(wallet.balance, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Google cancellation keeps demo rewards and retry saves and collects them',
      (tester) async {
    await openRewards(tester);
    await tester.tap(find.byKey(const ValueKey('login-privacy-checkbox')));
    await tester.pump();
    wallet.signInError = FirebaseAuthException(code: 'cancelled');
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(find.byType(LoginBottomSheet), findsOneWidget);
    expect(campaign.saves, 0);
    wallet.signInError = null;
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginBottomSheet), findsNothing);
    expect(campaign.saves, 1);
    expect(campaign.savedPayload, _payload);
    expect(wallet.balance, 100);
    expect(wallet.earnedXp, 30);
    expect(find.text('تم جمع المكافآت ✓'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
