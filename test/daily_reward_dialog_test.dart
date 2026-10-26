import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/models/lucky_wheel_prize.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/screens/home/daily_streak_screen.dart';
import 'package:challenge_land/screens/home/lucky_wheel_screen.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/daily_reward_dialog.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:challenge_land/widgets/lucky_wheel_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Rewards extends ChangeNotifier implements AppState {
  @override
  int streakDay = 1;
  @override
  bool claimedToday = false;
  @override
  bool dailyStreakLoaded = true;
  @override
  bool spinningLuckyWheel = false;
  @override
  String? luckyWheelError;
  @override
  int coins = 1250;
  @override
  int gems = 80;
  int paidSpins = 0;
  int? serverPaidSpins;
  int? previewCharacterIndex = 2;
  @override
  GameCharacter? get wheelPrizeCharacter => previewCharacterIndex == null
      ? null
      : CharacterCatalog.byIndex(previewCharacterIndex!);
  @override
  bool get isCommerceReady => true;
  @override
  String? get economyError => null;
  @override
  EconomyWallet get economyWallet => EconomyWallet(wheelSpins: paidSpins);
  @override
  int get purchasedWheelSpins => paidSpins;
  @override
  bool get canSpinLuckyWheel => !claimedToday || paidSpins > 0;
  @override
  bool get hasPendingLuckyWheelSpin => false;
  Completer<LuckyWheelSpin?>? response;
  int requests = 0;
  @override
  Future<void> loadLevelData() async {}
  @override
  Future<void> loadEconomy() async {
    if (serverPaidSpins != null) paidSpins = serverPaidSpins!;
    notifyListeners();
  }

  @override
  Future<void> refreshWheelPurchases() => loadEconomy();

  @override
  Future<LuckyWheelSpin?> spinLuckyWheel() async {
    requests++;
    final result = await response!.future;
    if (result != null) {
      if (claimedToday) paidSpins--;
      claimedToday = true;
    }
    notifyListeners();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BillingBridge extends NativeBridgeService {
  bool available = true;
  int launches = 0;
  @override
  Future<Map<String, dynamic>> getBillingProducts() async => {
        'available': available,
        'products': [
          if (available) {'id': 'wheel_spins_3', 'price': '₺19,99'}
        ],
      };
  @override
  Future<Map<String, dynamic>> launchBilling(String productId) async {
    expect(productId, 'wheel_spins_3');
    launches++;
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> restorePurchaseState() async =>
      {'success': true, 'pendingCount': 0};
}

Future<void> _purchaseEvent(
    String method, Map<String, dynamic> arguments) async {
  final complete = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
          'millionaire/native',
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall(method, arguments)),
          (_) => complete.complete());
  await complete.future;
}

Widget _app(_Rewards state,
        {Widget? child,
        double textScale = 1,
        bool reducedMotion = false,
        bool useViewport = false,
        InAppPurchaseService? iap}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        if (iap != null)
          ChangeNotifierProvider<InAppPurchaseService>.value(value: iap),
        ChangeNotifierProvider(
            create: (_) => AppSettings(NativeBridgeService())..haptic = false),
      ],
      child: MaterialApp(
          theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Baloo',
                  fontFamilyFallback: const ['NotoSansArabic'])),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion),
              child: useViewport ? GameViewport(child: child!) : child!),
          home: child ?? const DailyStreakScreen()),
    );

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(LuckyWheelScreen));
    for (final path in [
      'assets/store/hud_keys.webp',
      'assets/store/hud_tickets.webp',
      'assets/home/coins.webp',
      'assets/home/gems.webp',
      'assets/characters/fahad.png',
      'assets/ui/box1.png'
    ]) {
      await precacheImage(
          AssetImage(path, bundle: SharedAssets.bundle), context);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(LuckyWheelScreen));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('lucky-wheel-page')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/lucky-wheel-previews').create(recursive: true);
    await File('build/lucky-wheel-previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Baloo', 'assets/fonts/baloo.ttf'),
      ('NotoSansArabic', 'assets/fonts/NotoSansArabic.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')
    ]) {
      await (FontLoader(font.$1)..addFont(SharedAssets.bundle.load(font.$2)))
          .load();
    }
  });

  test('the visible wedges give each quantity variant one equal slot', () {
    expect(LuckyWheelPrize.catalog.length, 12);
    for (final prize in LuckyWheelPrize.catalog) {
      expect(luckyWheelSlots.where((index) => index == prize.index).length, 1);
    }
  });

  testWidgets(
      'winning character stays visible until reveal closes, then advances',
      (tester) async {
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pump();
    expect(
        tester
            .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
            .character
            ?.index,
        2);
    await tester.tap(find.byKey(const ValueKey('lucky-wheel-spin')));
    // Simulates a server result newer than the preview because of another device.
    state.previewCharacterIndex = 9;
    state.response!.complete(LuckyWheelSpin(
        prize: LuckyWheelPrize.catalog[4],
        grants: const {},
        newlyGranted: true,
        characterIndex: 7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
        tester
            .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
            .character
            ?.index,
        7);
    await tester.pump(const Duration(milliseconds: 3900));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('شخصية تاليا'), findsOneWidget);
    expect(
        tester
            .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
            .character
            ?.index,
        7);
    await tester.tap(find.text('رائع، متابعة'));
    await tester.pump();
    expect(
        tester
            .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
            .character
            ?.index,
        9);
    await _capture(tester, 'next-character');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'prize details disclose exact quantity odds and guaranteed chest contents',
      (tester) async {
    final state = _Rewards();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pump();
    await tester.tap(find.text('الجوائز وفرص الفوز'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('كل خانة لها فرصة متساوية: 1 من 12 (نحو 8.33%).'),
        findsOneWidget);
    expect(find.text('8.33%'), findsNWidgets(12));
    expect(
        find.text('1000 نقود + 20 جوهرة + مفتاحان + تذكرتان'), findsOneWidget);
    expect(find.text('250 نقود'), findsOneWidget);
    expect(find.text('20 جوهرة'), findsOneWidget);
    expect(find.text('شخصية فهد'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'complete character roster shows the100-gem replacement on the wheel',
      (tester) async {
    final state = _Rewards()..previewCharacterIndex = null;
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pump();
    final wheel =
        tester.widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork));
    expect(wheel.character, isNull);
    expect(wheel.characterCompensation, isTrue);
    await tester.tap(find.text('الجوائز وفرص الفوز'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('100 جوهرة — اكتملت الشخصيات'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed spin reveals nothing, retry grants once and lands correctly',
      (tester) async {
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pump();
    final button = find.byKey(const ValueKey('lucky-wheel-spin'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(state.requests, 1);
    state.luckyWheelError = 'فشل الاتصال';
    state.response!.complete(null);
    await tester.pump();
    expect(find.text('فشل الاتصال'), findsOneWidget);
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
    state.response = Completer();
    await tester.tap(button);
    state.response!.complete(LuckyWheelSpin(
        prize: LuckyWheelPrize.catalog[3],
        grants: const {'gems': 10},
        newlyGranted: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 700));
    final wheel =
        tester.widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork));
    expect(wheel.winningSlot, luckyWheelSlots.indexOf(3));
    expect((wheel.turns + wheel.winningSlot! / 12) % 1, closeTo(0, .00001));
    expect(find.text('أُضيفت جائزتك إلى حسابك'), findsOneWidget);
    expect(find.text('+10 جواهر'), findsOneWidget);
    expect(state.requests, 2);
    await _capture(tester, 'prize');
    await tester.tap(find.text('رائع، متابعة'));
    await tester.pump();
    expect(find.text('3 لفات إضافية'), findsOneWidget);
    expect(find.byKey(const ValueKey('lucky-wheel-countdown')), findsOneWidget);
    await tester.tap(button);
    expect(state.requests, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion reveals the server prize without spinning',
      (tester) async {
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, reducedMotion: true));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lucky-wheel-spin')));
    state.response!.complete(LuckyWheelSpin(
        prize: LuckyWheelPrize.catalog[5],
        grants: const {'coins': 1000, 'gems': 20, 'keys': 2, 'tickets': 2},
        newlyGranted: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsOneWidget);
    expect(find.text('+2 مفاتيح'), findsOneWidget);
    expect(find.text('+2 تذاكر'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the daily free spin is followed by banked paid spins',
      (tester) async {
    final state = _Rewards()
      ..paidSpins = 2
      ..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, reducedMotion: true));
    await tester.pump();
    final button = find.byKey(const ValueKey('lucky-wheel-spin'));
    await tester.tap(button);
    state.response!.complete(LuckyWheelSpin(
        prize: LuckyWheelPrize.catalog[0],
        grants: const {'keys': 1},
        newlyGranted: true));
    await tester.pump();
    expect(state.paidSpins, 2, reason: 'The free spin is always used first');
    await tester.tap(find.text('رائع، متابعة'));
    await tester.pump();
    expect(find.text('لفاتك الإضافية: 2'), findsOneWidget);
    for (var count = 1; count >= 0; count--) {
      state.response = Completer();
      await tester.tap(button);
      state.response!.complete(LuckyWheelSpin(
          prize: LuckyWheelPrize.catalog[1],
          grants: const {'tickets': 1},
          newlyGranted: true,
          usedFreeSpin: false));
      await tester.pump();
      await tester.tap(find.text('رائع، متابعة'));
      await tester.pump();
      expect(state.paidSpins, count);
    }
    expect(find.text('3 لفات إضافية'), findsOneWidget);
    expect(state.requests, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pack shows live price and only verified delivery unlocks paid spins',
      (tester) async {
    final state = _Rewards()..claimedToday = true;
    final bridge = _BillingBridge();
    final iap = InAppPurchaseService(nativeBridge: bridge);
    addTearDown(state.dispose);
    addTearDown(iap.dispose);
    await tester.pumpWidget(_app(state, iap: iap));
    await tester.pump();
    expect(find.text('3 لفات إضافية'), findsOneWidget);
    expect(find.text('₺19,99'), findsOneWidget);
    await _capture(tester, 'buy-spins');
    final button = find.byKey(const ValueKey('lucky-wheel-spin'));
    await tester.tap(button);
    await tester.pump();
    expect(bridge.launches, 1);
    expect(state.paidSpins, 0);
    await _purchaseEvent('onPurchaseStatus',
        {'productId': 'wheel_spins_3', 'status': 'pending'});
    await tester.pump();
    await tester.tap(button);
    expect(bridge.launches, 1);
    expect(state.requests, 0);
    expect(state.paidSpins, 0);
    state.serverPaidSpins = 3;
    await _purchaseEvent('onPurchaseDelivered', {'productId': 'wheel_spins_3'});
    await tester.pump();
    expect(find.text('لفاتك الإضافية: 3'), findsOneWidget);
    expect(find.text('لفّ الدولاب'), findsOneWidget);
    expect(state.requests, 0,
        reason: 'Buying a pack never spins automatically');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelled and missing Play products never add paid spins',
      (tester) async {
    final state = _Rewards()..claimedToday = true;
    final bridge = _BillingBridge();
    final iap = InAppPurchaseService(nativeBridge: bridge);
    addTearDown(state.dispose);
    addTearDown(iap.dispose);
    await tester.pumpWidget(_app(state, iap: iap));
    await tester.pump();
    final button = find.byKey(const ValueKey('lucky-wheel-spin'));
    await tester.tap(button);
    await tester.pump();
    await _purchaseEvent('onPurchaseStatus',
        {'productId': 'wheel_spins_3', 'status': 'canceled'});
    await tester.pump();
    expect(state.paidSpins, 0);
    bridge.available = false;
    await iap.loadProducts();
    await tester.pump();
    expect(find.text('₺19,99'), findsNothing);
    expect(find.text('السعر غير متاح حاليًا'), findsOneWidget);
    await tester.tap(button);
    expect(bridge.launches, 1);
    expect(state.paidSpins, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final sample in [
    (product: 'gems_80', claimed: false),
    (product: 'wheel_spins_3', claimed: false),
    (product: 'gems_80', claimed: true),
    (product: 'wheel_spins_3', claimed: true),
  ]) {
    testWidgets(
        'landscape phone can spin ${sample.claimed ? 'banked' : 'free'} credit while ${sample.product} payment is pending',
        (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards()
        ..claimedToday = sample.claimed
        ..paidSpins = sample.claimed ? 1 : 0
        ..response = Completer();
      final bridge = _BillingBridge();
      final iap = InAppPurchaseService(nativeBridge: bridge);
      addTearDown(state.dispose);
      addTearDown(iap.dispose);
      await tester.pumpWidget(_app(state, iap: iap, useViewport: true));
      await tester.pump();
      await _purchaseEvent('onPurchaseStatus', {
        'productId': sample.product,
        'status': 'pending',
      });
      await tester.pump();
      expect(iap.isPurchasing, isTrue);
      expect(find.text('لفّ الدولاب'), findsOneWidget);

      final button = find.byKey(const ValueKey('lucky-wheel-spin'));
      await tester.tap(button);
      expect(state.requests, 1,
          reason: 'A pending payment cannot lock an already available spin');
      state.response!.complete(LuckyWheelSpin(
          prize: LuckyWheelPrize.catalog[0],
          grants: const {'keys': 1},
          newlyGranted: true,
          usedFreeSpin: !sample.claimed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      expect(
          tester
              .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
              .turns,
          greaterThan(0));
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsOneWidget);
      expect(find.text('+1 مفاتيح'), findsOneWidget);
      expect(state.paidSpins, 0);
      expect(bridge.launches, 0,
          reason: 'Spinning never opens another payment sheet');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('corner back button returns from the wheel on a landscape phone',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _Rewards();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state,
        useViewport: true,
        child: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                            builder: (_) => const LuckyWheelScreen())),
                    child: const Text('افتح الدولاب'))))));
    await tester.tap(find.text('افتح الدولاب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final back = find.byTooltip('رجوع');
    expect(back, findsOneWidget);
    final backCenter = tester.getCenter(back);
    expect(backCenter.dx, lessThan(90));
    expect(backCenter.dy, lessThan(90));
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(LuckyWheelScreen), findsNothing);
    expect(find.text('افتح الدولاب'), findsOneWidget);
    expect(state.requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final sample in [
    (size: const Size(960, 540), scale: 1.0, claimed: false, name: 'landscape'),
    (size: const Size(900, 400), scale: 1.5, claimed: true, name: 'compact'),
    (size: const Size(438, 780), scale: 1.0, claimed: false, name: 'portrait'),
    (size: const Size(320, 640), scale: 1.5, claimed: true, name: 'small'),
  ]) {
    testWidgets('wheel fits and renders ${sample.name}', (tester) async {
      tester.view.physicalSize = sample.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards()..claimedToday = sample.claimed;
      addTearDown(state.dispose);
      await tester.pumpWidget(_app(state, textScale: sample.scale));
      await tester.pump();
      await _capture(tester, sample.name);
      expect(find.byType(LuckyWheelArtwork), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final claimed in [true, false]) {
    testWidgets(
        'automatic entry stays closed when claimed=$claimed and loaded=$claimed',
        (tester) async {
      final state = _Rewards()
        ..claimedToday = claimed
        ..dailyStreakLoaded = claimed;
      addTearDown(state.dispose);
      late BuildContext context;
      await tester.pumpWidget(_app(state, child: Builder(builder: (ctx) {
        context = ctx;
        return const SizedBox();
      })));
      await DailyRewardDialog.show(context);
      await tester.pump();
      expect(find.byType(LuckyWheelScreen), findsNothing);
      expect(state.requests, 0);
    });
  }
}
