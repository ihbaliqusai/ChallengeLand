import 'package:challenge_land/core/shared_assets.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart'; // ignore: depend_on_referenced_packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/legacy_auth_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/play_stake_dialog.dart';
import 'package:challenge_land/widgets/play_stake_artwork.dart';
import 'package:challenge_land/screens/social/social_screen.dart';

class _SignedOutAuth implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await (FontLoader('Baloo')
          ..addFont(SharedAssets.bundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(SharedAssets.bundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(SharedAssets.bundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  AppState createAppState({int coins = 1500, bool isOnline = true}) {
    final state = AppState(
      authService: _SignedOutAuth(),
      nativeBridgeService: NativeBridgeService(),
    );
    state.coins = coins;
    state.isOnline = isOnline;
    return state;
  }

  Widget buildTestableWidget({
    required AppState appState,
    required Widget child,
    double textScale = 1,
  }) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Baloo', fontFamilyFallback: const ['NotoSansArabic']),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('PlayStakeDialog renders stake tiers and bot difficulty scaling',
      (tester) async {
    final appState = createAppState(coins: 1500);

    await tester.pumpWidget(
      buildTestableWidget(
        appState: appState,
        child: const PlayStakeDialog(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تحدي المواجهة (العب)'), findsOneWidget);
    expect(find.textContaining('رصيدك الحالي: 1500 قطعة'), findsOneWidget);
    expect(find.text('اللعب العشوائي'), findsOneWidget);
    expect(find.text('اللعب ضد خصم من اختيارك'), findsOneWidget);

    // Initial selected stake is 50 -> prize is 100
    expect(find.textContaining('الجائزة للفائز: 100 قطعة'), findsOneWidget);

    // Tap on 5000 tier (which user can't afford since balance is 1500)
    await tester.tap(find.text('5000'));
    await tester.pumpAndSettle();

    // 5000 is selected, bot difficulty scaling is Level 10
    expect(find.textContaining('بطل خارق'), findsOneWidget);
    expect(find.textContaining('مستوى 10'), findsOneWidget);
    expect(find.textContaining('الجائزة للفائز: 10000 قطعة'), findsOneWidget);

    // Tap 0 (مجانية)
    await tester.tap(find.text('مجانية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('متكافئ وتدريبي'), findsOneWidget);
    expect(find.textContaining('مستوى 5'), findsOneWidget);
  });

  testWidgets(
      'PlayStakeDialog triggers random match with stakeCoins via method channel',
      (tester) async {
    final appState = createAppState(coins: 2000);

    int? capturedStake;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launchRandomMatch') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        capturedStake = args?['stakeCoins'] as int?;
        return true;
      }
      return null;
    });

    await tester.pumpWidget(
      buildTestableWidget(
        appState: appState,
        child: const PlayStakeDialog(),
      ),
    );
    await tester.pumpAndSettle();

    // Select 500
    await tester.tap(find.text('500'));
    await tester.pumpAndSettle();

    // Tap Random Match
    await tester.ensureVisible(find.text('اللعب العشوائي'));
    await tester.tap(find.text('اللعب العشوائي'));
    await tester.pumpAndSettle();

    expect(capturedStake, 500);
  });

  testWidgets('PlayStakeDialog blocks match when user has insufficient coins',
      (tester) async {
    final appState = createAppState(coins: 50);

    int? capturedStake;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launchRandomMatch') {
        capturedStake = 999;
        return true;
      }
      return null;
    });

    await tester.pumpWidget(
      buildTestableWidget(
        appState: appState,
        child: const PlayStakeDialog(),
      ),
    );
    await tester.pumpAndSettle();

    // Select 1000 (which is > 50)
    await tester.tap(find.text('1000'));
    await tester.pumpAndSettle();

    // Tap Random Match
    await tester.ensureVisible(find.text('اللعب العشوائي'));
    await tester.tap(find.text('اللعب العشوائي'));
    await tester.pumpAndSettle();

    // Dialog shows snackbar notice and does not launch
    expect(find.textContaining('لا يكفي لهذا الرهان'), findsOneWidget);
    expect(capturedStake, isNull);
  });

  test('SocialScreen accepts and stores initialStake', () {
    const screen = SocialScreen(initialStake: 500);
    expect(screen.initialStake, 500);
  });

  testWidgets('failed native launch keeps the dialog open and retryable',
      (tester) async {
    final appState = createAppState();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launchRandomMatch') {
        throw PlatformException(code: 'UNAVAILABLE', message: 'تعذر الاتصال');
      }
      return null;
    });
    await tester.pumpWidget(buildTestableWidget(
        appState: appState, child: const PlayStakeDialog()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('اللعب العشوائي'));
    await tester.tap(find.text('اللعب العشوائي'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayStakeDialog), findsOneWidget);
    expect(find.textContaining('تعذر بدء البحث'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();
  });

  for (final size in [const Size(360, 640), const Size(640, 320)]) {
    testWidgets('play controls fit $size with larger text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = createAppState();
      await tester.pumpWidget(buildTestableWidget(
          appState: state, child: const PlayStakeDialog(), textScale: 1.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('اللعب ضد خصم من اختيارك'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }

  for (final size in [const Size(430, 932), const Size(844, 390)]) {
    testWidgets('artwork preview and controls remain reachable at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = createAppState();
      const previewKey = ValueKey('play-artwork-preview');
      await tester.pumpWidget(buildTestableWidget(
        appState: state,
        child: const RepaintBoundary(
          key: previewKey,
          child: PlayStakeDialog(),
        ),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage(PlayStakeArtwork.asset),
          tester.element(find.byType(PlayStakeArtwork))));
      await tester.pumpAndSettle();
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(previewKey));
      final orientation = size.width > size.height ? 'landscape' : 'portrait';
      Future<void> capture(String suffix) => tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('build/play-dialog-$orientation$suffix.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
      await capture('');
      await tester.ensureVisible(find.text('اللعب ضد خصم من اختيارك'));
      await tester.pumpAndSettle();
      expect(
          find.text('اللعب ضد خصم من اختيارك').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('-actions');
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }
}
