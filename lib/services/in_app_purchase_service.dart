import 'dart:async';
import 'package:flutter/foundation.dart';
import 'native_bridge_service.dart';

/// كائن تفاصيل المنتج المتوافق مع شاشات اللعبة
class AppProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;

  const AppProductDetails({
    required this.id,
    this.title = '',
    this.description = '',
    this.price = '',
  });
}

/// خدمة إدارة المشتريات والاشتراكات الرسمية المباشرة عبر Google Play Billing 8.0.0
class InAppPurchaseService {
  InAppPurchaseService({required this.nativeBridge}) {
    NativeBridgeService.addPurchaseDeliveredListener(_onNativePurchaseDelivered);
  }

  final NativeBridgeService nativeBridge;

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  final Map<String, AppProductDetails> _products = {
    'gems_80': const AppProductDetails(id: 'gems_80', title: 'كيس جواهر صغير', price: r'$0.99'),
    'gems80': const AppProductDetails(id: 'gems80', title: 'كيس جواهر صغير', price: r'$0.99'),
    'gems_500': const AppProductDetails(id: 'gems_500', title: 'صندوق جواهر متوسط', price: r'$4.99'),
    'gems500': const AppProductDetails(id: 'gems500', title: 'صندوق جواهر متوسط', price: r'$4.99'),
    'gems_1200': const AppProductDetails(id: 'gems_1200', title: 'حقيبة جواهر كبيرة', price: r'$9.99'),
    'gems1200': const AppProductDetails(id: 'gems1200', title: 'حقيبة جواهر كبيرة', price: r'$9.99'),
    'pack_starter': const AppProductDetails(id: 'pack_starter', title: 'حزمة المبتدئ الحارقة', price: r'$0.99'),
    'packstarter': const AppProductDetails(id: 'packstarter', title: 'حزمة المبتدئ الحارقة', price: r'$0.99'),
    'pack_value': const AppProductDetails(id: 'pack_value', title: 'باقة القيمة الذهبية', price: r'$2.99'),
    'packvalue': const AppProductDetails(id: 'packvalue', title: 'باقة القيمة الذهبية', price: r'$2.99'),
    'pack_champion': const AppProductDetails(id: 'pack_champion', title: 'باقة الأبطال الملكية', price: r'$9.99'),
    'packchampion': const AppProductDetails(id: 'packchampion', title: 'باقة الأبطال الملكية', price: r'$9.99'),
    'vip_monthly': const AppProductDetails(id: 'vip_monthly', title: 'العضوية الملكية VIP', price: r'$4.99'),
    'vipmonthly': const AppProductDetails(id: 'vipmonthly', title: 'العضوية الملكية VIP', price: r'$4.99'),
    'vippass': const AppProductDetails(id: 'vippass', title: 'العضوية الملكية VIP', price: r'$4.99'),
  };

  Map<String, AppProductDetails> get products => _products;

  final List<void Function(String productId)> _deliveryListeners = [];

  void addDeliveryListener(void Function(String productId) listener) {
    if (!_deliveryListeners.contains(listener)) {
      _deliveryListeners.add(listener);
    }
  }

  void removeDeliveryListener(void Function(String productId) listener) {
    _deliveryListeners.remove(listener);
  }

  VoidCallback? onPurchaseCompleted;

  String _lastError = '';

  bool get hasProducts => _products.isNotEmpty;

  AppProductDetails? getProductDetails(String productId) {
    if (_products.containsKey(productId)) return _products[productId];
    final clean = productId.replaceAll('_', '').toLowerCase();
    for (final entry in _products.entries) {
      if (entry.key.replaceAll('_', '').toLowerCase() == clean) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    try {
      await nativeBridge.initBilling();
      _isAvailable = await nativeBridge.isBillingAvailable();
    } catch (e) {
      debugPrint('[Billing 8.0.0] Init error: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      await nativeBridge.initBilling();
      _isAvailable = await nativeBridge.isBillingAvailable();
    } catch (e) {
      debugPrint('[Billing 8.0.0] Load products error: $e');
    }
  }

  String getExplanation(String productId) {
    if (_lastError.isNotEmpty) {
      return _lastError;
    }
    return 'تعذر إتمام عملية الشراء عبر متجر Google Play، يرجى التحقق من اتصال الإنترنت.';
  }

  /// تنفيذ عملية الشراء عبر نافذة الدفع الرسمية لـ Google Play Billing 8.0.0
  Future<bool> buyProduct(String productId) async {
    try {
      _lastError = '';
      debugPrint('[Billing 8.0.0] Launching billing flow for: $productId');

      final result = await nativeBridge.launchBilling(productId);
      final success = result['success'] == true;
      if (!success) {
        _lastError = (result['message'] ?? 'فشلت عملية فتح نافذة الدفع').toString();
        debugPrint('[Billing 8.0.0] Billing flow error: $_lastError');
      }
      return success;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[Billing 8.0.0] buyProduct exception: $e');
      return false;
    }
  }

  void _onNativePurchaseDelivered(String productId) {
    debugPrint('[Billing 8.0.0] Native purchase delivered event received for: $productId');
    onPurchaseCompleted?.call();
    for (final listener in List.of(_deliveryListeners)) {
      try {
        listener(productId);
      } catch (e) {
        debugPrint('[Billing 8.0.0] Listener error: $e');
      }
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final restored = await nativeBridge.restorePurchases();
      return restored;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    NativeBridgeService.removePurchaseDeliveredListener(_onNativePurchaseDelivered);
    _deliveryListeners.clear();
  }
}
