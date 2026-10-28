import 'support/asset_images.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/models/campaign_home_progress.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:challenge_land/widgets/home_character_artwork.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/cross_promo_millionaire_badge.dart';
import 'package:challenge_land/widgets/home_quick_action.dart';
import 'package:challenge_land/widgets/home_menu_artwork.dart';
import 'package:challenge_land/widgets/game_modes_artwork.dart';
import 'package:challenge_land/widgets/home_artwork.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:challenge_land/widgets/home_action_sidebar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:challenge_land/screens/auth/login_bottom_sheet.dart';
import 'package:challenge_land/widgets/guide/guide_assistant_dialog.dart';
import 'package:challenge_land/widgets/guide/home_guide_tour_overlay.dart';
// Firebase's test harness accompanies the app's existing Firebase dependency.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeUser implements User {
  _HomeUser({this.uid = 'home-player'});

  @override
  final String uid;
  @override
  String get displayName => 'لاعب';
  @override
  String get email => 'player@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _HomeState extends ChangeNotifier implements AppState {
  @override
  EconomyWallet get economyWallet =>
      const EconomyWallet(dailyKeys: 3, tickets: 2);
  @override
  bool get economyLoaded => true;
  _HomeState(
      {this.online = false, this.signedIn = true, this.displayedLevel = 2});
  final bool online;
  final bool signedIn;
  final int displayedLevel;
  String playerId = 'home-player';
  int publishedTrophies = 238;

  void switchUser(String uid) {
    playerId = uid;
    notifyListeners();
  }

  void changeTrophies(int value) {
    publishedTrophies = value;
    notifyListeners();
  }

  int characterIndex = 1;
  @override
  int get selectedCharacterIndex => characterIndex;
  @override
  GameCharacter get selectedCharacter =>
      CharacterCatalog.byIndex(characterIndex);

  void changeCharacter(int index) {
    characterIndex = index;
    notifyListeners();
  }

  int mainChallengeRequests = 0;
  int offlineRequests = 0;
  @override
  Future<void> openMainChallenge() async {
    mainChallengeRequests++;
  }

  @override
  Future<void> openOfflineGame() async {
    offlineRequests++;
  }

  @override
  bool get isOnline => online;
  @override
  bool get isVip => false;
  @override
  User? get user => signedIn ? _HomeUser(uid: playerId) : null;
  @override
  User? get currentUser => user;
  @override
  bool get isBusy => false;
  @override
  int get coins => 1200;
  @override
  int get gems => 80;
  @override
  int get trophies => publishedTrophies;
  @override
  int get level => displayedLevel;
  @override
  int get xpInCurrentLevel => 20;
  @override
  int get xpNeededForLevel => 100;
  @override
  int get streakDay => 0;
  @override
  bool get claimedToday => true;
  @override
  bool get dailyStreakLoaded => true;
  @override
  bool isCharacterUnlocked(GameCharacter character) => true;
  @override
  bool get hasChosenCharacter => true;
  @override
  Future<bool> selectCharacter(int index) async {
    changeCharacter(index);
    return true;
  }

  @override
  Future<void> loadCurrency() async {}
  @override
  Future<void> loadLevelData() async {}
  @override
  Future<void> refreshCommerce() async {}
  @override
  Future<void> checkAndAwardXpForGames() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeCampaignService extends CampaignService {
  _HomeCampaignService() : super(firestore: FakeFirebaseFirestore());

  CampaignHomeProgress progress =
      const CampaignHomeProgress(reachedStage: 5, totalStages: 100);
  final requestedUids = <String>[];

  @override
  Future<CampaignHomeProgress> loadHomeProgress(
      {required String uid, String campaignId = 'main_campaign'}) async {
    requestedUids.add(uid);
    return progress;
  }
}

class _HomeLeaderboardService extends LeaderboardService {
  _HomeLeaderboardService() : super(firestore: FakeFirebaseFirestore());

  int? rank = 23;
  bool fail = false;
  final requestedUids = <String>[];
  final watchedUids = <String>[];
  final pending = <String, Completer<int?>>{};

  @override
  Stream<int?> watchWorldRank({required String uid}) {
    watchedUids.add(uid);
    if (pending.containsKey(uid)) {
      return Stream.fromFuture(pending[uid]!.future);
    }
    if (fail) return Stream.error(StateError('Rank unavailable'));
    return Stream.value(rank);
  }

  @override
  Future<int?> loadWorldRank({required String uid}) async {
    requestedUids.add(uid);
    if (pending.containsKey(uid)) return pending[uid]!.future;
    if (fail) throw StateError('Rank unavailable');
    return rank;
  }
}

String? _homeRank(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('home-leaderboard-rank')))
    .data;

Future<void> _mountRankHome(WidgetTester tester, _HomeState state,
    _HomeLeaderboardService service) async {
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  SharedPreferences.setMockInitialValues({
    'has_rated_challenge_land': true,
    'rate_reward_claimed': true,
  });
  final promo = _Promo();
  addTearDown(state.dispose);
  addTearDown(promo.dispose);
  await tester.binding.setSurfaceSize(const Size(800, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: state),
      ChangeNotifierProvider<CrossPromoService>.value(value: promo),
      Provider<NativeBridgeService>.value(value: _NativeBridge()),
    ],
    child: MaterialApp(
        home: HomeScreen(
            campaignService: _HomeCampaignService(),
            leaderboardService: service)),
  ));
  await tester.pump();
}

class _NativeBridge extends NativeBridgeService {
  @override
  bool get supportsAnimatedCharacters => false;
  final artworkRequests = <int>[];
  @override
  Future<Uint8List?> getCharacterArtwork(int index) async {
    artworkRequests.add(index);
    final id = CharacterCatalog.byIndex(index).id;
    return File('android/app/src/main/res/drawable/contestant_$id.png')
        .readAsBytesSync();
  }

  @override
  Future<Map<String, dynamic>> getAchievements() async => {};
  @override
  Future<Map<String, dynamic>?> getPendingRoomMatchResult() async => null;
  @override
  Future<String?> consumeLaunchAction() async => null;
  @override
  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async =>
      null;
}

class _Promo extends ChangeNotifier implements CrossPromoService {
  @override
  bool get isMillionaireInstalled => false;
  @override
  bool get isRewardClaimed => false;
  @override
  Future<bool> checkInstallation() async => false;
  @override
  Future<bool> checkRewardClaimed({String? uid}) async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AnimatedNativeBridge extends _NativeBridge {
  @override
  bool get supportsAnimatedCharacters => true;
}

class _DelayedNativeBridge extends _NativeBridge {
  final artwork = Completer<Uint8List?>();
  @override
  Future<Uint8List?> getCharacterArtwork(int index) => artwork.future;
}

Widget _shortcut({
  bool isAvailable = true,
  bool disableAnimations = false,
  double animationValue = 0.5,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: HomeQuickAction(
            label: 'الأصدقاء واللاعبون',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF7DD3FC),
            animation: AlwaysStoppedAnimation(animationValue),
            onPressed: onPressed ?? () {},
            isAvailable: isAvailable,
            showGreenDot: true,
          ),
        ),
      ),
    ),
  );
}

void _expectSidebarLayout(WidgetTester tester, Size screen) {
  Rect bounds(String name) =>
      tester.getRect(find.byKey(ValueKey('home-$name-button')));
  final panel = tester.getRect(find.byType(HomeActionSidebar));
  final leaderboard = bounds('leaderboard');
  final campaign = bounds('campaign');
  final vip = bounds('vip');
  final modes = bounds('modes');
  final friends =
      tester.getRect(find.byKey(const ValueKey('home-friends-shortcut')));
  final play = bounds('play');
  final character =
      tester.getRect(find.byKey(const ValueKey('home-selected-character')));
  expect(leaderboard.bottom, lessThanOrEqualTo(campaign.top));
  expect(campaign.right, lessThanOrEqualTo(vip.left));
  expect(campaign.center.dy, closeTo(vip.center.dy, .1));
  expect(campaign.bottom, lessThanOrEqualTo(modes.top));
  expect(vip.bottom, lessThanOrEqualTo(modes.top));
  expect(modes.bottom, lessThanOrEqualTo(friends.top));
  expect(friends.bottom, lessThanOrEqualTo(play.top));
  for (final control in [leaderboard, campaign, vip, modes, friends, play]) {
    expect(panel.inflate(.1).contains(control.topLeft), isTrue);
    expect(panel.inflate(.1).contains(control.bottomRight), isTrue);
    expect(control.left, greaterThanOrEqualTo(0));
    expect(control.top, greaterThanOrEqualTo(0));
    expect(control.right, lessThanOrEqualTo(screen.width));
    expect(control.bottom, lessThanOrEqualTo(screen.height));
    expect(control.overlaps(character), isFalse);
  }
  expect(panel.center.dx, greaterThanOrEqualTo(screen.width / 2));
  if (screen.width > screen.height) {
    expect(character.right, lessThanOrEqualTo(panel.left));
  } else {
    expect(character.bottom, lessThanOrEqualTo(panel.top));
  }
}

void main() {
  for (final size in [
    const Size(960, 540),
    const Size(800, 360),
    const Size(390, 844),
    const Size(1600, 826)
  ]) {
    testWidgets('home tour keeps every target and presenter clear at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final font in {
        'Baloo': 'assets/fonts/baloo.ttf',
        'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)
              ..addFont(SharedAssets.bundle.load(font.value)))
            .load();
      }
      final state = _HomeState(online: true, signedIn: false);
      addTearDown(state.dispose);
      final previewKey = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            Provider<NativeBridgeService>.value(value: _NativeBridge()),
          ],
          child: MaterialApp(
            builder: (context, child) => RepaintBoundary(
                key: previewKey, child: GameViewport(child: child!)),
            theme: ThemeData.dark(useMaterial3: true).copyWith(
                textTheme: ThemeData.dark()
                    .textTheme
                    .apply(fontFamily: 'NotoSansArabic')),
            home: const HomeScreen(),
          )));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeGuideTourOverlay), findsOneWidget,
          reason: 'A new guest should automatically see the tour');
      final tour = tester
          .widget<HomeGuideTourOverlay>(find.byType(HomeGuideTourOverlay));
      await tester.runAsync(() => Future.wait([
            for (final file
                in Directory('assets/presenter').listSync().whereType<File>())
              if (file.path.endsWith('.png'))
                precacheImage(AssetImage(file.path.replaceAll('\\', '/')),
                    tester.element(find.byType(HomeGuideTourOverlay))),
          ]));
      for (var index = 0; index < tour.steps.length; index++) {
        // Let the previous bubble fade out before checking the new speech turn.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Step $index: ${tour.steps[index].title}');
        final stage = tester.getRect(find.byKey(const ValueKey('guide-stage')));
        final scene =
            tester.getRect(find.byKey(const ValueKey('guide-presenter-scene')));
        final bubble =
            tester.getRect(find.byKey(const ValueKey('guide-dialogue-panel')));
        final host =
            tester.getRect(find.byKey(const ValueKey('guide-presenter')));
        final podium =
            tester.getRect(find.byKey(const ValueKey('guide-podium')));
        final navigation =
            tester.getRect(find.byKey(const ValueKey('guide-navigation')));
        expect(navigation.deflate(.5).overlaps(podium.deflate(.5)), isFalse,
            reason:
                'Step $index ${tour.steps[index].title}: navigation $navigation must not cover podium $podium');
        expect(navigation.deflate(.5).overlaps(bubble.deflate(.5)), isFalse);
        expect(bubble.bottom, lessThanOrEqualTo(host.top + .5),
            reason: 'The speech bubble belongs above the presenter');
        expect(podium.top, greaterThan(host.top + host.height * .85),
            reason: 'The podium belongs below the full torso');
        expect(host.height,
            greaterThanOrEqualTo(size == const Size(960, 540) ? 139.5 : 129.5),
            reason: 'The presenter should remain large enough to see speaking');
        for (final part in [scene, bubble, host, podium]) {
          expect(stage.inflate(.5).contains(part.topLeft), isTrue,
              reason: 'Step $index must contain the entire presenter scene');
          expect(stage.inflate(.5).contains(part.bottomRight), isTrue,
              reason: 'Step $index must contain the entire presenter scene');
        }
        final screen = Offset.zero & size;
        expect(screen.contains(stage.topLeft), isTrue);
        expect(screen.contains(stage.bottomRight), isTrue);
        final targetKey = tour.steps[index].targetKey;
        if (targetKey != null) {
          final target = tester.getRect(find.byKey(targetKey));
          final paint = tester.widget<CustomPaint>(
              find.byKey(const ValueKey('guide-spotlight')));
          final painter = paint.painter! as SpotlightPainter;
          expect(painter.targetRect, isNotNull,
              reason: tour.steps[index].title);
          final surface = tester.renderObject<RenderBox>(
              find.byKey(const ValueKey('guide-spotlight')));
          final actual = Rect.fromPoints(
              surface.localToGlobal(painter.targetRect!.topLeft),
              surface.localToGlobal(painter.targetRect!.bottomRight));
          expect(actual.left, closeTo(target.left, .1));
          expect(actual.top, closeTo(target.top, .1));
          expect(actual.width, closeTo(target.width, .1));
          expect(actual.height, closeTo(target.height, .1));
          expect(stage.overlaps(target), isFalse,
              reason: tour.steps[index].title);
        }
        if ([0, 1, 5, 12, 14, 17].contains(index)) {
          // Capture a talking frame, then reveal the whole line for a readable
          // reference image without changing the presenter/podium placement.
          await tester.tap(find.byTooltip('إعادة الشرح'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 450));
          await tester.runAsync(() async {
            final boundary = previewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes =
                await rendered.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'build/guide-${size.width.toInt()}x${size.height.toInt()}-$index.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
          await tester.tap(find.byKey(const ValueKey('guide-speech-bubble')));
          await tester.pump(const Duration(milliseconds: 180));
          await tester.runAsync(() async {
            final boundary = previewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes =
                await rendered.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'build/guide-${size.width.toInt()}x${size.height.toInt()}-$index-full.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        if (index < tour.steps.length - 1) {
          await tester.tap(find.text(index == 0 ? 'ابدأ الجولة' : 'التالي'));
          await tester.pump();
        }
      }
      await tester.tap(find.text('استكشف الساحة'));
      await tester.pump();
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      expect(
          (await SharedPreferences.getInstance())
              .getBool('has_completed_home_onboarding_guide'),
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
  for (final online in [true, false]) {
    testWidgets('guest home requires sign-in for every control online=$online',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'has_completed_home_onboarding_guide': true});
      await tester.binding.setSurfaceSize(const Size(1600, 826));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final font in {
        'Baloo': 'assets/fonts/baloo.ttf',
        'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)
              ..addFont(SharedAssets.bundle.load(font.value)))
            .load();
      }
      final state = _HomeState(online: online, signedIn: false);
      final previewKey = GlobalKey();
      addTearDown(state.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          Provider<NativeBridgeService>.value(value: _NativeBridge()),
        ],
        child: MaterialApp(
            builder: (context, child) => RepaintBoundary(
                key: previewKey, child: GameViewport(child: child!)),
            theme: ThemeData(
                brightness: Brightness.dark,
                useMaterial3: true,
                fontFamily: 'Baloo',
                fontFamilyFallback: const ['NotoSansArabic']),
            home: const HomeScreen()),
      ));
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(LoginBottomSheet), findsNothing);

      var previewSaved = false;
      for (final control in [
        find.byTooltip('القائمة'),
        find.byKey(const ValueKey('home-friends-shortcut')),
        find.byKey(const ValueKey('home-store-shortcut')),
        find.byKey(const ValueKey('home-help-shortcut')),
        find.byKey(const ValueKey('home-coins-balance')),
        find.byKey(const ValueKey('home-gems-balance')),
        find.byKey(const ValueKey('home-keys-balance')),
        find.byKey(const ValueKey('home-tickets-balance')),
        find.byKey(const ValueKey('home-play-button')),
        find.byKey(const ValueKey('home-vip-button')),
        find.byKey(const ValueKey('home-leaderboard-button')),
        find.byTooltip('تحدي المراحل'),
        find.byTooltip('أوضاع اللعب'),
        find.byKey(const ValueKey('home-selected-character')),
      ]) {
        await tester.tapAt(tester.getCenter(control));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final authPromptFinder = find.byType(LoginBottomSheet);
        expect(authPromptFinder, findsOneWidget, reason: control.toString());
        expect(find.byType(GuidePromptDialog), findsNothing);
        expect(find.text('جرّب التحدي مجانًا'), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(GameModesArtwork), findsNothing);
        expect(find.byType(CharacterSelectScreen), findsNothing);
        if (online && !previewSaved) {
          final context = tester.element(authPromptFinder);
          await tester.runAsync(() => Future.wait([
                for (final image
                    in tester.widgetList<Image>(find.byType(Image)))
                  precacheImage(image.image, context),
              ]));
          await tester.pump();
          final boundary = previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('build/guest-login-bottom-sheet.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          previewSaved = true;
        }
        await tester.tap(find.byKey(const ValueKey('close-login-sheet')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(authPromptFinder, findsNothing);
      }
      expect(state.mainChallengeRequests, 0);
      expect(state.offlineRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delayed character loading never enlarges the face portrait',
      (tester) async {
    final character = CharacterCatalog.byId('mahmoud')!;
    final bounds = find.byType(HomeCharacterArtwork);
    final portraits = find.byWidgetPredicate((widget) =>
        widget is Image &&
        underlyingAsset(widget.image) is AssetImage &&
        (underlyingAsset(widget.image) as AssetImage)
            .assetName
            .startsWith('assets/characters/'));
    for (final succeeds in [true, false]) {
      final bridge = _DelayedNativeBridge();
      await tester.pumpWidget(Provider<NativeBridgeService>.value(
        value: bridge,
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: HomeCharacterArtwork(
                  key: ValueKey(succeeds), character: character),
            ),
          ),
        ),
      ));
      final initialBounds = tester.getRect(bounds);
      expect(initialBounds.size, const Size(200, 300));
      await tester.pump(const Duration(seconds: 1));
      expect(portraits, findsNothing);
      expect(find.byKey(const ValueKey('home-character-placeholder')),
          findsOneWidget);
      bridge.artwork.complete(succeeds
          ? File('android/app/src/main/res/drawable/contestant_mahmoud.png')
              .readAsBytesSync()
          : null);
      await tester.pump();
      await tester.pump();
      expect(portraits, findsNothing);
      expect(tester.getRect(bounds), initialBounds);
      expect(find.byKey(const ValueKey('home-character-mahmoud')),
          succeeds ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'native character loops pause off route and change with selection',
      (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final created = <Map<Object?, Object?>>[];
    final pauseCalls = <bool>[];
    final disposed = <int>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      if (call.method == 'create') {
        created.add(args);
        final id = args['id'] as int;
        messenger.setMockMethodCallHandler(
            MethodChannel('challengeland/home-character/$id'), (call) async {
          if (call.method == 'setPaused') {
            pauseCalls.add(call.arguments as bool);
          }
          return null;
        });
      } else if (call.method == 'dispose') {
        disposed.add(args['id'] as int);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final view in created) {
        messenger.setMockMethodCallHandler(
            MethodChannel('challengeland/home-character/${view['id']}'), null);
      }
    });
    final selection = ValueNotifier((index: 1, paused: false, reduced: false));
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      Provider<NativeBridgeService>(
        create: (_) => _AnimatedNativeBridge(),
        child: MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: selection,
            builder: (context, value, _) => MediaQuery(
              data: MediaQueryData(disableAnimations: value.reduced),
              child: TickerMode(
                enabled: !value.paused,
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 300,
                    child: HomeCharacterArtwork(
                      character: CharacterCatalog.byIndex(value.index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(created, hasLength(1));
    expect(created.single['hybrid'], isTrue);
    final params = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(created.single['params'] as Uint8List)) as Map;
    expect(params['index'], 1);
    expect(pauseCalls.last, isFalse);
    expect(find.byKey(const ValueKey('home-character-omar')), findsOneWidget);
    final ready =
        MethodChannel('challengeland/home-character/${created.single['id']}');
    await messenger.handlePlatformMessage(ready.name,
        ready.codec.encodeMethodCall(const MethodCall('ready')), (_) {});
    await tester.pump();
    expect(find.byKey(const ValueKey('home-character-omar')), findsNothing);
    expect(find.byType(PlatformViewLink), findsOneWidget);

    selection.value = (index: 1, paused: true, reduced: false);
    await tester.pump();
    expect(pauseCalls.last, isTrue);
    selection.value = (index: 6, paused: false, reduced: false);
    await tester.pump();
    await tester.pump();
    expect(created, hasLength(2));
    expect(disposed, contains(created.first['id']));
    final next = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(created.last['params'] as Uint8List)) as Map;
    expect(next['index'], 6);
    selection.value = (index: 6, paused: false, reduced: true);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlatformViewLink), findsNothing);
    expect(disposed, contains(created.last['id']));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('friends dot stays green and visible when offline',
      (tester) async {
    for (final isAvailable in [true, false]) {
      await tester.pumpWidget(_shortcut(isAvailable: isAvailable));
      final indicator = find.byKey(const ValueKey('home-friends-green-dot'));
      expect(indicator, findsOneWidget);
      final decoration =
          tester.widget<Container>(indicator).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF34D399));
      expect(tester.getSize(indicator), const Size.square(12));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('icon-only shortcut responds to taps and has an Arabic label',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_shortcut(onPressed: () => taps++));
    expect(find.text('الأصدقاء واللاعبون'), findsNothing);
    expect(find.byTooltip('الأصدقاء واللاعبون'), findsOneWidget);
    expect(find.bySemanticsLabel('الأصدقاء واللاعبون'), findsOneWidget);
    expect(tester.getSize(find.byType(HomeQuickAction)), const Size.square(52));
    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    expect(taps, 1);
    await tester.longPress(find.byType(HomeQuickAction));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('الأصدقاء واللاعبون'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('reduced motion removes translation and rotation',
      (tester) async {
    await tester.pumpWidget(_shortcut());
    final transforms = find.descendant(
      of: find.byType(HomeQuickAction),
      matching: find.byType(Transform),
    );
    expect(transforms, findsNWidgets(2));
    expect(tester.widget<Transform>(transforms.first).transform.isIdentity(),
        isFalse);

    await tester.pumpWidget(_shortcut(disableAnimations: true));
    for (final transform in tester.widgetList<Transform>(transforms)) {
      expect(transform.transform.isIdentity(), isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  group('home shortcuts stay clear of the home controls', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    testWidgets(
        'home fills phone and tablet edges including the reported left gap',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_rated_challenge_land': true,
        'rate_reward_claimed': true,
      });
      for (final font in {
        'Baloo': 'assets/fonts/baloo.ttf',
        'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)
              ..addFont(SharedAssets.bundle.load(font.value)))
            .load();
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final state = _HomeState();
      final promo = _Promo();
      addTearDown(state.dispose);
      addTearDown(promo.dispose);
      for (final display in <(Size, double)>[
        (const Size(1592, 826), 108),
        (const Size(2340, 1080), 100),
        (const Size(1280, 800), 0),
        (const Size(640, 360), 0),
      ]) {
        final size = display.$1;
        tester.view.physicalSize = size;
        final boundaryKey = GlobalKey();
        final safe = EdgeInsets.only(left: display.$2);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<CrossPromoService>.value(value: promo),
            Provider<NativeBridgeService>.value(value: _NativeBridge()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark()
                  .textTheme
                  .apply(fontFamily: 'NotoSansArabic'),
            ),
            builder: (context, child) => RepaintBoundary(
              key: boundaryKey,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: safe,
                  viewPadding: safe,
                  textScaler: const TextScaler.linear(2.5),
                ),
                child: GameViewport(child: child!),
              ),
            ),
            home: const HomeScreen(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        final context = tester.element(find.byType(HomeScreen));
        await tester.runAsync(() => Future.wait([
              precacheImage(const AssetImage(HomeArtwork.background), context),
              for (final image in tester.widgetList<Image>(find.byType(Image)))
                precacheImage(image.image, context),
            ]));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getRect(find.byType(Scaffold).first),
            rectMoreOrLessEquals(Offset.zero & size, epsilon: .01));
        for (final control in [
          find.byTooltip('القائمة'),
          find.byKey(const ValueKey('home-friends-shortcut')),
          find.byKey(const ValueKey('home-store-shortcut')),
          find.byKey(const ValueKey('home-help-shortcut')),
        ]) {
          expect(control.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(control);
          expect(bounds.left, greaterThanOrEqualTo(display.$2));
          expect(bounds.right, lessThanOrEqualTo(size.width));
        }
        expect(tester.takeException(), isNull, reason: '$size');
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final pixels =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          for (final x in [0, image.width - 1]) {
            final offset = ((image.height ~/ 2) * image.width + x) * 4;
            expect(
                pixels.getUint8(offset) +
                    pixels.getUint8(offset + 1) +
                    pixels.getUint8(offset + 2),
                greaterThan(0),
                reason: 'A black strip remains at x=$x on $size');
          }
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  'build/fullscreen-home-${size.width.toInt()}x${size.height.toInt()}.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    });

    for (final size in [
      const Size(640, 360),
      const Size(800, 400),
      const Size(320, 640),
    ]) {
      testWidgets('full home layout at $size', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final state = _HomeState();
        final promo = _Promo();
        addTearDown(state.dispose);
        addTearDown(promo.dispose);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<CrossPromoService>.value(value: promo),
            Provider<NativeBridgeService>.value(value: _NativeBridge()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            builder: (context, child) {
              final padding =
                  EdgeInsets.only(left: size.width > size.height ? 32 : 0);
              return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(padding: padding, viewPadding: padding),
                  child: child!);
            },
            home: const HomeScreen(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        final obstacles = [
          find.byTooltip('القائمة'),
          find.byType(HomeLevelBadge),
          find.byType(HomeActionSidebar),
        ];
        for (final shortcut in [
          find.byKey(const ValueKey('home-store-shortcut')),
          find.byKey(const ValueKey('home-help-shortcut')),
        ]) {
          final bounds = tester.getRect(shortcut);
          expect(bounds.left, closeTo(size.width > size.height ? 38 : 6, .01),
              reason: 'Left shortcuts remain clear of the camera cutout');
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          for (final obstacle in obstacles) {
            expect(bounds.overlaps(tester.getRect(obstacle)), isFalse,
                reason: 'Shortcut overlaps a home control at $size');
          }
        }
        expect(find.byKey(const ValueKey('home-friends-notification-dot')),
            findsOneWidget);
        expect(tester.getRect(find.byTooltip('القائمة')).left,
            closeTo(size.width > size.height ? 38 : 6, .01));
        expect(find.byType(CrossPromoMillionaireBadge), findsNothing);
        _expectSidebarLayout(tester, size);
        final characterBounds = tester
            .getRect(find.byKey(const ValueKey('home-selected-character')));
        final levelBounds = tester.getRect(find.byType(HomeLevelBadge));
        expect(levelBounds.center.dx, closeTo(characterBounds.center.dx, .01));
        expect(levelBounds.bottom, lessThanOrEqualTo(characterBounds.top));
        await tester.tap(find.byKey(const ValueKey('home-help-shortcut')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('تواصل مع فريق العمل'), findsOneWidget);
        expect(find.byKey(const ValueKey('support-message')), findsOneWidget);
        await tester.tap(find.byTooltip('إغلاق التواصل'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('تواصل مع فريق العمل'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('home-friends-shortcut')));
        await tester.pump();
        expect(find.text('تتطلب هذه الميزة اتصالا بالإنترنت'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        // Drain the existing home startup delays after the screen is disposed.
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  testWidgets(
      'home character follows the saved selection without reloading on rebuild',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = _HomeState();
    final promo = _Promo();
    final native = _NativeBridge();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<CrossPromoService>.value(value: promo),
        Provider<NativeBridgeService>.value(value: native),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();
    expect(native.artworkRequests, [1]);
    expect(find.byKey(const ValueKey('home-character-omar')), findsOneWidget);
    final firstImage =
        tester.widget<Image>(find.byKey(const ValueKey('home-character-omar')));
    expect((firstImage.image as ResizeImage).imageProvider, isA<MemoryImage>());

    state.changeCharacter(1);
    await tester.pump();
    expect(native.artworkRequests, [1]);
    state.changeCharacter(6);
    await tester.pump();
    await tester.pump();
    expect(native.artworkRequests, [1, 6]);
    expect(find.byKey(const ValueKey('home-character-omar')), findsNothing);
    expect(find.byKey(const ValueKey('home-character-sarah')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping home character navigates to character select screen',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = _HomeState();
    final promo = _Promo();
    final native = _NativeBridge();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<CrossPromoService>.value(value: promo),
        Provider<NativeBridgeService>.value(value: native),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();
    expect(
        find.byKey(const ValueKey('home-selected-character')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-selected-character')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CharacterSelectScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final guideSize in [const Size(960, 540), const Size(390, 780)]) {
    testWidgets(
        'mode guide explains each choice before allowing launch at $guideSize',
        (tester) async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      SharedPreferences.setMockInitialValues(
          {'has_rated_challenge_land': true, 'rate_reward_claimed': true});
      for (final font in {
        'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
      }.entries) {
        await (FontLoader(font.key)
              ..addFont(SharedAssets.bundle.load(font.value)))
            .load();
      }
      await tester.binding.setSurfaceSize(guideSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = _HomeState();
      final promo = _Promo();
      final previewKey = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<CrossPromoService>.value(value: promo),
            Provider<NativeBridgeService>.value(value: _NativeBridge()),
          ],
          child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                  textTheme: ThemeData.dark()
                      .textTheme
                      .apply(fontFamily: 'NotoSansArabic')),
              builder: (_, child) =>
                  RepaintBoundary(key: previewKey, child: child!),
              home: const HomeScreen())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('أوضاع اللعب'));
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final tour = tester
          .widget<HomeGuideTourOverlay>(find.byType(HomeGuideTourOverlay));
      for (var index = 0; index < tour.steps.length; index++) {
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: tour.steps[index].title);
        final speechScroll = tester.state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('guide-speech-bubble')),
                matching: find.byType(Scrollable))
            .first);
        expect(speechScroll.position.maxScrollExtent, lessThanOrEqualTo(1),
            reason:
                '${tour.steps[index].title}: the short explanation must fit');
        final painter = tester
            .widget<CustomPaint>(find.byKey(const ValueKey('guide-spotlight')))
            .painter! as SpotlightPainter;
        if (tour.steps[index].targetKey != null) {
          expect(painter.targetRect, isNotNull,
              reason: tour.steps[index].title);
          final stage =
              tester.getRect(find.byKey(const ValueKey('guide-stage')));
          expect(stage.overlaps(painter.targetRect!), isFalse,
              reason: tour.steps[index].title);
        }
        if (const bool.fromEnvironment('GUIDE_PREVIEW')) {
          await tester.tap(find.byKey(const ValueKey('guide-speech-bubble')));
          await tester.pump();
          final images = tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => image.image)
              .toSet();
          await tester.runAsync(() => Future.wait(images.map(
              (image) => precacheImage(image, previewKey.currentContext!))));
          await tester.pump();
          final boundary = previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final snapshot = await boundary.toImage(pixelRatio: 1.5);
            final bytes =
                await snapshot.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'build/modes-guide-${guideSize.width.toInt()}-$index.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            snapshot.dispose();
          });
        }
        await tester.tap(find.text(index == tour.steps.length - 1
            ? 'اختر طريقة اللعب'
            : index == 0
                ? 'ابدأ الجولة'
                : 'التالي'));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      expect(state.mainChallengeRequests, 0);
      expect(state.offlineRequests, 0);
      await tester.tap(find.byTooltip('أوفلاين'));
      await tester.pump();
      expect(state.offlineRequests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      state.dispose();
      promo.dispose();
    });
  }

  testWidgets(
      'home game modes dismiss before launching or showing an offline notice',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_completed_page_guide_modes_v1': true,
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = _HomeState();
    final promo = _Promo();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<CrossPromoService>.value(value: promo),
          Provider<NativeBridgeService>.value(value: _NativeBridge()),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const HomeScreen())));
    await tester.pump(const Duration(milliseconds: 100));
    Future<void> openModes() async {
      await tester.tap(find.byTooltip('أوضاع اللعب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GameModesArtwork), findsOneWidget);
    }

    await openModes();
    await tester.tap(find.byTooltip('التحدي الرئيسي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.mainChallengeRequests, 1);
    expect(find.byType(BottomSheet), findsNothing);
    await openModes();
    await tester.tap(find.byTooltip('أوفلاين'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.offlineRequests, 1);
    expect(find.byType(BottomSheet), findsNothing);
    for (final mode in ['تحدي جماعي', 'تحدي صديق']) {
      await openModes();
      await tester.tap(find.byTooltip(mode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('تتطلب هذه الميزة اتصالا بالإنترنت'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'new currency artwork displays live balances and keeps tap actions',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    for (final gems in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 190,
                      height: 52,
                      child: HomeCurrencyArtwork(
                          gems: gems,
                          value: '2147483647',
                          onPressed: () => taps++))))));
      expect(find.text('2147483647'), findsOneWidget);
      expect(find.text('7746'), findsNothing);
      expect(find.text('299201'), findsNothing);
      expect(
          find.bySemanticsLabel(
              gems ? 'رصيد الجواهر: 2147483647' : 'رصيد النقود: 2147483647'),
          findsOneWidget);
      await tester.tap(find.byType(HomeCurrencyArtwork));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
    semantics.dispose();
  });

  testWidgets('original level badge clamps progress and exposes live XP',
      (tester) async {
    final semantics = tester.ensureSemantics();
    for (final data in [
      (xp: 20, goal: 100, fraction: .2),
      (xp: 200, goal: 100, fraction: 1.0),
      (xp: -10, goal: 100, fraction: 0.0),
      (xp: 20, goal: 0, fraction: 0.0),
      (xp: 2147483647, goal: 2147483647, fraction: 1.0),
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 180,
                      height: 80,
                      child: HomeLevelBadge(
                          level: 1234, xp: data.xp, requiredXp: data.goal))))));
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('${data.xp}/${data.goal}'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'المستوى 1234، نقاط الخبرة ${data.xp} من ${data.goal}'),
          findsOneWidget);
      final progress = find.byKey(const ValueKey('home-level-progress'));
      expect(tester.widget<LinearProgressIndicator>(progress).value,
          data.fraction);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('home campaign progress refreshes on resume and account change',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    final state = _HomeState(online: true);
    final service = _HomeCampaignService();
    final promo = _Promo();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<CrossPromoService>.value(value: promo),
        Provider<NativeBridgeService>.value(value: _NativeBridge()),
      ],
      child: MaterialApp(home: HomeScreen(campaignService: service)),
    ));
    await tester.pump();
    expect(find.text('5/100'), findsOneWidget);
    expect(service.requestedUids, ['home-player']);

    service.progress =
        const CampaignHomeProgress(reachedStage: 6, totalStages: 100);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('6/100'), findsOneWidget);
    expect(service.requestedUids, ['home-player', 'home-player']);

    service.progress =
        const CampaignHomeProgress(reachedStage: 1, totalStages: 100);
    state.switchUser('another-player');
    await tester.pump();
    await tester.pump();
    expect(find.text('1/100'), findsOneWidget);
    expect(find.text('6/100'), findsNothing);
    expect(service.requestedUids.last, 'another-player');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('home rank refreshes independently from player level',
      (tester) async {
    final state = _HomeState(online: true, displayedLevel: 6);
    final service = _HomeLeaderboardService();
    await _mountRankHome(tester, state, service);
    expect(_homeRank(tester), '23');
    expect(service.watchedUids, ['home-player']);
    expect(
        find.descendant(
            of: find.byType(HomeLevelBadge), matching: find.text('6')),
        findsOneWidget);

    service.rank = 24;
    state.changeTrophies(239);
    await tester.pump();
    await tester.pump();
    expect(_homeRank(tester), '24');

    service.rank = 42;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_homeRank(tester), '42');

    service.fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_homeRank(tester), '42',
        reason: 'A failed refresh should keep this account’s last known rank');

    state.switchUser('another-player');
    await tester.pump();
    await tester.pump();
    expect(_homeRank(tester), '—',
        reason: 'Another account must never inherit the previous rank');
    expect(service.watchedUids.last, 'another-player');

    service.fail = false;
    service.rank = 7;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_homeRank(tester), '7');
    expect(service.requestedUids.last, 'another-player');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'late rank from a previous account cannot replace the current rank',
      (tester) async {
    final state = _HomeState(online: true, displayedLevel: 6);
    final service = _HomeLeaderboardService();
    final oldAccount = Completer<int?>();
    await _mountRankHome(tester, state, service);
    expect(_homeRank(tester), '23');
    service.pending['home-player'] = oldAccount;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    service.rank = 8;
    state.switchUser('another-player');
    await tester.pump();
    await tester.pump();
    expect(_homeRank(tester), '8');
    oldAccount.complete(1);
    await tester.pump();
    expect(_homeRank(tester), '8');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('export updated home icons and banners with real balances',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    await (FontLoader('Leaderboard')
          ..addFont(
              rootBundle.load('assets/fonts/BarlowCondensed-SemiBold.ttf')))
        .load();
    await (FontLoader('Baloo')
          ..addFont(SharedAssets.bundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(
              SharedAssets.bundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(
              SharedAssets.bundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final state = _HomeState(online: true, displayedLevel: 6);
    final campaignService = _HomeCampaignService();
    final leaderboardService = _HomeLeaderboardService();
    final promo = _Promo();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(800, 400),
      const Size(640, 360),
      const Size(390, 780),
      const Size(1024, 572),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<CrossPromoService>.value(value: promo),
            Provider<NativeBridgeService>.value(value: _NativeBridge()),
          ],
          child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true).copyWith(
                  textTheme: ThemeData.dark().textTheme.apply(
                      fontFamily: 'Baloo',
                      fontFamilyFallback: const ['NotoSansArabic'])),
              home: RepaintBoundary(
                  key: key,
                  child: HomeScreen(
                      campaignService: campaignService,
                      leaderboardService: leaderboardService)))));
      await tester.runAsync(() => Future.wait([
            for (final asset in [
              HomeArtwork.menu,
              HomeArtwork.store,
              HomeArtwork.help,
              ...HomeActionSidebar.assets,
              HomeArtwork.coins,
              HomeArtwork.gems,
              HomeArtwork.keys,
              HomeArtwork.tickets,
              HomeArtwork.level,
              HomeArtwork.background,
            ])
              precacheImage(
                  AssetImage(asset), tester.element(find.byType(HomeScreen))),
          ]));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future.wait([
            for (final image in tester.widgetList<Image>(find.descendant(
                of: find.byType(HomeCharacterArtwork),
                matching: find.byType(Image))))
              precacheImage(image.image,
                  tester.element(find.byType(HomeCharacterArtwork))),
          ]));
      await tester.pump();
      expect(find.byKey(const ValueKey('home-character-omar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(HomeLevelBadge), matching: find.text('6')),
          findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('home-leaderboard-rank')))
              .data,
          '23');
      expect(find.text('5/100'), findsOneWidget);
      expect(find.textContaining('اجمع النجوم'), findsNothing);
      expect(find.text('20/100'), findsOneWidget);
      expect(find.byTooltip('تحدي المراحل'), findsOneWidget);
      expect(find.byTooltip('أوضاع اللعب'), findsOneWidget);
      _expectSidebarLayout(tester, size);
      expect(find.text('238 / 500'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-friends-notification-dot')),
          findsOneWidget);
      final coinBounds =
          tester.getRect(find.byKey(const ValueKey('home-coins-balance')));
      final gemBounds =
          tester.getRect(find.byKey(const ValueKey('home-gems-balance')));
      final keyBounds =
          tester.getRect(find.byKey(const ValueKey('home-keys-balance')));
      final ticketBounds =
          tester.getRect(find.byKey(const ValueKey('home-tickets-balance')));
      expect(find.byTooltip('3 مفاتيح'), findsOneWidget);
      expect(find.byTooltip('2 تذاكر'), findsOneWidget);
      final menuBounds = tester.getRect(find.byTooltip('القائمة'));
      final levelBounds = tester.getRect(find.byType(HomeLevelBadge));
      final characterBounds =
          tester.getRect(find.byKey(const ValueKey('home-selected-character')));
      expect(levelBounds.center.dx, closeTo(characterBounds.center.dx, .01));
      expect(menuBounds.left, closeTo(6, .01));
      if (size.width > size.height) {
        expect(ticketBounds.right, closeTo(size.width - 16, .01));
        expect(coinBounds.left, greaterThan(menuBounds.right));
      }
      expect(coinBounds.width, lessThanOrEqualTo(128));
      expect(gemBounds.width, lessThanOrEqualTo(128));
      final logo = find.byWidgetPredicate((widget) =>
          widget is Image &&
          underlyingAsset(widget.image) is AssetImage &&
          (underlyingAsset(widget.image) as AssetImage).assetName ==
              'assets/ui/logo.webp');
      expect(logo, findsNothing);
      expect(find.text('لاعب'), findsNothing);
      expect(find.text('Qusai'), findsNothing);
      for (final banner in ['تحدي المراحل', 'أوضاع اللعب']) {
        final bounds = tester.getRect(find.byTooltip(banner));
        expect(bounds.shortestSide, greaterThanOrEqualTo(40));
        expect(bounds.overlaps(characterBounds), isFalse);
      }
      expect(coinBounds.overlaps(gemBounds), isFalse);
      expect(gemBounds.overlaps(keyBounds), isFalse);
      expect(keyBounds.overlaps(ticketBounds), isFalse);
      expect(coinBounds.overlaps(menuBounds), isFalse);
      expect(gemBounds.overlaps(menuBounds), isFalse);
      for (final other in [coinBounds, gemBounds, menuBounds]) {
        expect(levelBounds.overlaps(other), isFalse);
      }
      // Export the illuminated phase of the repeating gold frame pulse.
      await tester.pump(const Duration(milliseconds: 1100));
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final name = size.width == 1024
            ? 'reference'
            : size.width == 800
                ? 'landscape'
                : size.width == 640
                    ? 'compact'
                    : 'mobile';
        await File('build/home-artwork-$name-ar.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      if (size.width == 1024) {
        final slotBounds =
            tester.getRect(find.byKey(const ValueKey('home-vip-button')));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 350));
        final wheel = find.byKey(const ValueKey('home-wheel-button'));
        expect(wheel, findsOneWidget);
        expect(tester.getRect(wheel), slotBounds);
        expect(find.byKey(const ValueKey('home-vip-button')), findsNothing);
        await tester.runAsync(() => Future.wait([
              for (final image in tester.widgetList<Image>(
                  find.descendant(of: wheel, matching: find.byType(Image))))
                precacheImage(image.image, tester.element(wheel)),
            ]));
        await tester.pump();
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          await File('build/home-artwork-wheel-ar.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  group('home menu entries', () {
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
      await (FontLoader('MaterialIcons')
            ..addFont(
                SharedAssets.bundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });

    for (final rated in [false, true]) {
      for (final claimed in [false, true]) {
        testWidgets('rating visibility with rated=$rated and claimed=$claimed',
            (tester) async {
          SharedPreferences.setMockInitialValues({
            'has_rated_challenge_land': rated,
            'rate_reward_claimed': claimed,
          });
          await tester.binding.setSurfaceSize(const Size(800, 400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final state = _HomeState();
          final promo = _Promo();
          addTearDown(state.dispose);
          addTearDown(promo.dispose);
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AppState>.value(value: state),
              ChangeNotifierProvider<CrossPromoService>.value(value: promo),
              Provider<NativeBridgeService>.value(value: _NativeBridge()),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true).copyWith(
                  textTheme: ThemeData.dark().textTheme.apply(
                      fontFamily: 'Baloo',
                      fontFamilyFallback: const ['NotoSansArabic'])),
              home: const HomeScreen(),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(find.byTooltip('القائمة'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final menu = find.byType(BottomSheet);
          expect(menu, findsOneWidget);
          expect(find.byType(HomeMenuArtwork), findsOneWidget);
          await tester.runAsync(() => precacheImage(
              const AssetImage(HomeMenuArtwork.asset),
              tester.element(find.byType(HomeMenuArtwork))));
          await tester.pump();
          if (!rated && !claimed) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('home-menu-artwork')));
            await tester.runAsync(() async {
              final rendered = await boundary.toImage(pixelRatio: 2);
              final bytes =
                  await rendered.toByteData(format: ui.ImageByteFormat.png);
              await File('build/home-menu-rating-ar.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              rendered.dispose();
            });
          }
          expect(
            find.descendant(
              of: menu,
              matching: find.text('تقييم أرض التحدي ⭐'),
            ),
            !rated && !claimed ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: menu,
              matching: find.text('قيّم الآن'),
            ),
            !rated && !claimed ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: menu,
              matching: find.text('لعبة تحدي المليون 🏆'),
            ),
            findsNothing,
          );
          expect(find.byType(CrossPromoMillionaireBadge), findsNothing);
          expect(
            find.descendant(
              of: find.byType(HomeScreen),
              matching: find.text('تحدي المليون'),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          if (rated && claimed) {
            await tester.tap(find.byTooltip('الصدارة'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(
                find.text('تتطلب هذه الميزة اتصالا بالإنترنت'), findsOneWidget);
            expect(find.byType(BottomSheet), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  });
}
