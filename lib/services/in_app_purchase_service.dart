import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'native_bridge_service.dart';

/// خدمة إدارة المشتريات والاشتراكات الرسمية عبر Google Play و App Store
class InAppPurchaseService {
  InAppPurchaseService({required this.nativeBridge});

  final NativeBridgeService nativeBridge;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

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

  static const Set<String> _consumableProductIds = {
    'pack_starter',
    'pack_value',
    'pack_champion',
    'gems_80',
    'gems_500',
    'gems_1200',
  };

  static const Set<String> _nonConsumableProductIds = {
    'vip_monthly',
    'vip_pass',
  };

  static Set<String> get allProductIds => {
        ..._consumableProductIds,
        ..._nonConsumableProductIds,
      };

  bool get hasProducts => _products.isNotEmpty;

  /// تهيئة الخدمة والتحقق من توفر متجر Google Play
  Future<void> initialize() async {
    try {
      _isAvailable = await _iap
          .isAvailable()
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (!_isAvailable) {
        debugPrint('[IAP] In-App Purchase store is not available.');
        return;
      }

      // الاستماع لأحداث الشراء القادمة من جوجل بلاي
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('[IAP] Purchase stream error: $error');
        },
      );

      // جلب تفاصيل المنتجات المعتمدة
      await loadProducts();
    } catch (e) {
      debugPrint('[IAP] Initialization failed: $e');
    }
  }

  /// تحميل المنتجات من Google Play Console بمهلة زمنية
  Future<void> loadProducts() async {
    if (!_isAvailable) return;
    try {
      final response = await _iap
          .queryProductDetails(allProductIds)
          .timeout(const Duration(seconds: 5));
      if (response.error != null) {
        debugPrint('[IAP] Query error: ${response.error!.message}');
        return;
      }
      _products = {for (final p in response.productDetails) p.id: p};
      debugPrint('[IAP] Loaded ${_products.length} products from store.');
    } catch (e) {
      debugPrint('[IAP] Failed to query product details: $e');
    }
  }

  /// توضيح سبب عدم توفر المنتج للمستخدم
  String getExplanation(String productId) {
    if (!_isAvailable) {
      return 'خدمة متجر Google Play غير متوفرة على هذا الجهاز حالياً.';
    }
    if (_products.isEmpty || !_products.containsKey(productId)) {
      return 'منتجات الدفع قيد الاعتماد من متجر Google Play... يرجى الانتظار حتى اكتمال مراجعة النسخة في Google Play Console.';
    }
    return 'تعذر إتمام عملية الشراء، يرجى المحاولة لاحقاً.';
  }

  /// تفعيل أو تعطيل المحاكاة المجانية عند غياب متجر Google Play
  /// مغلقة افتراضياً (false) لضمان أن كل المشتريات تمر عبر نافذة دفع Google Play الرسمية
  static const bool allowMockFallback = false;

  /// تنفيذ عملية الشراء مع مهلة زمنية مانعة للتعليق
  Future<bool> buyProduct(String productId) async {
    try {
      // محاولة إعادة التحقق من المتجر في حال لم يكن جاهزاً
      if (!_isAvailable) {
        _isAvailable = await _iap
            .isAvailable()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      }

      if (!_isAvailable) {
        debugPrint('[IAP] Store not available.');
        if (allowMockFallback) {
          final ok = await nativeBridge.deliverPurchase(
            productId,
            deliveryKey: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
          );
          if (ok) {
            onPurchaseCompleted?.call();
            _notifyDelivery(productId);
          }
          return ok;
        }
        return false;
      }

      // إذا لم تكن المنتجات محملة، نحاول إعادة جلبها بمهلة محددة
      if (!_products.containsKey(productId)) {
        await loadProducts().timeout(const Duration(seconds: 3), onTimeout: () {});
      }

      final productDetails = _products[productId];
      if (productDetails == null) {
        debugPrint('[IAP] Product details not found for $productId in store catalog.');
        if (allowMockFallback) {
          final ok = await nativeBridge.deliverPurchase(
            productId,
            deliveryKey: 'mock_${DateTime.now().millisecondsSinceEpoch}',
          );
          if (ok) {
            onPurchaseCompleted?.call();
            _notifyDelivery(productId);
          }
          return ok;
        }
        return false;
      }

      final purchaseParam = PurchaseParam(productDetails: productDetails);
      if (_consumableProductIds.contains(productId)) {
        return await _iap
            .buyConsumable(purchaseParam: purchaseParam)
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
      } else {
        return await _iap
            .buyNonConsumable(purchaseParam: purchaseParam)
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
      }
    } catch (e) {
      debugPrint('[IAP] buyProduct error: $e');
      return false;
    }
  }

  void _notifyDelivery(String productId) {
    for (final listener in List.of(_deliveryListeners)) {
      try {
        listener(productId);
      } catch (e) {
        debugPrint('[IAP] Listener callback error: $e');
      }
    }
  }

  /// معالجة أحداث الفواتير الواردة من Google Play
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[IAP] Purchase pending for ${purchase.productID}...');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final delivered = await nativeBridge.deliverPurchase(
            purchase.productID,
            deliveryKey: purchase.purchaseID,
          );
          if (delivered) {
            debugPrint('[IAP] Purchase successfully delivered for ${purchase.productID}!');
            onPurchaseCompleted?.call();
            _notifyDelivery(purchase.productID);
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[IAP] Purchase error: ${purchase.error?.message}');
          break;
        case PurchaseStatus.canceled:
          debugPrint('[IAP] Purchase canceled by user.');
          break;
      }
    }
  }

  /// استرجاع المشتريات السابقة (للاشتراكات والمنتجات الدائمة)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] Restore purchases failed: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _deliveryListeners.clear();
  }
}
