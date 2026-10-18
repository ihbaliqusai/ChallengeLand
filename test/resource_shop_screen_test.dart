import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/screens/home/resource_shop_screen.dart';
import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallet extends ChangeNotifier implements AppState {
  @override
  EconomyWallet economyWallet = EconomyWallet.fromMap({
    'dailyKeys': 3,
    'keys': 7,
    'dailyHearts': 3,
    'hearts': 4,
    'tickets': 2,
    'offers': {
      'tickets_3': {
        'resource': 'tickets',
        'amount': 3,
        'coins': 2400,
        'gems': 24
      }
    },
  });
  final actions = <Map<String, dynamic>>[];
  bool fail = false;
  bool ready = true;
  String? unavailableMessage;
  int loadRequests = 0;
  @override
  int get coins => 10000;
  @override
  int get gems => 100;
  @override
  Future<void> loadCurrency() async {}
  @override
  bool get economyLoaded => ready;
  @override
  String? get economyError => unavailableMessage;
  @override
  Future<void> loadEconomy() async {
    loadRequests++;
  }

  @override
  Future<void> economyAction(Map<String, dynamic> data) async {
    actions.add(data);
    if (fail) throw StateError('الرصيد غير كافٍ');
    economyWallet = const EconomyWallet(
        dailyKeys: 3, keys: 7, dailyHearts: 3, hearts: 4, tickets: 5);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Billing extends InAppPurchaseService {
  _Billing() : super(nativeBridge: NativeBridgeService());
  int loadRequests = 0;
  @override
  Future<void> loadProducts() async {
    loadRequests++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('economy failures expose the player message without platform details',
      () async {
    const channel = MethodChannel('millionaire/native');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
            code: 'ECONOMY_FAILED', message: 'الرصيد غير كافٍ'));
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
        NativeBridgeService().economy({'action': 'state'}),
        throwsA(isA<EconomyOperationException>()
            .having((e) => e.toString(), 'message', 'الرصيد غير كافٍ')));
  });
  Future<void> mount(
      WidgetTester tester, _Wallet wallet, _Billing billing, Size size,
      {double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: wallet),
          ChangeNotifierProvider<InAppPurchaseService>.value(value: billing),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const ResourceShopScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'missing wallet service shows unknown balances and separate Play price retry',
      (tester) async {
    final wallet = _Wallet()
      ..ready = false
      ..economyWallet = const EconomyWallet()
      ..unavailableMessage = 'خدمة الأرصدة غير متاحة حالياً. حاول لاحقاً.';
    final billing = _Billing();
    await mount(tester, wallet, billing, const Size(360, 640), scale: 1.4);
    expect(find.text('… مفاتيح'), findsOneWidget);
    expect(find.text('… تذاكر'), findsOneWidget);
    expect(find.text('… قلوب'), findsOneWidget);
    expect(find.textContaining('المفاتيح اليومية: 0'), findsNothing);
    expect(find.textContaining('لم يتم تحميل رصيد الحساب بعد'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تحميل الأرصدة'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('تحميل الأرصدة'));
    await tester.pumpAndSettle();
    expect(wallet.loadRequests, 2);
    final retry = find.text('إعادة تحميل أسعار Google Play');
    await tester.scrollUntilVisible(retry, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('لم تصل أسعار منتجات الأرصدة من Google Play'),
        findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(billing.loadRequests, 2);
    expect(wallet.actions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    wallet.dispose();
    billing.dispose();
  });

  testWidgets(
      'resource exchange requires confirmation and refreshes displayed balance after delivery',
      (tester) async {
    final wallet = _Wallet();
    final billing = _Billing();
    await mount(tester, wallet, billing, const Size(360, 640));
    expect(
        find.descendant(
            of: find.byType(ResourceBalance), matching: find.text('10 مفاتيح')),
        findsOneWidget);
    expect(find.text('7 قلوب'), findsOneWidget);
    await tester.ensureVisible(find.text('2400 قطعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2400 قطعة'));
    await tester.pumpAndSettle();
    expect(wallet.actions, isEmpty);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(wallet.actions.single,
        {'action': 'buy', 'offerId': 'tickets_3', 'currency': 'coins'});
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('5 تذاكر'), findsOneWidget);
    expect(find.text('تمت إضافة الرصيد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    wallet.dispose();
    billing.dispose();
  });
  testWidgets(
      'mixed bundle shows every resource and cancellation cannot spend the wallet',
      (tester) async {
    final wallet = _Wallet();
    wallet.economyWallet = EconomyWallet.fromMap({
      'dailyKeys': 3,
      'dailyHearts': 3,
      'tickets': 3,
      'offers': {
        'play_bundle': {
          'grants': {'keys': 3, 'hearts': 3, 'tickets': 3},
          'coins': 5100,
          'gems': 51
        }
      },
      'weekDays': [1, 2],
      'weekCorrect': 14,
      'rewardLog': [
        {
          'kind': 'welcome',
          'id': 'welcome',
          'grants': {'keys': 3, 'hearts': 3, 'tickets': 3}
        }
      ],
    });
    final billing = _Billing();
    await mount(tester, wallet, billing, const Size(360, 640), scale: 1.4);
    await tester.scrollUntilVisible(find.text('5100 قطعة'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('3 مفاتيح + 3 قلوب + 3 تذاكر تصنيفات'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5100 قطعة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5100 قطعة'), findsNWidgets(2));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(wallet.actions, isEmpty);
    expect(wallet.economyWallet.tickets, 3);
    await tester.scrollUntilVisible(
        find.textContaining('هدية البداية • مرة واحدة'), 400,
        maxScrolls: 60, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('هدية البداية • مرة واحدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    wallet.dispose();
    billing.dispose();
  });

  testWidgets(
      'failed exchange keeps balance and large text can scroll on a small screen',
      (tester) async {
    final wallet = _Wallet()..fail = true;
    final billing = _Billing();
    await mount(tester, wallet, billing, const Size(360, 640), scale: 1.4);
    final button = find.text('2400 قطعة');
    await tester.scrollUntilVisible(button, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(wallet.economyWallet.tickets, 2);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('الرصيد غير كافٍ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    wallet.dispose();
    billing.dispose();
  });
}
