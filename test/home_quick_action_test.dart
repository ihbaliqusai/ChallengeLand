import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/cross_promo_millionaire_badge.dart';
import 'package:challenge_land/widgets/home_quick_action.dart';
import 'package:challenge_land/widgets/home_menu_artwork.dart';
import 'package:challenge_land/widgets/game_modes_artwork.dart';
import 'package:challenge_land/widgets/home_artwork.dart';
import 'package:challenge_land/widgets/special_offer_badge.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's test harness accompanies the app's existing Firebase dependency.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeState extends ChangeNotifier implements AppState {
  _HomeState({this.online = false});
  final bool online;
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
  get user => null;
  @override
  get currentUser => null;
  @override
  int get coins => 1200;
  @override
  int get gems => 80;
  @override
  int get level => 2;
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
  Future<void> loadCurrency() async {}
  @override
  Future<void> loadLevelData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NativeBridge extends NativeBridgeService {
  @override
  Future<Map<String, dynamic>> getAchievements() async => {};
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
            home: const HomeScreen(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        final obstacles = [
          find.byTooltip('القائمة'),
          find.byType(HomeLevelBadge),
          find.byType(CrossPromoMillionaireBadge),
          find.byType(SpecialOfferBadge),
          find.byTooltip('تحدي المراحل'),
          find.byTooltip('أوضاع اللعب'),
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/ui/logo.webp'),
        ];
        for (final shortcut in [
          find.byKey(const ValueKey('home-friends-shortcut')),
          find.byKey(const ValueKey('home-store-shortcut')),
        ]) {
          final bounds = tester.getRect(shortcut);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          for (final obstacle in obstacles) {
            expect(bounds.overlaps(tester.getRect(obstacle)), isFalse,
                reason: 'Shortcut overlaps a home control at $size');
          }
        }
        expect(find.byKey(const ValueKey('home-friends-green-dot')),
            findsOneWidget);
        expect(find.byType(CrossPromoMillionaireBadge), findsOneWidget);
        final campaignBounds = tester.getRect(find.byTooltip('تحدي المراحل'));
        final modesBounds = tester.getRect(find.byTooltip('أوضاع اللعب'));
        expect(campaignBounds.bottom, lessThan(modesBounds.top));
        expect(campaignBounds.overlaps(modesBounds), isFalse);
        expect(campaignBounds.center.dx, closeTo(size.width / 2, .01));
        expect(modesBounds.center.dx, closeTo(size.width / 2, .01));
        for (final banner in [
          find.byTooltip('تحدي المراحل'),
          find.byTooltip('أوضاع اللعب')
        ]) {
          for (final badge in [
            find.byType(CrossPromoMillionaireBadge),
            find.byType(SpecialOfferBadge)
          ]) {
            expect(
                tester.getRect(banner).overlaps(tester.getRect(badge)), isFalse,
                reason: 'Home banners must remain clear of the bottom badges');
          }
        }
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
      'home game modes dismiss before launching or showing an offline notice',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
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
      expect(find.text('المستوى 1234'), findsOneWidget);
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

  testWidgets('export updated home icons and banners with real balances',
      (tester) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({
      'has_rated_challenge_land': true,
      'rate_reward_claimed': true,
    });
    await (FontLoader('Baloo')
          ..addFont(rootBundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final state = _HomeState(online: true);
    final promo = _Promo();
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(800, 400),
      const Size(640, 360),
      const Size(390, 780)
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
              home: RepaintBoundary(key: key, child: const HomeScreen()))));
      await tester.runAsync(() => Future.wait([
            for (final asset in [
              HomeArtwork.menu,
              HomeArtwork.friends,
              HomeArtwork.store,
              HomeArtwork.campaign,
              HomeArtwork.modes,
              HomeArtwork.coins,
              HomeArtwork.gems,
              'assets/ui/logo.webp',
              'assets/ui/bg_main.webp'
            ])
              precacheImage(
                  AssetImage(asset), tester.element(find.byType(HomeScreen))),
          ]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('المستوى 2'), findsOneWidget);
      expect(find.text('20/100'), findsOneWidget);
      expect(find.byTooltip('تحدي المراحل'), findsOneWidget);
      expect(find.byTooltip('أوضاع اللعب'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('home-friends-green-dot')), findsOneWidget);
      final coinBounds =
          tester.getRect(find.byKey(const ValueKey('home-coins-balance')));
      final gemBounds =
          tester.getRect(find.byKey(const ValueKey('home-gems-balance')));
      final menuBounds = tester.getRect(find.byTooltip('القائمة'));
      final levelBounds = tester.getRect(find.byType(HomeLevelBadge));
      expect(levelBounds.center.dx, closeTo(size.width / 2, .01));
      expect(coinBounds.left, closeTo(0, .01));
      expect(coinBounds.width, lessThanOrEqualTo(128));
      expect(gemBounds.width, lessThanOrEqualTo(128));
      final logo = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/ui/logo.webp');
      final logoBounds = tester.getRect(logo);
      expect(levelBounds.overlaps(logoBounds), isFalse);
      for (final banner in ['تحدي المراحل', 'أوضاع اللعب']) {
        final bounds = tester.getRect(find.byTooltip(banner));
        expect(bounds.shortestSide, greaterThanOrEqualTo(48));
        expect(bounds.overlaps(logoBounds), isFalse);
      }
      expect(coinBounds.overlaps(gemBounds), isFalse);
      expect(coinBounds.overlaps(menuBounds), isFalse);
      expect(gemBounds.overlaps(menuBounds), isFalse);
      for (final other in [coinBounds, gemBounds, menuBounds]) {
        expect(levelBounds.overlaps(other), isFalse);
      }
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final name = size.width == 800
            ? 'landscape'
            : size.width == 640
                ? 'compact'
                : 'mobile';
        await File('build/home-artwork-$name-ar.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  group('home menu entries', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      await (FontLoader('Baloo')
            ..addFont(rootBundle.load('assets/fonts/baloo.ttf')))
          .load();
      await (FontLoader('NotoSansArabic')
            ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
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
          expect(find.byType(CrossPromoMillionaireBadge), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(CrossPromoMillionaireBadge),
              matching: find.text('تحدي المليون'),
            ),
            findsOneWidget,
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
