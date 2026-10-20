import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/models/store_catalog.dart';
import 'package:challenge_land/screens/home/store_screen.dart';
import 'package:challenge_land/services/ad_service.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/game_store_widgets.dart';
import 'package:challenge_land/widgets/special_offer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// These providers exercise the real store without initializing a Firebase app,
// real authentication, ads, or payment credentials.
class _StoreAppState extends ChangeNotifier implements AppState {
  @override
  EconomyWallet economyWallet = EconomyWallet.fromMap({
    'dailyKeys': 2,
    'keys': 8,
    'dailyHearts': 3,
    'hearts': 6,
    'tickets': 8,
    'offers': {
      'keys_1': {'resource': 'keys', 'amount': 1, 'coins': 700, 'gems': 7},
      'keys_3': {'resource': 'keys', 'amount': 3, 'coins': 1800, 'gems': 18},
      'hearts_1': {'resource': 'hearts', 'amount': 1, 'coins': 600, 'gems': 6},
      'hearts_3': {
        'resource': 'hearts',
        'amount': 3,
        'coins': 1500,
        'gems': 15
      },
      'tickets_1': {
        'resource': 'tickets',
        'amount': 1,
        'coins': 900,
        'gems': 9
      },
      'tickets_3': {
        'resource': 'tickets',
        'amount': 3,
        'coins': 2400,
        'gems': 24
      },
      'play_bundle': {
        'grants': {'keys': 3, 'hearts': 3, 'tickets': 3},
        'coins': 5100,
        'gems': 51
      },
      'play_bundle_large': {
        'grants': {'keys': 10, 'hearts': 10, 'tickets': 10},
        'coins': 16000,
        'gems': 160
      },
    },
  });
  bool economyReady = true;
  String? economyFailure;
  int rentalHours = 0;
  final economyActions = <Map<String, dynamic>>[];
  @override
  bool get economyLoaded => economyReady;
  @override
  String? get economyError => economyFailure;
  @override
  Future<void> loadEconomy() async {}
  @override
  Future<void> economyAction(Map<String, dynamic> data) async {
    economyActions.add(data);
  }

  @override
  Future<bool> claimAdResource(String resource) async {
    economyActions.add({'action': 'adReward', 'resource': resource});
    return true;
  }

  bool canClaimVip = false;
  @override
  bool get canClaimVipBonus => canClaimVip;
  @override
  Future<bool> claimVipBonus() async {
    economyActions.add({'action': 'claimVipBonus'});
    return true;
  }

  bool commerceReady = true;
  bool claimedDaily = false;
  bool membershipActive = false;
  @override
  bool get isCommerceReady => commerceReady;
  @override
  int get coins => 12500;
  @override
  int get gems => 450;
  @override
  int get level => 7;
  @override
  bool get isVip => membershipActive;
  @override
  bool get hasPermanentCategoryPass => false;
  @override
  int get vipExpiresAtMillis => 0;
  @override
  bool get categoryStateLoaded => true;
  @override
  Set<String> get ownedStoreProducts => <String>{};
  @override
  List<String> get unlockedCategories => <String>[];
  @override
  bool get dailyStreakLoaded => true;
  @override
  bool get claimedToday => claimedDaily;
  @override
  bool get isOnline => true;
  @override
  int get streakDay => 3;
  @override
  get user => null;
  @override
  Map<String, int> get todayReward => const {'coins': 200, 'gems': 1};
  @override
  GameCharacter get selectedCharacter => CharacterCatalog.byIndex(1);
  @override
  final Set<int> purchasedCharacters = <int>{};
  @override
  bool isCharacterUnlocked(GameCharacter character) =>
      character.unlock.isFree ||
      purchasedCharacters.contains(character.index) ||
      (character.unlock.isLevelGated && character.unlock.value <= level);
  @override
  bool isCategoryUnlocked(String categoryName) => rentalHours > 0;
  @override
  int getCategoryRemainingRentalHours(String categoryName) => rentalHours;
  @override
  Future<void> loadCurrency() async {}
  @override
  Future<void> loadCategoryState() async {}
  @override
  Future<void> loadCharacterState() async {}
  @override
  Future<void> loadLevelData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreSettings extends ChangeNotifier implements AppSettings {
  _StoreSettings({this.arabic = false});
  final bool arabic;
  @override
  bool get isArabic => arabic;
  @override
  String get languageCode => arabic ? 'ar' : 'en';
  @override
  Locale get locale => Locale(languageCode);
  @override
  Future<bool> playHaptic({String style = 'light', bool force = false}) async =>
      true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreAds extends AdService {
  bool available = true;
  int remaining = 5;
  int watchRequests = 0;
  int actionAdRequests = 0;
  bool actionAdResult = true;
  @override
  bool get canWatchAd => available && remaining > 0;
  @override
  int get watchesLeft => remaining;
  @override
  Duration get cooldownRemaining =>
      available ? Duration.zero : const Duration(minutes: 30);
  @override
  Future<Map<String, int>?> showRewardedAd() async {
    watchRequests++;
    return null;
  }

  @override
  Future<bool> showActionRewardedAd() async {
    actionAdRequests++;
    return actionAdResult;
  }
}

class _StorePromo extends ChangeNotifier implements CrossPromoService {
  bool installed = false;
  bool claimed = false;
  bool claiming = false;
  int claimRequests = 0;
  @override
  bool get isMillionaireInstalled => installed;
  @override
  bool get isRewardClaimed => claimed;
  @override
  bool get isClaiming => claiming;
  @override
  Future<bool> checkInstallation() async => installed;
  @override
  Future<bool> checkRewardClaimed({String? uid}) async => claimed;
  @override
  Future<CrossPromoClaimResult> claimDownloadReward(
      BuildContext context) async {
    claimRequests++;
    return CrossPromoClaimResult.failed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late NativeBridgeService bridge;
  late InAppPurchaseService purchases;
  late _StoreAppState app;
  late _StoreSettings settings;
  late AdService ads;
  late _StorePromo promo;
  late List<MethodCall> calls;
  late Future<Map<String, dynamic>> Function() loadCatalog;

  Map<String, dynamic> availableCatalog() => {
        'available': true,
        'products': [
          for (final product in StoreCatalog.products)
            {
              'id': product.id,
              'price': product.id == 'vip_monthly' ? '₺149,99' : '₺39,99',
              'currencyCode': 'TRY',
              'rawPrice': product.id == 'vip_monthly' ? 149.99 : 39.99,
              'billingPeriod':
                  product.kind == StoreProductKind.subscription ? 'P1M' : '',
              'available': true,
            }
        ],
      };

  setUpAll(() async {
    // Widget tests normally use Ahem. Load the actual app font for meaningful
    // text measurements and the exported preview.
    final font = FontLoader('Baloo')
      ..addFont(rootBundle.load('assets/fonts/baloo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final arabicFont = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await arabicFont.load();
  });

  setUp(() {
    calls = [];
    loadCatalog = () async => availableCatalog();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getBillingProducts') return loadCatalog();
      if (call.method == 'launchBilling') return {'success': true};
      if (call.method == 'manageSubscriptions') return true;
      return null;
    });
    bridge = NativeBridgeService();
    purchases = InAppPurchaseService(nativeBridge: bridge);
    app = _StoreAppState();
    settings = _StoreSettings();
    ads = _StoreAds();
    promo = _StorePromo();
  });

  tearDown(() {
    purchases.dispose();
    app.dispose();
    settings.dispose();
    ads.dispose();
    promo.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(WidgetTester tester, Size size,
      {StoreProductKind? initialKind,
      GlobalKey? repaintKey,
      double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<AdService>.value(value: ads),
        ChangeNotifierProvider<CrossPromoService>.value(value: promo),
        ChangeNotifierProvider<InAppPurchaseService>.value(value: purchases),
        Provider<NativeBridgeService>.value(value: bridge),
      ],
      child: MaterialApp(
        locale: settings.locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Baloo',
              fontFamilyFallback: const ['NotoSansArabic']),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: repaintKey,
          child: StoreScreen(initialKind: initialKind),
        ),
      ),
    ));
  }

  Future<void> assertClean(WidgetTester tester, String location) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: location);
  }

  void assertCenteredTitles(WidgetTester tester) {
    final titles = find.byWidgetPredicate((widget) =>
        widget is GameStoreText && widget.size == 23 && widget.maxLines == 2);
    expect(titles, findsWidgets);
    for (final title in titles.evaluate()) {
      expect(tester.getCenter(find.byWidget(title.widget)).dx,
          closeTo(tester.view.physicalSize.width / 2, .5),
          reason: 'Section title: ${(title.widget as GameStoreText).text}');
    }
  }

  Future<void> select(WidgetTester tester, String tab) async {
    if (find.byTooltip(tab).evaluate().isEmpty &&
        (tab == 'Coins' || tab == 'النقود')) {
      await tester.tap(find.byTooltip(tab == 'Coins' ? 'Featured' : 'المميزة'));
      await assertClean(tester, 'Open featured currency section');
    }
    final label = find.byTooltip(tab).first;
    await Scrollable.ensureVisible(tester.element(label), alignment: 0.1);
    await tester.pumpAndSettle();
    await tester.tap(label);
    await assertClean(tester, 'Tab $tab');
  }

  for (final viewport in <Size>[
    const Size(800, 360),
    const Size(640, 320),
    const Size(1100, 700),
  ]) {
    testWidgets(
        'all five English store tabs fit ${viewport.width.toInt()}x${viewport.height.toInt()} without overflow',
        (tester) async {
      await mount(tester, viewport);
      await assertClean(tester, 'Featured initial layout');
      assertCenteredTitles(tester);
      expect(find.text('SPECIAL OFFERS'), findsOneWidget);
      expect(find.text('Starter bundle'), findsOneWidget);

      for (final entry in const <String, String>{
        'Gems': 'More gems. More possibilities.',
        'Coins': 'Coins for your collection',
        'Membership': 'A richer experience, every month',
        'Categories & characters': 'Build your own collection',
        'Featured': 'Starter bundle',
      }.entries) {
        await select(tester, entry.key);
        assertCenteredTitles(tester);
        expect(find.text(entry.value), findsOneWidget);
        // Exercise the bottom of the page too, including optional rewards,
        // exchanges, category cards, and footer actions.
        final list = tester.widget<ListView>(find.byType(ListView));
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
        await assertClean(tester, '${entry.key} scrolled footer');
        expect(find.text('Restore purchases'), findsOneWidget);
      }
      expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('offer carousel changes the bundle without starting a purchase',
      (tester) async {
    await mount(tester, const Size(390, 780));
    await assertClean(tester, 'Offer carousel');
    expect(find.text('Starter bundle'), findsOneWidget);
    expect(
        tester
            .widget<Image>(
                find.byKey(const ValueKey('store-offer-pack_starter')))
            .image,
        isA<AssetImage>().having((image) => image.assetName, 'asset',
            'assets/store/offer_starter.webp'));
    await tester.tap(find.byTooltip('Next offer').first);
    await assertClean(tester, 'Next bundle');
    expect(find.text('Explorer bundle'), findsOneWidget);
    expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('store-offer-pack_value')))
            .image,
        isA<AssetImage>().having((image) => image.assetName, 'asset',
            'assets/store/offer_explorer.webp'));
    expect(find.textContaining('35,000'), findsOneWidget);
    expect(find.text(' 600'), findsOneWidget);
    await tester.tap(find.byTooltip('Next offer').first);
    await assertClean(tester, 'Champion bundle');
    expect(
        tester
            .widget<Image>(
                find.byKey(const ValueKey('store-offer-pack_champion')))
            .image,
        isA<AssetImage>().having((image) => image.assetName, 'asset',
            'assets/store/offer_champion.webp'));
    expect(find.text('Champion bundle'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offer carousel auto-advances offers periodically',
      (tester) async {
    await mount(tester, const Size(390, 780));
    await assertClean(tester, 'Offer carousel initial');
    expect(find.text('Starter bundle'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Explorer bundle'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Champion bundle'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Starter bundle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'supplied banner uses its live price and opens the matching review',
      (tester) async {
    loadCatalog = () async {
      final catalog = availableCatalog();
      for (final product in catalog['products'] as List) {
        if (product['id'] == 'pack_value') product['price'] = '₺79,99';
      }
      return catalog;
    };
    await mount(tester, const Size(1100, 600));
    await assertClean(tester, 'Supplied banner prices');
    await tester.tap(find.byTooltip('Next offer').first);
    await assertClean(tester, 'Explorer artwork price');
    expect(find.widgetWithText(FilledButton, '₺79,99'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store-offer-pack_value')));
    await assertClean(tester, 'Explorer review');
    expect(find.text('Explorer bundle'), findsWidgets);
    expect(find.text('₺79,99'), findsWidgets);
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in [StoreProductKind.coins, StoreProductKind.gems]) {
    testWidgets('$kind cards and price buttons have matching bounds',
        (tester) async {
      await mount(tester, const Size(800, 360), initialKind: kind);
      await assertClean(tester, 'Currency artwork alignment');
      final ids = kind == StoreProductKind.coins
          ? ['coins_5000', 'coins_25000', 'coins_100000']
          : ['gems_80', 'gems_500', 'gems_1200'];
      final firstCard = tester
          .getRect(find.byKey(ValueKey('store-currency-card-${ids.first}')));
      final firstPrice =
          tester.getRect(find.byKey(ValueKey('store-price-${ids.first}')));
      for (final id in ids) {
        final artwork = find.byKey(ValueKey('store-product-$id'));
        expect(
            tester.widget<Image>(artwork).image,
            isA<AssetImage>().having(
                (image) => image.assetName, 'asset', 'assets/store/$id.webp'));
        final card =
            tester.getRect(find.byKey(ValueKey('store-currency-card-$id')));
        final price = tester.getRect(find.byKey(ValueKey('store-price-$id')));
        expect(card.size, firstCard.size);
        expect(card.top, firstCard.top);
        expect(card.bottom, firstCard.bottom);
        expect(price.size, firstPrice.size);
        expect(price.top, firstPrice.top);
        expect(price.bottom, firstPrice.bottom);
        expect(card.height, lessThan(360 - 100));
      }
      expect(
          find.descendant(
              of: find.byType(GameStoreCurrencyCard),
              matching: find.byType(GameStoreGlossySurface)),
          findsNWidgets(3));
      expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('coin and gem rows share card and price dimensions on mobile',
      (tester) async {
    await mount(tester, const Size(390, 780));
    await assertClean(tester, 'Mobile shared card sizing');
    Size? cardSize;
    Size? priceSize;
    double? priceOffset;
    for (final id in [
      'coins_5000',
      'coins_25000',
      'coins_100000',
      'gems_80',
      'gems_500',
      'gems_1200'
    ]) {
      final card =
          tester.getRect(find.byKey(ValueKey('store-currency-card-$id')));
      final price = tester.getRect(find.byKey(ValueKey('store-price-$id')));
      cardSize ??= card.size;
      priceSize ??= price.size;
      priceOffset ??= price.top - card.top;
      expect(card.width, closeTo(cardSize.width, .001));
      expect(card.height, closeTo(cardSize.height, .001));
      expect(price.width, closeTo(priceSize.width, .001));
      expect(price.height, closeTo(priceSize.height, .001));
      expect(price.top - card.top, closeTo(priceOffset, .001));
    }
    expect(
        find.descendant(
            of: find.byType(GameStoreCurrencyCard),
            matching: find.byType(GameStoreGlossySurface)),
        findsNWidgets(6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'reward artwork is aligned and reflects claim and cooldown states',
      (tester) async {
    ads.dispose();
    final rewardAds = _StoreAds();
    ads = rewardAds;
    await mount(tester, const Size(800, 600));
    await assertClean(tester, 'Reward artwork');
    for (final id in ['daily', 'watch']) {
      expect(
          tester
              .widget<Image>(find.byKey(ValueKey('store-reward-art-$id')))
              .image,
          isA<AssetImage>().having((image) => image.assetName, 'asset',
              'assets/store/reward_$id.webp'));
    }
    final daily =
        tester.getRect(find.byKey(const ValueKey('store-reward-daily')));
    final watch =
        tester.getRect(find.byKey(const ValueKey('store-reward-watch')));
    expect(daily.top, watch.top);
    expect(daily.height, watch.height);
    final dailyButton = find.descendant(
        of: find.byKey(const ValueKey('store-reward-action-daily')),
        matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(dailyButton).onPressed, isNull);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CLAIMED'), findsNothing);
    app.claimedDaily = true;
    app.notifyListeners();
    rewardAds.available = false;
    rewardAds.notifyListeners();
    await assertClean(tester, 'Claimed and cooldown states');
    expect(find.text('CLAIMED'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    final watchButton = find.descendant(
        of: find.byKey(const ValueKey('store-reward-action-watch')),
        matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(watchButton).onPressed, isNull);
    rewardAds.remaining = 0;
    rewardAds.notifyListeners();
    await assertClean(tester, 'Daily ad limit');
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(rewardAds.watchRequests, 0);
    expect(calls.where((call) => call.method == 'grantCurrency'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reward artwork launches ads without granting an unearned reward',
      (tester) async {
    ads.dispose();
    final rewardAds = _StoreAds();
    ads = rewardAds;
    await mount(tester, const Size(800, 600));
    await assertClean(tester, 'Watch reward artwork');
    final banner = find.byKey(const ValueKey('store-reward-watch'));
    await Scrollable.ensureVisible(tester.element(banner), alignment: .3);
    await tester.pumpAndSettle();
    await tester.tap(banner);
    await assertClean(tester, 'Ad returned without a reward');
    expect(rewardAds.watchRequests, 1);
    expect(calls.where((call) => call.method == 'grantCurrency'), isEmpty);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'return reward cards use live amounts, counters and claimed states',
      (tester) async {
    ads.dispose();
    final rewardAds = _StoreAds()..remaining = 3;
    ads = rewardAds;
    await mount(tester, const Size(800, 360),
        initialKind: StoreProductKind.gems);
    await assertClean(tester, 'Return reward designs');
    expect(find.text('A reason to come back'), findsOneWidget);
    Rect? first;
    for (final id in ['daily', 'watch', 'download']) {
      final image = find.byKey(ValueKey('store-return-art-$id'));
      expect(
          tester.widget<Image>(image).image,
          isA<AssetImage>().having((image) => image.assetName, 'asset',
              'assets/store/return_$id.webp'));
      final bounds = tester.getRect(find.byKey(ValueKey('store-return-$id')));
      first ??= bounds;
      expect(bounds.width, closeTo(first.width, .001));
      expect(bounds.height, closeTo(first.height, .001));
      expect(bounds.top, closeTo(first.top, .001));
    }
    expect(find.text('Day 3 of your streak'), findsOneWidget);
    expect(find.text('200 coins'), findsOneWidget);
    expect(find.text('3 of 5 watches left today'), findsOneWidget);
    expect(find.text('Download & earn 80 gems'), findsOneWidget);
    expect(find.text('Reward claimed ✓'), findsNothing);
    app.claimedDaily = true;
    app.notifyListeners();
    promo.claimed = true;
    promo.notifyListeners();
    rewardAds.available = false;
    rewardAds.notifyListeners();
    await assertClean(tester, 'Return reward account states');
    expect(find.text('Claimed • Come back tomorrow'), findsOneWidget);
    expect(find.text('Reward claimed ✓'), findsOneWidget);
    expect(find.text('Available in 30 min'), findsOneWidget);
    for (final id in ['daily', 'watch', 'download']) {
      final button = find.descendant(
          of: find.byKey(ValueKey('store-return-action-$id')),
          matching: find.byType(FilledButton));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    }
    expect(calls.where((call) => call.method == 'grantCurrency'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'download reward design uses verified claiming without a false success',
      (tester) async {
    promo.installed = true;
    await mount(tester, const Size(800, 600),
        initialKind: StoreProductKind.gems);
    await assertClean(tester, 'Installed download reward');
    final claim = find.byKey(const ValueKey('store-return-action-download'));
    await Scrollable.ensureVisible(tester.element(claim), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(claim);
    await assertClean(tester, 'Download reward verification failed');
    expect(promo.claimRequests, 1);
    expect(find.text('80 Gems Claimed ✓'), findsNothing);
    expect(find.text('Claim 80 Gems Now'), findsOneWidget);
    expect(calls.where((call) => call.method == 'grantCurrency'), isEmpty);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'gem artwork uses the live price and opens its own purchase review',
      (tester) async {
    loadCatalog = () async {
      final catalog = availableCatalog();
      for (final product in catalog['products'] as List) {
        if (product['id'] == 'gems_500') product['price'] = '₺99,99';
      }
      return catalog;
    };
    await mount(tester, const Size(800, 600),
        initialKind: StoreProductKind.gems);
    await assertClean(tester, 'Gem artwork live price');
    expect(find.widgetWithText(FilledButton, '₺99,99'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store-product-gems_500')));
    await assertClean(tester, 'Gem chest review');
    expect(find.text('Gem chest'), findsOneWidget);
    expect(find.text('₺99,99'), findsWidgets);
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'coin card opens the matching review and cancellation skips billing',
      (tester) async {
    await mount(tester, const Size(800, 600),
        initialKind: StoreProductKind.coins);
    await assertClean(tester, 'Coin cards');
    await tester.tap(find.widgetWithText(FilledButton, '₺39,99').first);
    await assertClean(tester, 'Coin review');
    expect(find.text('Coin pouch'), findsOneWidget);
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    final cancel = find.text('Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await assertClean(tester, 'Coin review cancelled');
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'full-width top navigation stays fixed without a home or bottom bar',
      (tester) async {
    await mount(tester, const Size(390, 780));
    await assertClean(tester, 'Mobile navigation');
    final navigation = find.byKey(const ValueKey('store-top-navigation'));
    final navigationBounds = tester.getRect(navigation);
    expect(navigationBounds.left, 0);
    expect(navigationBounds.right, 390);
    expect(navigationBounds.top, 0);
    expect(find.byType(GameStoreTopBarArtwork), findsOneWidget);
    expect(find.byType(GameStoreNavigationBack), findsOneWidget);
    final navigationTabs = [
      'Featured',
      'Resources',
      'Gems',
      'Membership',
      'Categories & characters',
    ];
    final tabBounds = {
      for (final tab in navigationTabs)
        tab: tester.getRect(find.byTooltip(tab)),
    };
    final iconCenters = {
      for (final tab in navigationTabs)
        tab: tester.getCenter(find.descendant(
            of: find.byTooltip(tab), matching: find.byType(GameStoreNavIcon))),
    };
    for (final tab in navigationTabs) {
      await select(tester, tab);
      expect(
          find.descendant(
              of: find.byTooltip(tab),
              matching: find.byType(GameStoreNavigationSelection)),
          findsOneWidget);
      expect(find.byType(GameStoreNavigationSelection), findsOneWidget);
      for (final item in navigationTabs) {
        expect(tester.getRect(find.byTooltip(item)), tabBounds[item]);
        expect(
            tester.getCenter(find.descendant(
                of: find.byTooltip(item),
                matching: find.byType(GameStoreNavIcon))),
            iconCenters[item]);
      }
    }
    await select(tester, 'Featured');
    expect(find.byTooltip('Home'), findsNothing);
    expect(find.text('12,500'), findsNothing);
    expect(find.text('450'), findsNothing);
    final back = find.byKey(const ValueKey('store-back-button'));
    final backPosition = tester.getCenter(back);
    expect(navigationBounds.contains(backPosition), isTrue);
    expect(
        tester
            .widgetList<GameStoreNavIcon>(find.byType(GameStoreNavIcon))
            .map((icon) => icon.index),
        [0, 2, 1, 3, 4]);
    expect(tester.getRect(find.byType(ListView)).bottom, 780);
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await assertClean(tester, 'Scrolled shop');
    expect(tester.getRect(navigation), navigationBounds);
    expect(tester.getCenter(back), backPosition);
    await select(tester, 'Coins');
    expect(find.text('Coins for your collection'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('top navigation background spans landscape safe-area insets',
      (tester) async {
    await mount(tester, const Size(800, 360));
    tester.view.padding = const FakeViewPadding(left: 36, right: 16, top: 12);
    addTearDown(tester.view.resetPadding);
    await assertClean(tester, 'Landscape safe area');
    final navigation =
        tester.getRect(find.byKey(const ValueKey('store-top-navigation')));
    expect(navigation.left, 0);
    expect(navigation.right, 800);
    expect(navigation.top, 0);
    final firstTab = tester.getRect(find.byTooltip('Featured'));
    expect(firstTab.left, greaterThanOrEqualTo(36));
    expect(firstTab.top, greaterThanOrEqualTo(12));
    expect(tester.getRect(find.byType(ListView)).bottom, 360);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('top bar back button returns to the previous route',
      (tester) async {
    await mount(tester, const Size(800, 360));
    await assertClean(tester, 'Store entry route');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push<void>(MaterialPageRoute(
        builder: (_) =>
            const StoreScreen(initialKind: StoreProductKind.gems))));
    await assertClean(tester, 'Pushed gems store');
    expect(find.text('More gems. More possibilities.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await assertClean(tester, 'Returned from store');
    expect(find.text('SPECIAL OFFERS'), findsOneWidget);
    expect(find.text('More gems. More possibilities.'), findsNothing);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loading real prices shows progress and cannot open checkout',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    loadCatalog = () => pending.future;
    await mount(tester, const Size(640, 320));
    await tester.pump(const Duration(milliseconds: 100));
    expect(purchases.isLoading, isTrue);
    expect(find.text('Loading prices from Google Play…'), findsOneWidget);
    expect(find.text('Loading price…'), findsWidgets);
    expect(tester.takeException(), isNull);
    final buttons = find.ancestor(
        of: find.text('Loading price…'), matching: find.byType(FilledButton));
    expect(buttons, findsWidgets);
    for (final button in tester.widgetList<FilledButton>(buttons)) {
      expect(button.onPressed, isNull);
    }
    expect(await purchases.buyProduct('pack_starter'), isFalse);
    pending.complete(availableCatalog());
    await assertClean(tester, 'Prices resolved');
    expect(find.text('Loading price…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'unavailable prices remain disabled without invented retail prices',
      (tester) async {
    loadCatalog = () async => {'available': false, 'products': <dynamic>[]};
    await mount(tester, const Size(800, 360));
    await assertClean(tester, 'Unavailable store');
    expect(find.text('Currently unavailable'), findsWidgets);
    final disabledButtons = find.ancestor(
        of: find.text('Currently unavailable'),
        matching: find.byType(FilledButton));
    expect(disabledButtons, findsWidgets);
    for (final button in tester.widgetList<FilledButton>(disabledButtons)) {
      expect(button.onPressed, isNull);
    }
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining(r'$0.99'), findsNothing);
    expect(find.textContaining('₺39,99'), findsNothing);
    expect(await purchases.buyProduct('pack_starter'), isFalse);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checkout waits until the signed-in account wallet is hydrated',
      (tester) async {
    app.commerceReady = false;
    await mount(tester, const Size(800, 360));
    await assertClean(tester, 'Account hydration pending');
    final waiting = find.text('Checking your account…');
    expect(waiting, findsWidgets);
    final disabled =
        find.ancestor(of: waiting, matching: find.byType(FilledButton));
    expect(disabled, findsWidgets);
    for (final button in tester.widgetList<FilledButton>(disabled)) {
      expect(button.onPressed, isNull);
    }
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    app.commerceReady = true;
    app.notifyListeners();
    await assertClean(tester, 'Account ready');
    expect(find.text('Checking your account…'), findsNothing);
    expect(find.text('₺39,99'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'subscription review explains price, renewal, access and cancellation before billing',
      (tester) async {
    await mount(tester, const Size(800, 360),
        initialKind: StoreProductKind.subscription);
    await assertClean(tester, 'Membership layout');
    expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('store-membership-art')))
            .image,
        isA<AssetImage>().having((image) => image.assetName, 'asset',
            'assets/store/membership.webp'));
    expect(find.byType(GameStoreMembershipPrice), findsOneWidget);
    final price = find.text('₺149,99 / month');
    await Scrollable.ensureVisible(tester.element(price), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(price);
    await assertClean(tester, 'Subscription review sheet');
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(
        find.text('No forced ads; reward ads remain optional'), findsOneWidget);
    expect(find.textContaining('automatically renewing subscription'),
        findsOneWidget);
    expect(find.textContaining('paid period ends after cancellation'),
        findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty,
        reason: 'Showing the review sheet must not charge or launch billing.');
    final cancel = find.text('Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await assertClean(tester, 'Review cancelled');
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'active membership artwork button manages the existing subscription',
      (tester) async {
    app.membershipActive = true;
    await mount(tester, const Size(800, 360),
        initialKind: StoreProductKind.subscription);
    await assertClean(tester, 'Active membership artwork');
    expect(find.text('Your membership is active'), findsOneWidget);
    final manage = find.text('Manage membership');
    await Scrollable.ensureVisible(tester.element(manage), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await assertClean(tester, 'Membership management');
    expect(calls.where((call) => call.method == 'manageSubscriptions'),
        hasLength(1));
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    expect(find.text('Continue to payment'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retry checks failed purchase verification, not only prices',
      (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getBillingProducts') return loadCatalog();
      if (call.method == 'restorePurchases') {
        return {
          'success': false,
          'message':
              'commerce/backend-not-configured: The purchase service has not been deployed.'
        };
      }
      return null;
    });
    await mount(tester, const Size(1100, 600));
    await assertClean(tester, 'Catalog ready');
    expect(await purchases.restorePurchases(), false);
    await assertClean(tester, 'Backend failure');
    expect(find.textContaining('خدمة الشراء غير مفعّلة'), findsOneWidget);
    final previousRestores =
        calls.where((call) => call.method == 'restorePurchases').length;
    await tester.tap(find.text('إعادة المحاولة'));
    await assertClean(tester, 'Retry verification');
    expect(calls.where((call) => call.method == 'restorePurchases').length,
        previousRestores + 1);
    expect(find.textContaining('خدمة الشراء غير مفعّلة'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> openMembershipPreview(WidgetTester tester) async {
    unawaited(showDialog<void>(
        context: tester.element(find.byType(StoreScreen).last),
        builder: (_) => const SpecialOfferDialog()));
    await tester.pump();
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/store/champions_club_preview.webp'),
        tester.element(find.byType(SpecialOfferDialog))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  testWidgets('membership preview artwork fits and closes on both orientations',
      (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    for (final viewport in [
      const Size(800, 360),
      const Size(390, 780),
      const Size(640, 320),
    ]) {
      await mount(tester, viewport, textScale: viewport.width == 640 ? 1.5 : 1);
      await assertClean(tester, 'Preview host');
      await openMembershipPreview(tester);
      expect(
          find.text(
              '${purchases.getProductDetails('vip_monthly')!.price} / شهر'),
          findsOneWidget);
      final preview = find.byKey(const ValueKey('champions-club-preview'));
      final bounds = tester.getRect(preview);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(viewport.width));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(viewport.height));
      final close = find.byTooltip('إغلاق');
      expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
      if (viewport.width != 640) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(preview);
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          final name = viewport.width == 800 ? 'landscape' : 'mobile';
          await File('build/champions-club-$name-ar.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.tap(close);
      await assertClean(tester, 'Preview closed');
      expect(find.byType(SpecialOfferDialog), findsNothing);
      expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('membership preview opens subscription without starting billing',
      (tester) async {
    await mount(tester, const Size(800, 360));
    await assertClean(tester, 'Membership preview host');
    await openMembershipPreview(tester);
    await tester.tap(find.byTooltip('استكشاف العضوية'));
    await assertClean(tester, 'Preview opens membership');
    expect(find.byType(SpecialOfferDialog), findsNothing);
    expect(find.byType(GameStoreMembershipCard), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);

    app.membershipActive = true;
    app.notifyListeners();
    await openMembershipPreview(tester);
    expect(find.text('عضويتك فعّالة'), findsOneWidget);
    expect(find.byTooltip('إدارة العضوية'), findsOneWidget);
    await tester.tap(find.byTooltip('إدارة العضوية'));
    await assertClean(tester, 'Active preview opens membership');
    expect(find.text('Manage membership'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('membership preview never displays the printed placeholder price',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    loadCatalog = () => pending.future;
    await mount(tester, const Size(800, 360));
    await tester.pump(const Duration(milliseconds: 100));
    await openMembershipPreview(tester);
    expect(find.text('جارٍ تحميل السعر…'), findsOneWidget);
    pending.complete({'available': false, 'products': []});
    await assertClean(tester, 'Preview with unavailable billing');
    expect(find.text('السعر غير متاح حالياً'), findsOneWidget);
    expect(find.byTooltip('استكشاف العضوية'), findsOneWidget);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('export rendered store preview', (tester) async {
    final boundaryKey = GlobalKey();
    await mount(tester, const Size(1100, 600), repaintKey: boundaryKey);
    await assertClean(tester, 'Preview layout');
    Future<void> capture(String path) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        final context = boundaryKey.currentContext!;
        final images = tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image)
            .toSet();
        await tester.runAsync(() =>
            Future.wait(images.map((image) => precacheImage(image, context))));
        await tester.pump();
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        boundary.markNeedsPaint();
        await tester.pump();
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 1);
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes, isNotNull);
          final output = File(path);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          rendered.dispose();
        });
      } finally {
        debugDisableShadows = previousShadows;
      }
    }

    await capture('build/store-preview.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-character-showcase'))),
        alignment: .2);
    await assertClean(tester, 'English character artwork');
    expect(find.text('12,000 coins'), findsOneWidget);
    expect(find.text('800 gems'), findsOneWidget);
    await capture('build/store-expression-en.png');
    await select(tester, 'Membership');
    await capture('build/store-membership-preview.png');
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    await mount(tester, const Size(1100, 600), repaintKey: boundaryKey);
    await assertClean(tester, 'Arabic preview layout');
    await capture('build/store-preview-ar.png');
    await tester.tap(find.byTooltip('العرض التالي').first);
    await assertClean(tester, 'Explorer artwork preview');
    await capture('build/store-offer-explorer-ar.png');
    await tester.tap(find.byTooltip('العرض التالي').first);
    await assertClean(tester, 'Champion artwork preview');
    await capture('build/store-offer-champion-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-reward-daily'))),
        alignment: .2);
    await assertClean(tester, 'Reward artwork desktop preview');
    await capture('build/store-rewards-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-character-showcase'))),
        alignment: .2);
    await assertClean(tester, 'Arabic character artwork desktop preview');
    await capture('build/store-expression-ar.png');
    await select(tester, 'العضوية');
    await capture('build/store-membership-ar.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, const Size(800, 360), repaintKey: boundaryKey);
    await assertClean(tester, 'Arabic landscape preview');
    await capture('build/store-landscape-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-reward-daily'))),
        alignment: .2);
    await assertClean(tester, 'Reward artwork landscape preview');
    await capture('build/store-landscape-rewards-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-character-showcase'))),
        alignment: .65);
    await assertClean(tester, 'Character showcase landscape preview');
    await capture('build/store-landscape-expression-ar.png');
    final fahad = find.byKey(const ValueKey('store-character-fahad'));
    final talia = find.byKey(const ValueKey('store-character-talia'));
    expect(tester.getSize(fahad), tester.getSize(talia));
    expect(find.text('12,000 نقود'), findsOneWidget);
    expect(find.text('800 جواهر'), findsOneWidget);
    for (final card in [fahad, talia]) {
      final action =
          find.descendant(of: card, matching: find.byType(FilledButton));
      expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    }
    app.purchasedCharacters.add(2);
    app.notifyListeners();
    await assertClean(tester, 'Owned character updates its original button');
    expect(find.descendant(of: fahad, matching: find.text('تم الامتلاك')),
        findsOneWidget);
    expect(find.text('12,000 نقود'), findsNothing);
    await capture('build/store-expression-owned-ar.png');
    app.purchasedCharacters.clear();
    app.notifyListeners();
    await select(tester, 'النقود');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-product-coins_25000'))),
        alignment: .1);
    await assertClean(tester, 'Landscape coin artwork');
    await capture('build/store-landscape-coins-ar.png');
    await select(tester, 'الجواهر');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-product-gems_500'))),
        alignment: .1);
    await assertClean(tester, 'Landscape gem artwork');
    await capture('build/store-landscape-gems-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-return-daily'))),
        alignment: 1);
    await assertClean(tester, 'Return reward landscape preview');
    await capture('build/store-landscape-return-ar.png');
    await select(tester, 'العضوية');
    await Scrollable.ensureVisible(
        tester.element(find.byType(GameStoreMembershipCard)),
        alignment: .1);
    await assertClean(tester, 'Membership artwork landscape preview');
    await capture('build/store-landscape-membership-ar.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, const Size(390, 780), repaintKey: boundaryKey);
    await assertClean(tester, 'Arabic mobile preview');
    await capture('build/store-mobile-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-reward-daily'))),
        alignment: .2);
    await assertClean(tester, 'Reward artwork mobile preview');
    await capture('build/store-mobile-rewards-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-character-showcase'))),
        alignment: .1);
    await assertClean(tester, 'Character artwork mobile preview');
    expect(tester.getSize(fahad), tester.getSize(talia));
    expect(tester.getRect(fahad).bottom, lessThan(tester.getRect(talia).top));
    await capture('build/store-mobile-expression-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-product-coins_25000'))),
        alignment: .1);
    await assertClean(tester, 'Arabic mobile currency cards');
    await capture('build/store-mobile-coins-ar.png');
    await select(tester, 'الجواهر');
    await capture('build/store-mobile-gems-ar.png');
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('store-return-daily'))),
        alignment: .2);
    await assertClean(tester, 'Return reward mobile preview');
    await capture('build/store-mobile-return-ar.png');
    await select(tester, 'العضوية');
    await capture('build/store-mobile-membership-ar.png');
    await select(tester, 'أرصدة اللعب');
    await capture('build/store-mobile-resources-ar.png');
    for (final tab in [
      ('المميزة', 'featured'),
      ('أرصدة اللعب', 'resources'),
      ('الجواهر', 'gems'),
      ('العضوية', 'membership'),
      ('الفئات والشخصيات', 'collection'),
    ]) {
      await select(tester, tab.$1);
      await capture('build/store-navigation-${tab.$2}-ar.png');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    settings = _StoreSettings();
    await mount(tester, const Size(390, 780), repaintKey: boundaryKey);
    await assertClean(tester, 'English mobile preview');
    await capture('build/store-mobile.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Arabic portrait tabs remain usable at 360x640', (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    await mount(tester, const Size(360, 640));
    await assertClean(tester, 'Arabic featured portrait');
    assertCenteredTitles(tester);
    for (final tab in <String>[
      'الجواهر',
      'النقود',
      'العضوية',
      'الفئات والشخصيات',
      'المميزة'
    ]) {
      await select(tester, tab);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('VIP players can still redeem earned permanent category vouchers',
      (tester) async {
    app.membershipActive = true;
    app.economyWallet = const EconomyWallet(categoryVouchers: 1);
    await mount(tester, const Size(360, 640));
    await assertClean(tester, 'VIP store');
    await select(tester, 'Categories & characters');
    final search = find.byType(TextField).first;
    await tester.ensureVisible(search);
    await tester.enterText(search, 'سبيس تون');
    await tester.pumpAndSettle();
    final voucher = find.text('استخدام قسيمة امتلاك');
    await tester.ensureVisible(voucher);
    await tester.tap(voucher);
    await tester.pumpAndSettle();
    expect(find.text('امتلاك دائم باستخدام قسيمة واحدة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await assertClean(tester, 'Cancel voucher');
    expect(app.economyWallet.categoryVouchers, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'rental confirmation includes category, duration, and exact price',
      (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    app.economyWallet = const EconomyWallet(rentalPrices: {
      'day': {'days': 1, 'coins': 2000, 'gems': 20},
      'week': {'days': 7, 'coins': 7000, 'gems': 70},
      'month': {'days': 30, 'coins': 15000, 'gems': 140},
    });
    await mount(tester, const Size(390, 780));
    await select(tester, 'الفئات والشخصيات');
    final search = find.byType(TextField).first;
    await tester.ensureVisible(search);
    await tester.enterText(search, 'سبيس تون');
    await tester.pumpAndSettle();
    final rent = find.text('استئجار يوم / أسبوع / شهر');
    await tester.ensureVisible(rent);
    await tester.tap(rent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('أسبوع (7 أيام) • 7000 قطعة'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'استئجار تصنيف «سبيس تون» لمدة أسبوع (7 أيام) مقابل 7000 قطعة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.'),
        findsOneWidget);
    expect(app.economyActions, isEmpty);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(app.economyActions.single, {
      'action': 'rent',
      'duration': 'week',
      'currency': 'coins',
      'category': 'سبيس تون',
    });
    expect(find.text('تم استئجار تصنيف «سبيس تون» لمدة أسبوع (7 أيام).'),
        findsOneWidget);
    await assertClean(tester, 'Confirmed rental');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'weekly voucher clearly extends an existing rental and can cancel',
      (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    app.rentalHours = 48;
    app.economyWallet = const EconomyWallet(rentalVouchers: 1, rentalPrices: {
      'week': {'days': 7, 'coins': 7000, 'gems': 70},
    });
    await mount(tester, const Size(390, 780));
    await select(tester, 'الفئات والشخصيات');
    final search = find.byType(TextField).first;
    await tester.ensureVisible(search);
    await tester.enterText(search, 'سبيس تون');
    await tester.pumpAndSettle();
    expect(find.text('الاستئجار: 48 ساعة متبقية'), findsOneWidget);
    final rent = find.text('استئجار يوم / أسبوع / شهر');
    await tester.ensureVisible(rent);
    await tester.tap(rent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('قسيمة استئجار • أسبوع (7 أيام)'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'استئجار تصنيف «سبيس تون» لمدة أسبوع (7 أيام) مقابل قسيمة أسبوعية واحدة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.'),
        findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(app.economyActions, isEmpty);
    expect(app.economyWallet.rentalVouchers, 1);
    await assertClean(tester, 'Cancelled rental voucher');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unavailable rental service reports the problem before checkout',
      (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    app.economyReady = false;
    app.economyFailure = 'خدمة الأرصدة غير متاحة حالياً.';
    await mount(tester, const Size(390, 780));
    await select(tester, 'الفئات والشخصيات');
    final search = find.byType(TextField).first;
    await tester.ensureVisible(search);
    await tester.enterText(search, 'سبيس تون');
    await tester.pumpAndSettle();
    final rent = find.text('استئجار يوم / أسبوع / شهر');
    await tester.ensureVisible(rent);
    await tester.tap(rent);
    await tester.pumpAndSettle();
    expect(find.text('خدمة الأرصدة غير متاحة حالياً.'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(app.economyActions, isEmpty);
    await assertClean(tester, 'Unavailable rental service');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large English text stays scrollable in compact landscape',
      (tester) async {
    await mount(tester, const Size(640, 320), textScale: 1.5);
    await assertClean(tester, 'Large text featured');
    for (final tab in <String>[
      'Gems',
      'Coins',
      'Membership',
      'Categories & characters'
    ]) {
      await select(tester, tab);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'all exchange offers including tickets_1 and hearts_1 display rich artwork',
      (tester) async {
    await mount(tester, const Size(800, 600));
    await select(tester, 'Resources');
    final images = tester.widgetList<Image>(find.byType(Image)).where((img) {
      final asset = img.image;
      return asset is AssetImage && asset.assetName.contains('exchange_');
    }).toList();
    final names =
        images.map((img) => (img.image as AssetImage).assetName).toSet();
    expect(
        names,
        containsAll([
          'assets/store/exchange_keys_1.webp',
          'assets/store/exchange_keys_3.webp',
          'assets/store/exchange_hearts_1.webp',
          'assets/store/exchange_hearts_3.webp',
          'assets/store/exchange_tickets_1.webp',
          'assets/store/exchange_tickets_3.webp',
          'assets/store/exchange_bundle_3.webp',
          'assets/store/exchange_bundle_10.webp',
        ]));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'all 8 resource packages appear and ad products grant free rewards via ads',
      (tester) async {
    await mount(tester, const Size(800, 800));

    // Verify all 8 resource package products are present in the catalog
    final resourceProductIds = [
      'resources_3_each',
      'resources_10_each',
      'keys_1',
      'hearts_1',
      'tickets_1',
      'keys_10',
      'hearts_10',
      'tickets_10',
    ];
    for (final id in resourceProductIds) {
      final product = StoreCatalog.byId(id);
      expect(product, isNotNull, reason: 'Product $id must exist in catalog');
    }

    // Verify Free Ad buttons are rendered for the 3 ad-based packages
    final freeAdButtons = find.text('Free Ad');
    expect(freeAdButtons, findsNWidgets(3));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(freeAdButtons.first, 150,
        scrollable: scrollable);
    await tester.pumpAndSettle();
    if (tester.getRect(freeAdButtons.first).top < 120) {
      await tester.drag(scrollable, const Offset(0, 150));
      await tester.pumpAndSettle();
    }

    // Tap on the first free ad button (keys_1)
    await tester.tap(freeAdButtons.first);
    await tester.pumpAndSettle();

    // Verify that action ad was requested and economyAction adReward was executed
    expect((ads as _StoreAds).actionAdRequests, 1);
    expect(
        app.economyActions.where((a) => a['action'] == 'adReward'), isNotEmpty);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Champions Club displays welcome bonus package and claim button for VIP',
      (tester) async {
    app.membershipActive = true;
    app.canClaimVip = true;
    await mount(tester, const Size(800, 800),
        initialKind: StoreProductKind.subscription);
    await assertClean(tester, 'VIP membership view');

    // Verify welcome pack title and 5 reward capsules
    expect(
        find.textContaining('Instant Champions Welcome Pack'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('1,000'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(3));

    // Verify claim button is rendered
    final claimButton = find.byKey(const ValueKey('claim-vip-bonus-button'));
    expect(claimButton, findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(claimButton, 150, scrollable: scrollable);
    await tester.pumpAndSettle();

    // Tap claim button
    await tester.tap(claimButton);
    await tester.pumpAndSettle();

    // Verify claimVipBonus action was executed
    expect(app.economyActions.where((a) => a['action'] == 'claimVipBonus'),
        isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unfinished or unavailable resource ads never grant a resource',
      (tester) async {
    (ads as _StoreAds).actionAdResult = false;
    await mount(tester, const Size(800, 800));
    await assertClean(tester, 'Resource ad unavailable');
    final button = find.text('Free Ad').first;
    await tester.scrollUntilVisible(button, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    if (tester.getRect(button).top < 120) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 150));
      await tester.pumpAndSettle();
    }
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect((ads as _StoreAds).actionAdRequests, 1);
    expect(app.economyActions, isEmpty);
    expect(find.textContaining('not watched to completion'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
