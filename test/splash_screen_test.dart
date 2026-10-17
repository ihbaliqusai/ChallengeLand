import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/auth/auth_gate.dart';
import 'package:challenge_land/screens/auth/offline_welcome_screen.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:challenge_land/screens/splash/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final released = Completer<void>();
  bool initializePlayer = true;
  bool playing = false;
  int created = 0;
  int disposed = 0;
  String? asset;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created++;
    asset = options.dataSource.asset;
    if (initializePlayer) {
      events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1280, 720),
      ));
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
    released.complete();
  }

  @override
  Future<void> play(int playerId) async => playing = true;

  @override
  Future<void> pause(int playerId) async => playing = false;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

void main() {
  late _VideoPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.events.close();
    VideoPlayerPlatform.instance = previous;
  });

  Future<void> showSplash(WidgetTester tester, VoidCallback onComplete) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(onComplete: onComplete),
    ));
    await tester.pump();
  }

  testWidgets('plays the bundled intro once and completes once',
      (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);
    expect(platform.asset, 'assets/videos/splashscreen.mp4');
    expect(platform.playing, isTrue);
    expect(find.byType(VideoPlayer), findsOneWidget);
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    expect(completions, 1);
    expect(platform.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => platform.released.future);
    expect(platform.disposed, 1);
  });

  testWidgets('video fills the screen without skip or loading controls',
      (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);
    expect(find.text('Skip intro'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(completions, 0);
    expect(platform.playing, isTrue);
    expect(find.text('Skip intro'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.cover);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('decoder failure shows the poster and still completes',
      (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);
    platform.events.addError(
      PlatformException(code: 'decoder', message: 'Unsupported codec'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a player that never initializes cannot block startup',
      (tester) async {
    platform.initializePlayer = false;
    var completions = 0;
    await showSplash(tester, () => completions++);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stalled playback has a deadline', (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);
    await tester.pump(const Duration(seconds: 13));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backgrounding pauses video and its deadline', (tester) async {
    var completions = 0;
    await showSplash(tester, () => completions++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(platform.playing, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(completions, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.playing, isTrue);
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing while initialization is pending cancels deadlines',
      (tester) async {
    platform.initializePlayer = false;
    var completions = 0;
    await showSplash(tester, () => completions++);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    await tester.runAsync(() => platform.released.future);
    expect(completions, 0);
    expect(platform.disposed, 1);
    expect(tester.takeException(), isNull);
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
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OfflineWelcomeScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(readyCalls, 0);
    account.authStateLoaded = true;
    account.changed();
    await tester.pump();
    await tester.pump();
    expect(find.byType(OfflineWelcomeScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() => platform.released.future);
    expect(find.byType(SplashScreen), findsNothing);
    expect(platform.created, 1);
    expect(platform.disposed, 1);
    expect(readyCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ready account still waits for the complete intro',
      (tester) async {
    final account = _AccountState()..authStateLoaded = true;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: account,
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pump();
    expect(find.byType(OfflineWelcomeScreen), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(OfflineWelcomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
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
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    account.characterStateLoaded = true;
    account.changed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CharacterSelectScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(platform.created, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
