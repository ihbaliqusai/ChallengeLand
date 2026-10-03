import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/store_catalog.dart';
import 'native_bridge_service.dart';

enum PurchaseFlowStatus {
  idle,
  launching,
  pending,
  verifying,
  delivered,
  canceled,
  failed
}

class AppProductDetails {
  const AppProductDetails(
      {required this.id,
      this.title = '',
      this.description = '',
      this.price = '',
      this.currencyCode = '',
      this.rawPrice = 0,
      this.billingPeriod = '',
      this.available = true});

  final String id;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final double rawPrice;
  final String billingPeriod;
  final bool available;

  factory AppProductDetails.fromMap(Map<String, dynamic> data) =>
      AppProductDetails(
        id: data['id']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        price: data['price']?.toString() ?? '',
        currencyCode: data['currencyCode']?.toString() ?? '',
        rawPrice: (data['rawPrice'] as num?)?.toDouble() ?? 0,
        billingPeriod: data['billingPeriod']?.toString() ?? '',
        available: data['available'] != false,
      );
}

/// Opening the native payment sheet is never treated as a successful purchase.
/// Only the verified, durably committed delivery event completes a purchase.
class InAppPurchaseService extends ChangeNotifier {
  InAppPurchaseService({required this.nativeBridge}) {
    NativeBridgeService.addPurchaseDeliveredListener(
        _onNativePurchaseDelivered);
    NativeBridgeService.addPurchaseStatusListener(_onNativePurchaseStatus);
  }

  final NativeBridgeService nativeBridge;
  final Map<String, AppProductDetails> _products = {};
  final Map<String, String> _unavailableReasons = {};
  final List<void Function(String)> _deliveryListeners = [];
  bool _disposed = false;
  bool _isAvailable = false;
  bool _isLoading = false;
  bool _restoring = false;
  final Set<String> _pendingProducts = {};
  String? _checkoutProductId;
  Future<void>? _loadingFuture;
  String _lastError = '';
  String _catalogError = '';
  PurchaseFlowStatus status = PurchaseFlowStatus.idle;
  String? activeProductId;
  String statusMessage = '';
  VoidCallback? onPurchaseCompleted;

  Map<String, AppProductDetails> get products => UnmodifiableMapView(_products);
  bool get hasProducts => _products.isNotEmpty;
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isRestoring => _restoring;
  bool get isPurchasing =>
      _restoring ||
      _checkoutProductId != null ||
      _pendingProducts.isNotEmpty ||
      status == PurchaseFlowStatus.launching ||
      status == PurchaseFlowStatus.pending ||
      status == PurchaseFlowStatus.verifying;
  String get error => _lastError.isNotEmpty ? _lastError : _catalogError;

  AppProductDetails? getProductDetails(String productId) =>
      _products[StoreCatalog.canonicalId(productId)];

  void addDeliveryListener(void Function(String) listener) {
    if (!_deliveryListeners.contains(listener)) {
      _deliveryListeners.add(listener);
    }
  }

  void removeDeliveryListener(void Function(String) listener) =>
      _deliveryListeners.remove(listener);

  Future<void> initialize() => loadProducts();

  Future<void> loadProducts() {
    if (_loadingFuture != null) return _loadingFuture!;
    final future = _loadProducts();
    _loadingFuture = future;
    return future.whenComplete(() => _loadingFuture = null);
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    _catalogError = '';
    _notify();
    try {
      final response = await nativeBridge
          .getBillingProducts()
          .timeout(const Duration(seconds: 25));
      _products.clear();
      _unavailableReasons.clear();
      final rawProducts = response['products'];
      if (rawProducts is List) {
        for (final raw in rawProducts.whereType<Map>()) {
          final detail =
              AppProductDetails.fromMap(Map<String, dynamic>.from(raw));
          if (detail.id.isEmpty || detail.price.isEmpty || !detail.available) {
            if (detail.id.isNotEmpty) {
              _unavailableReasons[StoreCatalog.canonicalId(detail.id)] =
                  _friendlyError(raw['availabilityMessage']?.toString() ??
                      'Product not returned by Google Play.');
            }
            continue;
          }
          final canonical = StoreCatalog.canonicalId(detail.id);
          if (!_products.containsKey(canonical) || detail.id == canonical) {
            _products[canonical] = detail;
          }
        }
      }
      _isAvailable = response['available'] == true && _products.isNotEmpty;
      if (!_isAvailable) {
        _catalogError = response['error']?.toString().isNotEmpty == true
            ? _friendlyError(response['error'].toString())
            : 'لم تصل المنتجات من Google Play. تحقق من تفعيل خيارات الشراء وتوفّرها لحساب المتجر.';
      }
    } catch (_) {
      _products.clear();
      _unavailableReasons.clear();
      _isAvailable = false;
      _catalogError = 'تعذر تحميل الأسعار من Google Play. أعد المحاولة.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  String getExplanation(String productId) =>
      _unavailableReasons[StoreCatalog.canonicalId(productId)] ??
      (error.isNotEmpty
          ? error
          : 'تعذر إتمام عملية الشراء. أعد المحاولة من المتجر.');

  Future<bool> buyProduct(String productId) async {
    if (isPurchasing) return false;
    final detail = getProductDetails(productId);
    if (!_isAvailable || detail == null || !detail.available) {
      _lastError = getExplanation(productId);
      _notify();
      return false;
    }
    activeProductId = StoreCatalog.canonicalId(productId);
    _checkoutProductId = activeProductId;
    status = PurchaseFlowStatus.launching;
    statusMessage = 'جارٍ فتح نافذة الدفع الآمنة…';
    _lastError = '';
    _notify();
    try {
      final response = await nativeBridge
          .launchBilling(detail.id)
          .timeout(const Duration(seconds: 60));
      if (response['success'] != true) {
        _fail(response['message']?.toString() ?? 'تعذر فتح نافذة الدفع.');
        return false;
      }
      return true;
    } catch (_) {
      _fail('تعذر فتح نافذة الدفع. تحقق من اتصالك وأعد المحاولة.');
      return false;
    }
  }

  void _onNativePurchaseStatus(Map<String, dynamic> event) {
    final id = event['productId']?.toString() ?? '';
    final canonical = StoreCatalog.canonicalId(id);
    final nativeStatus = event['status']?.toString() ?? '';
    if (nativeStatus == 'pending' && id.isNotEmpty) {
      _pendingProducts.add(canonical);
    } else if (nativeStatus == 'delivered' ||
        nativeStatus == 'cancelled' ||
        nativeStatus == 'canceled') {
      _pendingProducts.remove(canonical);
    }
    if (_checkoutProductId != null &&
        id.isNotEmpty &&
        canonical != _checkoutProductId) {
      _notify();
      return;
    }
    if (nativeStatus == 'delivered' ||
        nativeStatus == 'cancelled' ||
        nativeStatus == 'canceled' ||
        nativeStatus == 'failed' ||
        nativeStatus == 'error') {
      _checkoutProductId = null;
    }
    // Restoring an unrelated receipt must not erase a pending payment.
    if (_pendingProducts.isNotEmpty && nativeStatus == 'delivered') {
      _notify();
      return;
    }
    if (id.isNotEmpty) activeProductId = canonical;
    switch (event['status']?.toString() ?? '') {
      case 'launching':
        status = PurchaseFlowStatus.launching;
      case 'pending':
        status = PurchaseFlowStatus.pending;
      case 'verifying':
        status = PurchaseFlowStatus.verifying;
      case 'delivered':
        status = PurchaseFlowStatus.delivered;
      case 'cancelled':
      case 'canceled':
        status = PurchaseFlowStatus.canceled;
      case 'error':
      case 'failed':
        status = PurchaseFlowStatus.failed;
      default:
        return;
    }
    statusMessage = switch (status) {
      PurchaseFlowStatus.launching => 'جارٍ فتح نافذة الدفع الآمنة…',
      PurchaseFlowStatus.pending =>
        'الدفع معلّق لدى Google Play. ستصلك المشتريات بعد تأكيده.',
      PurchaseFlowStatus.verifying => 'جارٍ التحقق من الدفع وحفظ مشترياتك…',
      PurchaseFlowStatus.delivered => 'تم التحقق من الدفع وتسليم مشترياتك.',
      PurchaseFlowStatus.canceled => 'أُلغيت عملية الشراء.',
      PurchaseFlowStatus.failed =>
        _friendlyError(event['message']?.toString() ?? ''),
      PurchaseFlowStatus.idle => '',
    };
    if (status == PurchaseFlowStatus.failed) _lastError = statusMessage;
    _notify();
  }

  void _onNativePurchaseDelivered(String productId) {
    if (_disposed) return;
    final canonical = StoreCatalog.canonicalId(productId);
    _pendingProducts.remove(canonical);
    final matchesCheckout =
        _checkoutProductId == null || _checkoutProductId == canonical;
    if (_checkoutProductId == canonical) _checkoutProductId = null;
    if (_pendingProducts.isEmpty && matchesCheckout) {
      activeProductId = canonical;
      status = PurchaseFlowStatus.delivered;
      statusMessage = 'تم التحقق من الدفع وتسليم مشترياتك.';
    } else if (matchesCheckout && _pendingProducts.isNotEmpty) {
      activeProductId = _pendingProducts.first;
      status = PurchaseFlowStatus.pending;
      statusMessage =
          'هناك دفعة معلّقة لدى Google Play. يمكنك التحقق منها عبر استعادة المشتريات.';
    }
    _lastError = '';
    _notify();
    try {
      onPurchaseCompleted?.call();
    } catch (error) {
      debugPrint('[Commerce] Delivery callback failed: $error');
    }
    for (final listener in List.of(_deliveryListeners)) {
      try {
        listener(canonical);
      } catch (error) {
        debugPrint('[Commerce] Delivery listener failed: $error');
      }
    }
  }

  Future<bool> restorePurchases() async {
    if (_restoring ||
        status == PurchaseFlowStatus.launching ||
        status == PurchaseFlowStatus.verifying) {
      return false;
    }
    _restoring = true;
    _lastError = '';
    statusMessage = 'جارٍ التحقق من مشتريات حسابك…';
    _notify();
    try {
      final result = await nativeBridge
          .restorePurchaseState()
          .timeout(const Duration(seconds: 60));
      final restored = result['success'] == true;
      if (restored && result['pendingCount'] == 0) {
        _pendingProducts.clear();
        _checkoutProductId = null;
        if (status == PurchaseFlowStatus.pending) {
          status = PurchaseFlowStatus.idle;
        }
      }
      if (!restored) {
        _fail(result['message']?.toString().isNotEmpty == true
            ? result['message'].toString()
            : 'تعذر استعادة المشتريات الآن. أعد المحاولة لاحقاً.');
      } else if (status != PurchaseFlowStatus.pending) {
        status = PurchaseFlowStatus.idle;
        activeProductId = null;
        statusMessage =
            'تمت مزامنة مشتريات الحساب. العملات المستهلكة لا تُمنح مجدداً.';
      }
      return restored;
    } catch (_) {
      _fail('تعذر التحقق من مشترياتك الآن. يمكنك إعادة الاستعادة لاحقاً.');
      return false;
    } finally {
      _restoring = false;
      _notify();
    }
  }

  Future<bool> manageSubscriptions() => nativeBridge.manageSubscriptions();

  void _fail(String message) {
    _checkoutProductId = null;
    status = PurchaseFlowStatus.failed;
    _lastError = _friendlyError(message);
    statusMessage = _lastError;
    _notify();
  }

  String _friendlyError(String message) {
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(message)) return message;
    final lower = message.toLowerCase();
    if (lower.contains('commerce/backend-not-configured') ||
        lower.contains('not been deployed')) {
      return 'خدمة الشراء غير مفعّلة حالياً. يلزم إكمال إعدادها قبل الشراء أو استعادة المشتريات.';
    }
    if (lower.contains('commerce/backend-access-denied') ||
        lower.contains('not configured correctly')) {
      return 'خدمة التحقق من الدفع تحتاج إلى تصحيح صلاحياتها. يرجى التواصل مع دعم اللعبة.';
    }
    if (lower.contains('another game account') ||
        lower.contains('different game account') ||
        lower.contains('does not match your game account')) {
      return 'هذه المشتريات مرتبطة بحساب لعبة آخر. سجّل الدخول إلى الحساب الذي اشتريتها به.';
    }
    if (lower.contains('wallet is syncing')) {
      return 'جارٍ مزامنة محفظة حسابك. انتظر قليلاً ثم أعد المحاولة.';
    }
    if (lower.contains('sign in') || lower.contains('authenticate')) {
      return 'سجّل الدخول إلى حسابك لحماية مشترياتك واستعادتها.';
    }
    if (lower.contains('legacy')) {
      return 'هذه عملية شراء قديمة تحتاج إلى مراجعة ملكيتها. تواصل مع دعم اللعبة.';
    }
    if (lower.contains('already owned') || lower.contains('already active')) {
      return 'هذا المنتج مملوك لحسابك بالفعل. راجع مجموعتك أو إدارة الاشتراك.';
    }
    if (lower.contains('monthly auto-renewing') ||
        lower.contains('eligible subscription offer')) {
      return 'الخطة الشهرية غير متاحة لحساب Google Play الحالي. تحقق من تفعيل خطة الاشتراك وتوفّرها في بلدك.';
    }
    if (lower.contains('buy purchase option') ||
        lower.contains('eligible purchase option')) {
      return 'خيار شراء هذا المنتج غير متاح في Google Play حالياً. يلزم تفعيل خيار شراء متاح في بلدك.';
    }
    if (lower.contains('product not returned') ||
        lower.contains('currently unavailable in google play')) {
      return 'هذا المنتج لم يصل من Google Play. تحقق من تفعيل خيار الشراء وتوفّره في بلد حسابك ثم حدّث المنتجات.';
    }
    if (lower.contains('product query failed')) {
      return 'تعذر تحميل المنتجات من Google Play. حدّث المنتجات وأعد المحاولة.';
    }
    if (lower.contains('refunded') ||
        lower.contains('revoked') ||
        lower.contains('expired')) {
      return 'هذه المشتريات منتهية الصلاحية أو أُلغيت أو رُدّ ثمنها. راجع سجل الطلبات في Google Play.';
    }
    if (lower.contains('commerce/timeout') || lower.contains('timed out')) {
      return 'استغرق التحقق من الدفع وقتاً أطول من المتوقع. أعد المحاولة أو استخدم استعادة المشتريات.';
    }
    if (lower.contains('commerce/backend-') ||
        lower.contains('verification is temporarily unavailable')) {
      return 'خدمة التحقق من الدفع غير متاحة مؤقتاً. أعد المحاولة لاحقاً.';
    }
    return 'تعذر إتمام العملية الآن. تحقق من اتصالك واستخدم استعادة المشتريات لإعادة التحقق.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    NativeBridgeService.removePurchaseDeliveredListener(
        _onNativePurchaseDelivered);
    NativeBridgeService.removePurchaseStatusListener(_onNativePurchaseStatus);
    _deliveryListeners.clear();
    super.dispose();
  }
}
