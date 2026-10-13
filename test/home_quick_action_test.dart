import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/cross_promo_millionaire_badge.dart';
import 'package:challenge_land/widgets/home_quick_action.dart';
import 'package:challenge_land/widgets/special_offer_badge.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's test harness accompanies the app's existing Firebase dependency.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeState extends ChangeNotifier implements AppState {
  @override
  bool get isOnline => false;
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
          find.byType(CrossPromoMillionaireBadge),
          find.byType(SpecialOfferBadge),
          find
              .ancestor(
                of: find.text('تحدي المراحل'),
                matching: find.byType(GestureDetector),
              )
              .first,
          find
              .ancestor(
                of: find.text('أوضاع اللعب'),
                matching: find.byType(GestureDetector),
              )
              .first,
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/ui/logo.png'),
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
        await tester.tap(find.byKey(const ValueKey('home-friends-shortcut')));
        await tester.pump();
        expect(find.text('تتطلب هذه الميزة اتصالا بالإنترنت'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        // Drain the existing home startup delays after the screen is disposed.
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('home menu entries', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
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
              theme: ThemeData.dark(useMaterial3: true),
              home: const HomeScreen(),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(find.byTooltip('القائمة'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final menu = find.byType(BottomSheet);
          expect(menu, findsOneWidget);
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
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  });
}
