import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/auth/auth_gate.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:challenge_land/screens/splash/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/full_screen_artwork.dart';
import 'package:challenge_land/widgets/game_viewport.dart';

class _User implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountState extends ChangeNotifier implements AppState {
  @override
  User? user;
  @override
  bool authStateLoaded = false;
  @override
  bool characterStateLoaded = false;
  @override
  bool get isAccountReady =>
      authStateLoaded && (user == null || characterStateLoaded);
  @override
  bool get isOnline => false;
  @override
  bool get hasChosenCharacter => false;
  @override
  int get selectedCharacterIndex => -1;
  @override
  int get level => 1;
  @override
  int get coins => 500;
  @override
  int get gems => 10;
  @override
  bool get isVip => false;
  @override
  int get xpInCurrentLevel => 0;
  @override
  int get xpNeededForLevel => 100;
  @override
  bool get economyLoaded => false;
  @override
  EconomyWallet get economyWallet => const EconomyWallet();
  @override
  GameCharacter get selectedCharacter =>
      CharacterCatalog.byIndex(CharacterCatalog.defaultIndex);
  @override
  bool get dailyStreakLoaded => false;
  @override
  bool get claimedToday => false;
  @override
  int get streakDay => 0;
  @override
  bool isCharacterUnlocked(GameCharacter character) => true;

  void changed() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NativeBridge extends NativeBridgeService {
  @override
  bool get supportsAnimatedCharacters => false;
  @override
  Future<Uint8List?> getCharacterArtwork(int index) async => null;
}

Widget _gate(_AccountState state, {VoidCallback? onReady}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        Provider<NativeBridgeService>(create: (_) => _NativeBridge()),
      ],
      child: MaterialApp(home: AuthGate(onReady: onReady)),
    );

void main() {
  setUpAll(() async {
    for (final font in ['Baloo', 'NotoSansArabic']) {
      final asset = font == 'Baloo'
          ? 'assets/fonts/baloo.ttf'
          : 'assets/fonts/NotoSansArabic.ttf';
      await (FontLoader(font)..addFont(SharedAssets.bundle.load(asset))).load();
    }
  });

  Future<void> showSplash(
    WidgetTester tester,
    VoidCallback onComplete, {
    Duration duration = const Duration(milliseconds: 1000),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        onComplete: onComplete,
        duration: duration,
      ),
    ));
    await tester.pump();
  }

  testWidgets('displays the new splash artwork and loading bar',
      (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);

    expect(find.byType(SplashPoster), findsOneWidget);
    expect(find.byType(SplashLoadingBar), findsOneWidget);
    expect(find.text('جاري تجهيز التحديات...'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.byKey(const ValueKey('splash-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-presenter')), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(completions, 0);

    // Let animation complete
    await tester.pump(const Duration(milliseconds: 1100));
    expect(completions, 1);
  });

  for (final (size, safe) in artworkDisplays) {
    testWidgets('splash fills the entire window at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'Baloo', fontFamilyFallback: const ['NotoSansArabic']),
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(padding: safe, viewPadding: safe),
          child: GameViewport(child: child!),
        ),
        home: RepaintBoundary(key: boundaryKey, child: const SplashScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.getRect(find.byKey(const ValueKey('splash-artwork'))),
          rectMoreOrLessEquals(Offset.zero & size));
      final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
      final presenter =
          tester.getRect(find.byKey(const ValueKey('splash-presenter')));
      for (final rect in [logo, presenter]) {
        expect(rect.left, greaterThanOrEqualTo(safe.left - .01));
        expect(rect.top, greaterThanOrEqualTo(safe.top - .01));
        expect(rect.right, lessThanOrEqualTo(size.width - safe.right + .01));
        expect(rect.bottom, lessThanOrEqualTo(size.height + .01));
      }
      expect(logo.width / logo.height, closeTo(996 / 644, .001));
      expect(presenter.width / presenter.height, closeTo(984 / 1160, .001));
      expect(logo.right, lessThan(presenter.left));
      final loading = tester.getRect(find.byType(SplashLoadingBar));
      expect(logo.bottom, lessThan(loading.top));
      expect(loading.left, greaterThanOrEqualTo(safe.left));
      expect(loading.right, lessThanOrEqualTo(size.width - safe.right));
      expect(loading.bottom, lessThanOrEqualTo(size.height - safe.bottom));
      await checkArtworkEdges(tester, boundaryKey,
          'splash-${size.width.toInt()}x${size.height.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('animates progress bar to 100% and completes once',
      (tester) async {
    var completions = 0;
    await showSplash(
      tester,
      () => completions++,
      duration: const Duration(milliseconds: 1000),
    );

    expect(find.text('0%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('100%'), findsOneWidget);
    expect(completions, 1);

    // Further pumping does not re-trigger completion
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('backgrounding pauses the loading progress', (tester) async {
    var completions = 0;
    await showSplash(
      tester,
      () => completions++,
      duration: const Duration(milliseconds: 2000),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(completions, 0);

    // Pause app
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Time passes while paused
    await tester.pump(const Duration(seconds: 5));
    expect(completions, 0);

    // Resume app
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Finish remaining animation
    await tester.pump(const Duration(milliseconds: 1600));
    expect(completions, 1);
  });

  testWidgets('intro stays visible until account data is ready then fades',
      (tester) async {
    final account = _AccountState();
    var readyCalls = 0;
    await tester.pumpWidget(_gate(account, onReady: () => readyCalls++));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(readyCalls, 0);

    // Let splash finish its animation
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();

    // Still on splash because account is not ready yet
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(readyCalls, 0);

    // Mark account ready
    account.authStateLoaded = true;
    account.changed();
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsNothing);
    expect(readyCalls, 1);
  });

  testWidgets(
      'ready account waits for the splash loading bar before revealing screen',
      (tester) async {
    final account = _AccountState()..authStateLoaded = true;
    await tester.pumpWidget(_gate(account));
    await tester.pump();

    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Allow splash animation to finish
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('signed-in account resolves character selection under the splash',
      (tester) async {
    final account = _AccountState()
      ..authStateLoaded = true
      ..user = _User();
    await tester.pumpWidget(_gate(account));
    await tester.pump();

    // Splash is active
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CharacterSelectScreen), findsNothing);

    // Splash completes
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();

    // Character state becomes loaded
    account.characterStateLoaded = true;
    account.changed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CharacterSelectScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
