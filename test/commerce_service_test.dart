import 'dart:async';

import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late InAppPurchaseService service;
  late List<MethodCall> calls;
  late Map<String, dynamic> catalog;

  Future<void> nativeEvent(
      String method, Map<String, dynamic> arguments) async {
    final complete = Completer<void>();
    await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) => complete.complete());
    await complete.future;
  }

  setUp(() {
    calls = [];
    catalog = {
      'available': true,
      'products': [
        {
          'id': 'gems80',
          'title': 'Gems',
          'price': '₺39,99',
          'currencyCode': 'TRY',
          'rawPrice': 39.99
        },
        {'id': 'vip_monthly', 'price': '₺149,99', 'billingPeriod': 'P1M'},
      ]
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getBillingProducts':
          return catalog;
        case 'launchBilling':
          return {'success': true};
        case 'restorePurchases':
          return {'success': true};
        default:
          return null;
      }
    });
    service = InAppPurchaseService(nativeBridge: NativeBridgeService());
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('uses localized store prices and launches the actual legacy SKU',
      () async {
    await service.initialize();
    expect(service.getProductDetails('gems_80')?.price, '₺39,99');
    expect(service.getProductDetails('vip_monthly')?.billingPeriod, 'P1M');
    expect(await service.buyProduct('gems_80'), true);
    expect(calls.last.arguments, {'productId': 'gems80'});
    expect(service.status, PurchaseFlowStatus.launching);
  });

  test(
      'opening payment never delivers; pending purchase prevents second charge',
      () async {
    var deliveries = 0;
    service.addDeliveryListener((_) => deliveries++);
    await service.initialize();
    await service.buyProduct('gems_80');
    expect(deliveries, 0);
    await nativeEvent('onPurchaseStatus', {
      'productId': 'gems80',
      'status': 'pending',
      'message': 'Payment pending'
    });
    expect(service.status, PurchaseFlowStatus.pending);
    expect(await service.buyProduct('vip_monthly'), false);
    expect(calls.where((call) => call.method == 'launchBilling').length, 1);
    await nativeEvent(
        'onPurchaseStatus', {'productId': 'gems80', 'status': 'verifying'});
    expect(deliveries, 0);
    await nativeEvent('onPurchaseDelivered', {'productId': 'gems80'});
    expect(deliveries, 1);
    expect(service.status, PurchaseFlowStatus.delivered);
    expect(service.isPurchasing, false);
  });

  test('cancellation permits retry and does not create a delivery', () async {
    await service.initialize();
    await service.buyProduct('gems_80');
    await nativeEvent(
        'onPurchaseStatus', {'productId': 'gems80', 'status': 'cancelled'});
    expect(service.status, PurchaseFlowStatus.canceled);
    expect(await service.buyProduct('gems_80'), true);
  });

  test('background receipt delivery cannot complete another open checkout',
      () async {
    await service.initialize();
    await service.buyProduct('vip_monthly');
    await nativeEvent('onPurchaseStatus',
        {'productId': 'pack_starter', 'status': 'verifying'});
    await nativeEvent('onPurchaseDelivered', {'productId': 'pack_starter'});
    await nativeEvent('onPurchaseStatus',
        {'productId': 'pack_starter', 'status': 'delivered'});
    expect(service.status, PurchaseFlowStatus.launching);
    expect(service.activeProductId, 'vip_monthly');
    expect(service.isPurchasing, true);
    expect(await service.buyProduct('gems_80'), false);
  });

  test(
      'restoring another receipt does not erase an outstanding pending payment',
      () async {
    await service.initialize();
    await service.buyProduct('gems_80');
    await nativeEvent(
        'onPurchaseStatus', {'productId': 'gems80', 'status': 'pending'});
    await nativeEvent('onPurchaseDelivered', {'productId': 'pack_starter'});
    await nativeEvent('onPurchaseStatus',
        {'productId': 'pack_starter', 'status': 'delivered'});
    expect(service.status, PurchaseFlowStatus.pending);
    expect(service.isPurchasing, true);
    expect(await service.buyProduct('gems_80'), false);
  });

  test('restoring a cancelled pending payment releases checkout', () async {
    await service.initialize();
    await service.buyProduct('gems_80');
    await nativeEvent(
        'onPurchaseStatus', {'productId': 'gems80', 'status': 'pending'});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'restorePurchases') {
        return {'success': true, 'pendingCount': 0};
      }
      return {'success': true};
    });
    expect(await service.restorePurchases(), true);
    expect(service.status, PurchaseFlowStatus.idle);
    expect(service.isPurchasing, false);
  });

  test('missing prices disable purchases without fallback USD prices',
      () async {
    catalog = {
      'available': true,
      'products': [
        {'id': 'gems_80', 'price': ''}
      ]
    };
    await service.initialize();
    expect(service.isAvailable, false);
    expect(service.products, isEmpty);
    expect(await service.buyProduct('gems_80'), false);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
  });

  test('canonical published SKU wins over legacy aliases', () async {
    (catalog['products'] as List).add({'id': 'gems_80', 'price': '₺42,99'});
    await service.initialize();
    expect(service.getProductDetails('gems80')?.id, 'gems_80');
    expect(service.getProductDetails('gems80')?.price, '₺42,99');
  });

  test('restore success does not manufacture currency delivery callbacks',
      () async {
    var deliveries = 0;
    service.addDeliveryListener((_) => deliveries++);
    expect(await service.restorePurchases(), true);
    expect(deliveries, 0);
    expect(service.isRestoring, false);
    expect(service.status, PurchaseFlowStatus.idle);
  });

  test('native restore failure is surfaced', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => {'success': false});
    expect(await service.restorePurchases(), false);
    expect(service.status, PurchaseFlowStatus.failed);
    expect(service.error, isNotEmpty);
  });

  test('missing purchase backend is distinct from a connectivity failure',
      () async {
    await service.initialize();
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
              'success': false,
              'message':
                  'commerce/backend-not-configured: The purchase service has not been deployed.'
            });
    expect(await service.buyProduct('gems_80'), false);
    expect(service.error, contains('خدمة الشراء غير مفعّلة'));
    expect(service.error, isNot(contains('اتصالك')));
    expect(service.isPurchasing, false);
    expect(await service.restorePurchases(), false);
    expect(service.error, contains('خدمة الشراء غير مفعّلة'));
  });

  test('price refresh does not erase a failed purchase verification', () async {
    await service.initialize();
    await nativeEvent('onPurchaseStatus', {
      'productId': 'vip_monthly',
      'status': 'error',
      'message':
          'commerce/backend-not-configured: The purchase service has not been deployed.'
    });
    final error = service.error;
    await service.loadProducts();
    expect(service.isAvailable, true);
    expect(service.error, error);
    expect(service.status, PurchaseFlowStatus.failed);
  });

  test(
      'missing product explains availability while existing products still work',
      () async {
    (catalog['products'] as List).add({
      'id': 'coins_5000',
      'available': false,
      'price': '',
      'availabilityMessage': 'No eligible buy purchase option is available.'
    });
    await service.initialize();
    expect(service.isAvailable, true);
    expect(service.getProductDetails('gems_80'), isNotNull);
    expect(service.getProductDetails('coins_5000'), isNull);
    expect(service.getExplanation('coins_5000'), contains('خيار شراء'));
    expect(await service.buyProduct('coins_5000'), false);
    expect(calls.where((call) => call.method == 'launchBilling'), isEmpty);
    expect(await service.buyProduct('gems_80'), true);
  });

  test('restore retains an ownership error and never credits another account',
      () async {
    var deliveries = 0;
    service.addDeliveryListener((_) => deliveries++);
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
              'success': false,
              'message': 'This purchase belongs to another game account.'
            });
    expect(await service.restorePurchases(), false);
    expect(service.error, contains('حساب لعبة آخر'));
    expect(deliveries, 0);
  });
}
