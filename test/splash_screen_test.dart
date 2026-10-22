import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/auth/auth_gate.dart';
import 'package:challenge_land/screens/auth/offline_welcome_screen.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:challenge_land/screens/splash/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  bool isCharacterUnlocked(GameCharacter character) => true;

  void changed() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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

  testWidgets('displays the new splash artwork and loading bar', (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);

    expect(find.byType(SplashPoster), findsOneWidget);
    expect(find.byType(SplashLoadingBar), findsOneWidget);
    expect(find.text('جاري تجهيز التحديات...'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    expect(completions, 0);

    // Let animation complete
    await tester.pump(const Duration(milliseconds: 1100));
    expect(completions, 1);
  });

  testWidgets('animates progress bar to 100% and completes once', (tester) async {
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
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: account,
      child: MaterialApp(home: AuthGate(onReady: () => readyCalls++)),
    ));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OfflineWelcomeScreen), findsNothing);
    expect(readyCalls, 0);

    // Let splash finish its animation
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();

    // Still on splash because account is not ready yet
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OfflineWelcomeScreen), findsNothing);
    expect(readyCalls, 0);

    // Mark account ready
    account.authStateLoaded = true;
    account.changed();
    await tester.pump();
    await tester.pump();

    expect(find.byType(OfflineWelcomeScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsNothing);
    expect(readyCalls, 1);
  });

  testWidgets('ready account waits for the splash loading bar before revealing screen',
      (tester) async {
    final account = _AccountState()..authStateLoaded = true;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: account,
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pump();

    expect(find.byType(OfflineWelcomeScreen), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Allow splash animation to finish
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(OfflineWelcomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('signed-in account resolves character selection under the splash',
      (tester) async {
    final account = _AccountState()
      ..authStateLoaded = true
      ..user = _User();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: account,
      child: const MaterialApp(home: AuthGate()),
    ));
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
