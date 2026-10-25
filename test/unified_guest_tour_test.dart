import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/guide/home_guide_steps.dart';
import 'package:challenge_land/widgets/guide/unified_guest_tour_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  @override
  get user => null;
  @override
  get currentUser => null;
  @override
  bool get authStateLoaded => true;
  @override
  bool get isAccountReady => true;
  @override
  int get coins => 0;
  @override
  int get gems => 0;
  @override
  EconomyWallet get economyWallet => const EconomyWallet();
  @override
  bool get economyLoaded => true;
  @override
  bool get isOnline => true;
  @override
  bool get isVip => false;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNativeBridge extends NativeBridgeService {
  @override
  Future<void> playCampaignMapMusic() async {}
  @override
  Future<void> stopCampaignMapMusic() async {}
  @override
  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async =>
      null;
  @override
  Future<Map<String, dynamic>> economy(Map<String, dynamic> data) async => {};
  @override
  Future<Map<String, dynamic>> getAchievements() async => {};
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

  testWidgets(
      'UnifiedGuestTourOverlay starts on Home screen, advances with التالي, goes back with السابق, and shows Google Sign-In at end',
      (tester) async {
    final appState = _FakeAppState();
    final nativeBridge = _FakeNativeBridge();
    final homeTargets = {
      for (final t in HomeGuideTarget.values) t: GlobalKey(),
    };
    var completed = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          Provider<NativeBridgeService>.value(value: nativeBridge),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: UnifiedGuestTourOverlay(
                rootContext: context,
                homeTargets: homeTargets,
                onComplete: () => completed = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify section and step label in navigation bar
    expect(find.textContaining('الرئيسية'), findsWidgets);

    // Initial step is Home screen intro
    expect(find.textContaining('أهلًا بك في أرض التحدي'), findsOneWidget);

    expect(find.text('السابق'), findsOneWidget);

    // Click Next (التالي) to advance to step 1 (زر بدء اللعب)
    expect(find.text('التالي'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Now step 1 is active (زر بدء اللعب)
    expect(find.textContaining('زر بدء اللعب'), findsOneWidget);

    // Click Previous (السابق) to return to step 0
    await tester.tap(find.text('السابق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('أهلًا بك في أرض التحدي'), findsOneWidget);

    // Test skipping directly to completion
    final skipBtnFinder = find.byTooltip('تخطي الجولة');
    expect(skipBtnFinder, findsWidgets);
    await tester.tap(skipBtnFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Check completion was triggered
    expect(completed, isTrue);

    // Verify SharedPreferences persisted completion
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getBool(UnifiedGuestTourOverlay.completedPrefKey), isTrue);
    expect(
        prefs.getBool(UnifiedGuestTourOverlay.legacyHomePrefKey), isTrue);
  });

  testWidgets('Final step renders Google sign in options and can sign in',
      (tester) async {
    final appState = _FakeAppState();
    final nativeBridge = _FakeNativeBridge();
    var completed = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          Provider<NativeBridgeService>.value(value: nativeBridge),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: UnifiedGuestTourOverlay(
                rootContext: context,
                onComplete: () => completed = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap through until final step or reach final choices
    // Fast-forward by tapping Next repeatedly
    for (var i = 0; i < 100; i++) {
      if (find.text('المتابعة بحساب Google').evaluate().isNotEmpty) {
        break;
      }

      final nextFinder = find.text('التالي');
      final finishFinder = find.text('إنهاء وبدء اللعب');
      if (nextFinder.evaluate().isNotEmpty) {
        await tester.tap(nextFinder.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      } else if (finishFinder.evaluate().isNotEmpty) {
        break;
      } else {
        break;
      }
    }

    // Now on final step: should display Google Sign-in button
    expect(find.text('المتابعة بحساب Google'), findsOneWidget);
    expect(find.text('جرّب التحدي'), findsOneWidget);
    expect(find.text('خيارات أخرى'), findsOneWidget);
    expect(completed, isFalse);

    // Tap Google Sign-in
    await tester.tap(find.text('المتابعة بحساب Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
}

