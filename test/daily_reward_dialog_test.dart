import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/lucky_wheel_motion.dart';
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

const _exportWheelMotion = bool.fromEnvironment('EXPORT_WHEEL_MOTION');
const _pointerSettleAllowance = Duration(milliseconds: 650);
const _revealDuration = Duration(milliseconds: 700);

Future<void> _pumpWheelFrames(WidgetTester tester, Duration duration) async {
  var remaining = duration;
  const frame = Duration(milliseconds: 20);
  while (remaining > Duration.zero) {
    final step = remaining < frame ? remaining : frame;
    await tester.pump(step);
    remaining -= step;
  }
}

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
  void updatePreviewCharacter(int? index) {
    previewCharacterIndex = index;
    notifyListeners();
  }

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
  bool get isLuckyWheelFreeAvailable => !claimedToday;
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

Future<void> _capture(WidgetTester tester, String name,
    {double pixelRatio = 2}) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(LuckyWheelScreen));
    for (final path in [
      'assets/lucky_wheel/stage.webp',
      'assets/lucky_wheel/wheel.webp',
      'assets/lucky_wheel/emblem.webp',
      'assets/lucky_wheel/icons/chest.webp',
      'assets/lucky_wheel/icons/coins.webp',
      'assets/lucky_wheel/icons/key.webp',
      'assets/lucky_wheel/icons/gems.webp',
      'assets/lucky_wheel/icons/ticket.webp',
      'assets/lucky_wheel/icons/character_frame.webp',
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
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/lucky-wheel-previews').create(recursive: true);
    await File('build/lucky-wheel-previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void _expectInside(Rect content, Rect bounds) {
  const tolerance = .5;
  expect(content.left, greaterThanOrEqualTo(bounds.left - tolerance));
  expect(content.top, greaterThanOrEqualTo(bounds.top - tolerance));
  expect(content.right, lessThanOrEqualTo(bounds.right + tolerance));
  expect(content.bottom, lessThanOrEqualTo(bounds.bottom + tolerance));
}

String? _imageAsset(Image image) {
  var provider = image.image;
  while (provider is ResizeImage) {
    provider = provider.imageProvider;
  }
  if (provider is AssetImage) return provider.assetName;
  if (provider is ExactAssetImage) return provider.assetName;
  return null;
}

Finder _characterWedge() =>
    find.byKey(const ValueKey('lucky-wheel-character-prize'));

Finder _characterWedgeImages() => find.descendant(
    of: find.byKey(const ValueKey('lucky-wheel-character-icon')),
    matching: find.byType(Image));

void _expectPrizeIconAssets(
    WidgetTester tester, Finder finder, LuckyWheelPrize prize,
    {GameCharacter? character, bool compensation = false}) {
  final assets = tester
      .widgetList<Image>(
          find.descendant(of: finder, matching: find.byType(Image)))
      .map(_imageAsset)
      .whereType<String>()
      .toList();
  final iconName = switch (prize.kind) {
    LuckyWheelPrizeKind.chest => 'chest',
    LuckyWheelPrizeKind.coins => 'coins',
    LuckyWheelPrizeKind.keys => 'key',
    LuckyWheelPrizeKind.gems => 'gems',
    LuckyWheelPrizeKind.tickets => 'ticket',
    LuckyWheelPrizeKind.character => compensation ? 'gems' : 'character_frame',
  };
  expect(assets, contains('assets/lucky_wheel/icons/$iconName.webp'),
      reason: '${prize.id} must use the supplied reward artwork');
  expect(assets, isNot(contains('assets/lucky_wheel/wheel.webp')),
      reason: 'Reward icons must not crop the old baked wheel prizes');
  if (prize.kind == LuckyWheelPrizeKind.character && !compensation) {
    expect(assets, contains(character!.asset),
        reason: 'The supplied portrait frame must contain the actual reward');
  }
}

LuckyWheelArtwork _wheel(WidgetTester tester) =>
    tester.widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork));

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('millionaire/native'),
            (call) async {
      if (call.method == 'playSoundEffect' || call.method == 'playHaptic') {
        return true;
      }
      return null;
    });
  });

  test('the visible wedges give each quantity variant one equal slot', () {
    expect(LuckyWheelPrize.catalog.length, 12);
    for (final prize in LuckyWheelPrize.catalog) {
      expect(luckyWheelSlots.where((index) => index == prize.index).length, 1);
    }
  });

  testWidgets(
      'all twelve wedges, the legend, and prize reveals use the supplied reward icons',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _Rewards()
      ..paidSpins = 12
      ..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(
        _app(state, child: const LuckyWheelScreen(), reducedMotion: true));
    await tester.pump();

    final wedges = find.descendant(
        of: find.byKey(const ValueKey('lucky-wheel-rotating-disc')),
        matching: find.byType(LuckyWheelPrizeIcon));
    expect(wedges, findsNWidgets(12));
    expect(
        tester
            .widgetList<LuckyWheelPrizeIcon>(wedges)
            .map((icon) => icon.prize.id),
        unorderedEquals(LuckyWheelPrize.catalog.map((prize) => prize.id)));
    final allIcons = find.byType(LuckyWheelPrizeIcon);
    expect(allIcons, findsNWidgets(18),
        reason:
            'The twelve wedges and six legend items share the same artwork');
    for (final element in allIcons.evaluate()) {
      final icon = element.widget as LuckyWheelPrizeIcon;
      _expectPrizeIconAssets(
          tester,
          find.byElementPredicate((candidate) => candidate == element),
          icon.prize,
          character: icon.character,
          compensation: icon.characterCompensation);
    }

    for (final prize in LuckyWheelPrize.catalog) {
      state.response = Completer();
      await tester.tap(find.byKey(const ValueKey('lucky-wheel-spin')));
      state.response!.complete(LuckyWheelSpin(
          prize: prize,
          grants: prize.grants,
          newlyGranted: true,
          characterIndex:
              prize.kind == LuckyWheelPrizeKind.character ? 7 : null));
      await tester.pump();
      final result = find.byKey(const ValueKey('lucky-wheel-result'));
      expect(result, findsOneWidget);
      final iconFinder = find.descendant(
          of: result, matching: find.byType(LuckyWheelPrizeIcon));
      expect(iconFinder, findsOneWidget);
      expect(tester.widget<LuckyWheelPrizeIcon>(iconFinder).prize.id, prize.id);
      _expectPrizeIconAssets(tester, iconFinder, prize,
          character: CharacterCatalog.byIndex(7));
      final wheel = _wheel(tester);
      expect(wheel.winningSlot, luckyWheelSlots.indexOf(prize.index));
      expect((wheel.turns + wheel.winningSlot! / 12) % 1, closeTo(0, .00001));
      expect(wheel.pointerAngle, closeTo(0, .004));
      await tester.tap(find.text('رائع، متابعة'));
      await tester.pump();
    }
    expect(state.requests, 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'wheel accelerates, slows, and releases its pointer before revealing the server prize',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, child: const LuckyWheelScreen()));
    await tester.pump();

    // Rim lighting is independent of the physical pointer.
    await tester.pump(const Duration(milliseconds: 600));
    expect(_wheel(tester).turns, 0);
    expect(_wheel(tester).pointerAngle, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_wheel(tester).pointerAngle, 0);
    await _capture(tester, 'motion-idle');

    await tester.tap(find.byKey(const ValueKey('lucky-wheel-spin')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_wheel(tester).turns, 0,
        reason: 'Animation must wait for the committed server prize');
    expect(_wheel(tester).pointerAngle, 0);
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
    state.response!.complete(LuckyWheelSpin(
        prize: LuckyWheelPrize.catalog[8],
        grants: const {'coins': 250},
        newlyGranted: true));
    await tester.pump();

    final samples = <({int millis, double turns, double angle})>[];
    var elapsed = Duration.zero;
    var previousTurns = _wheel(tester).turns;
    var motionFrame = 0;
    var capturedTailContact = false;
    final total =
        luckyWheelSpinDuration + _pointerSettleAllowance + _revealDuration;

    Future<void> captureMotionFrame() async {
      if (!_exportWheelMotion) return;
      await _capture(
          tester, 'motion-frame-${motionFrame.toString().padLeft(3, '0')}',
          pixelRatio: .75);
      motionFrame++;
    }

    await captureMotionFrame();
    await _capture(tester, 'motion-start');
    while (elapsed < total) {
      const frame = Duration(milliseconds: 20);
      final remaining = total - elapsed;
      final step = remaining < frame ? remaining : frame;
      await tester.pump(step);
      elapsed += step;
      final wheel = _wheel(tester);
      expect(wheel.turns, greaterThanOrEqualTo(previousTurns - .0000001),
          reason: 'Wheel rotation must never reverse during the spin');
      previousTurns = wheel.turns;
      samples.add((
        millis: elapsed.inMilliseconds,
        turns: wheel.turns,
        angle: wheel.pointerAngle,
      ));
      if (elapsed < luckyWheelSpinDuration ~/ 2) {
        expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
      }
      if (elapsed.inMilliseconds % 80 == 0) await captureMotionFrame();
      if (elapsed.inMilliseconds == 400) {
        await _capture(tester, 'motion-accelerating');
      } else if (elapsed.inMilliseconds == 1200) {
        await _capture(tester, 'motion-fast');
      } else if (elapsed.inMilliseconds == 3500) {
        await _capture(tester, 'motion-slowing');
      }
      if (!capturedTailContact &&
          elapsed > luckyWheelSpinDuration * .65 &&
          elapsed < luckyWheelSpinDuration &&
          wheel.pointerAngle.abs() > .04) {
        capturedTailContact = true;
        await _capture(tester, 'motion-pointer-contact');
      }
    }
    await captureMotionFrame();

    double turnsAt(int millis) =>
        samples.firstWhere((sample) => sample.millis >= millis).turns;
    final interval = (luckyWheelSpinDuration.inMilliseconds * .08).floor();
    final fastStart = (luckyWheelSpinDuration.inMilliseconds * .25).floor();
    final earlyTravel = turnsAt(interval);
    final fastTravel = turnsAt(fastStart + interval) - turnsAt(fastStart);
    final tailTravel = turnsAt(luckyWheelSpinDuration.inMilliseconds) -
        turnsAt(luckyWheelSpinDuration.inMilliseconds - interval);
    expect(fastTravel, greaterThan(earlyTravel),
        reason: 'The motor must visibly accelerate from its initial rest');
    expect(fastTravel, greaterThan(tailTravel * 2),
        reason: 'Friction must make the final approach slower than the coast');
    final tail = samples.where((sample) =>
        sample.millis > luckyWheelSpinDuration.inMilliseconds * .65);
    expect(tail.any((sample) => sample.angle > .01), isTrue);
    expect(tail.any((sample) => sample.angle < -.001), isTrue,
        reason: 'The released pointer must rebound rather than stick to a peg');
    expect(capturedTailContact, isTrue);
    final wheel = _wheel(tester);
    expect(wheel.pointerAngle, closeTo(0, .004));
    expect(wheel.winningSlot, luckyWheelSlots.indexOf(8));
    expect((wheel.turns + wheel.winningSlot! / 12) % 1, closeTo(0, .00001));
    expect(find.text('250 نقود'), findsOneWidget);
    expect(find.text('+250 نقود'), findsOneWidget);
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsOneWidget);
    expect(state.requests, 1);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'motion-settled-result');
    await tester.pumpWidget(const SizedBox());
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
    await _pumpWheelFrames(
        tester,
        luckyWheelSpinDuration -
            const Duration(milliseconds: 200) +
            _pointerSettleAllowance);
    await tester.pump(_revealDuration);
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
    final halfway = luckyWheelSpinDuration ~/ 2;
    await _pumpWheelFrames(tester, halfway);
    expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
    await _pumpWheelFrames(
        tester, luckyWheelSpinDuration - halfway + _pointerSettleAllowance);
    await tester.pump(_revealDuration);
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
      final halfway = luckyWheelSpinDuration ~/ 2;
      await _pumpWheelFrames(tester, halfway);
      expect(
          tester
              .widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork))
              .turns,
          greaterThan(0));
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
      await _pumpWheelFrames(
          tester, luckyWheelSpinDuration - halfway + _pointerSettleAllowance);
      await tester.pump(_revealDuration);
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsOneWidget);
      expect(find.text('+1 مفاتيح'), findsOneWidget);
      expect(state.paidSpins, 0);
      expect(bridge.launches, 0,
          reason: 'Spinning never opens another payment sheet');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'right corner back button returns from the wheel on a landscape phone',
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
    final pageBounds =
        tester.getRect(find.byKey(const ValueKey('lucky-wheel-page')));
    expect(backCenter.dx, greaterThan(pageBounds.right - 90));
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

  for (final sample in [
    (size: const Size(960, 540), scale: 1.0, name: 'reference-960x540'),
    (size: const Size(1280, 720), scale: 1.0, name: 'reference-1280x720'),
    (size: const Size(800, 450), scale: 1.0, name: 'reference-800x450'),
    (size: const Size(800, 360), scale: 1.0, name: 'reference-compact-800x360'),
    (size: const Size(960, 540), scale: 1.5, name: 'reference-large-text'),
  ]) {
    testWidgets(
        'landscape wheel keeps its artwork and spin action visible at ${sample.size} text scale ${sample.scale}',
        (tester) async {
      tester.view.physicalSize = sample.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards()..response = Completer();
      addTearDown(state.dispose);
      await tester.pumpWidget(_app(state,
          child: const LuckyWheelScreen(), textScale: sample.scale));
      await tester.pump();

      final bounds = Offset.zero & sample.size;
      final wheel = find.byType(LuckyWheelArtwork);
      final spin = find.byKey(const ValueKey('lucky-wheel-spin'));
      final back = find.byKey(const ValueKey('lucky-wheel-back'));
      expect(wheel, findsOneWidget);
      expect(spin.hitTestable(), findsOneWidget,
          reason: 'The primary action must be usable before scrolling');
      expect(back.hitTestable(), findsOneWidget);
      final wheelBounds = tester.getRect(wheel);
      final spinBounds = tester.getRect(spin);
      _expectInside(wheelBounds, bounds);
      _expectInside(spinBounds, bounds);
      _expectInside(tester.getRect(back), bounds);
      expect(wheelBounds.width, closeTo(wheelBounds.height, .5),
          reason: 'Responsive layout must preserve the circular wheel');
      expect(wheelBounds.height, greaterThan(sample.size.height * .5));
      expect(wheelBounds.overlaps(spinBounds), isFalse,
          reason: 'The spin action cannot cover prize wedges');
      expect(spinBounds.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      await _capture(tester, sample.name);

      await tester.tap(spin);
      await tester.pump();
      expect(state.requests, 1,
          reason: 'A correctly positioned button must also accept input');
      state.response!.complete(null);
      await tester.pump();
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);

      final details = find.text('الجوائز وفرص الفوز');
      await tester.ensureVisible(details);
      await tester.pump();
      await tester.tap(details);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('كل خانة لها فرصة متساوية: 1 من 12 (نحو 8.33%).'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('wide phone viewport keeps wheel controls clear of safe edges',
      (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 3;
    tester.view.padding =
        const FakeViewPadding(left: 120, right: 60, bottom: 24);
    tester.view.viewPadding =
        const FakeViewPadding(left: 120, right: 60, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final state = _Rewards()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(
        _app(state, child: const LuckyWheelScreen(), useViewport: true));
    await tester.pump();

    // Flutter reports geometry in logical pixels; these insets model a cutout
    // and gesture edge on a 2340x1080 physical-pixel, 3x landscape phone.
    const safeBounds = Rect.fromLTRB(40, 0, 760, 352);
    final wheel = find.byType(LuckyWheelArtwork);
    final spin = find.byKey(const ValueKey('lucky-wheel-spin'));
    final back = find.byKey(const ValueKey('lucky-wheel-back'));
    _expectInside(tester.getRect(wheel), safeBounds);
    _expectInside(tester.getRect(spin), safeBounds);
    _expectInside(tester.getRect(back), safeBounds);
    expect(spin.hitTestable(), findsOneWidget);
    expect(back.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'reference-safe-phone-2340x1080');
    await tester.tap(spin);
    await tester.pump();
    expect(state.requests, 1);
    state.response!.complete(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final compensation in [false, true]) {
    testWidgets(
        'live character wedge uses the ${compensation ? 'server gem replacement' : 'server character portrait'} during rotation',
        (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _Rewards()
        ..previewCharacterIndex = 2
        ..response = Completer();
      addTearDown(state.dispose);
      await tester.pumpWidget(_app(state, child: const LuckyWheelScreen()));
      await tester.pump();

      final liveLabel =
          find.byKey(const ValueKey('lucky-wheel-character-label'));
      final liveIcon = find.byKey(const ValueKey('lucky-wheel-character-icon'));
      expect(_characterWedge(), findsOneWidget);
      expect(tester.widget<Text>(liveLabel).data,
          CharacterCatalog.byIndex(2).nameAr);
      expect(tester.widgetList<Image>(_characterWedgeImages()).map(_imageAsset),
          contains(CharacterCatalog.byIndex(2).asset));

      await tester.tap(find.byKey(const ValueKey('lucky-wheel-spin')));
      // Account refreshes cannot replace the frozen spin preview while waiting
      // for its receipt; the server award then owns the rotating live wedge.
      state.updatePreviewCharacter(9);
      await tester.pump();
      expect(tester.widget<Text>(liveLabel).data,
          CharacterCatalog.byIndex(2).nameAr);
      state.response!.complete(LuckyWheelSpin(
          prize: LuckyWheelPrize.catalog[4],
          grants: compensation ? const {'gems': 100} : const {},
          newlyGranted: true,
          characterIndex: compensation ? null : 7,
          compensation: compensation));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final artwork =
          tester.widget<LuckyWheelArtwork>(find.byType(LuckyWheelArtwork));
      final icon = tester.widget<LuckyWheelPrizeIcon>(liveIcon);
      expect(artwork.turns, greaterThan(0));
      expect(find.byKey(const ValueKey('lucky-wheel-result')), findsNothing);
      expect(icon.characterCompensation, compensation);
      expect(tester.widget<Text>(liveLabel).data,
          compensation ? '100' : CharacterCatalog.byIndex(7).nameAr);
      final paintedAssets = tester
          .widgetList<Image>(_characterWedgeImages())
          .map(_imageAsset)
          .whereType<String>()
          .toList();
      if (compensation) {
        expect(icon.character, isNull);
        expect(paintedAssets, isNotEmpty);
        expect(paintedAssets.where((asset) => asset.contains('/characters/')),
            isEmpty,
            reason: 'A compensated wedge must draw gems, not a stock portrait');
      } else {
        expect(icon.character?.index, 7);
        expect(paintedAssets, contains(CharacterCatalog.byIndex(7).asset));
        expect(
            paintedAssets, isNot(contains(CharacterCatalog.byIndex(2).asset)));
        expect(
            paintedAssets, isNot(contains(CharacterCatalog.byIndex(9).asset)));
      }
      expect(tester.takeException(), isNull);
      await _capture(
          tester,
          compensation
              ? 'reference-compensation-spin'
              : 'reference-character-spin');
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
