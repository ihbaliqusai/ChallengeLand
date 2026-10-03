import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/models/store_catalog.dart';
import 'package:challenge_land/screens/home/store_screen.dart';
import 'package:challenge_land/services/ad_service.dart';
import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// These providers exercise the real store without initializing a Firebase app,
// real authentication, ads, or payment credentials.
class _StoreAppState extends ChangeNotifier implements AppState {
  bool commerceReady = true;
  @override
  bool get isCommerceReady => commerceReady;
  @override
  int get coins => 12500;
  @override
  int get gems => 450;
  @override
  int get level => 7;
  @override
  bool get isVip => false;
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
  bool get claimedToday => false;
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
  bool isCharacterUnlocked(GameCharacter character) =>
      character.unlock.isFree ||
      (character.unlock.isLevelGated && character.unlock.value <= level);
  @override
  bool isCategoryUnlocked(String categoryName) => false;
  @override
  int getCategoryRemainingRentalHours(String categoryName) => 0;
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
      return null;
    });
    bridge = NativeBridgeService();
    purchases = InAppPurchaseService(nativeBridge: bridge);
    app = _StoreAppState();
    settings = _StoreSettings();
    ads = AdService();
  });

  tearDown(() {
    purchases.dispose();
    app.dispose();
    settings.dispose();
    ads.dispose();
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

  Future<void> select(WidgetTester tester, String tab) async {
    final label = find.text(tab).first;
    await tester.ensureVisible(label);
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
      expect(find.text('Challenge Store'), findsOneWidget);
      expect(find.text('Starter bundle'), findsOneWidget);

      for (final entry in const <String, String>{
        'Gems': 'More gems. More possibilities.',
        'Coins': 'Coins for your collection',
        'Membership': 'A richer experience, every month',
        'Categories & characters': 'Build your own collection',
        'Featured': 'Starter bundle',
      }.entries) {
        await select(tester, entry.key);
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
    final price = find.text('₺149,99 / month');
    await tester.ensureVisible(price);
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

  testWidgets('export rendered store preview', (tester) async {
    final boundaryKey = GlobalKey();
    await mount(tester, const Size(1100, 600), repaintKey: boundaryKey);
    await assertClean(tester, 'Preview layout');
    Future<void> capture(String path) async {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final output = File(path);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
        rendered.dispose();
      });
    }

    await capture('build/store-preview.png');
    await select(tester, 'Membership');
    await capture('build/store-membership-preview.png');
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    await mount(tester, const Size(1100, 600), repaintKey: boundaryKey);
    await assertClean(tester, 'Arabic preview layout');
    await capture('build/store-preview-ar.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Arabic portrait tabs remain usable at 360x640', (tester) async {
    settings.dispose();
    settings = _StoreSettings(arabic: true);
    await mount(tester, const Size(360, 640));
    await assertClean(tester, 'Arabic featured portrait');
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
}
