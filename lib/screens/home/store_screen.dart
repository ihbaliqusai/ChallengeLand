import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../models/game_category.dart';
import '../../models/store_catalog.dart';
import '../../services/ad_service.dart';
import '../../services/cross_promo_service.dart';
import '../../services/in_app_purchase_service.dart';
import '../../services/native_bridge_service.dart';
import '../../widgets/cross_promo_millionaire_dialog.dart';
import '../../widgets/currency_reward_overlay.dart';
import '../character/character_select_screen.dart';
import '../legal/privacy_policy_screen.dart';

const _background = Color(0xFF080D1B);
const _surface = Color(0xFF121A2E);
const _muted = Color(0xFF9EABC5);
const _purple = Color(0xFFA78BFA);
const _gold = Color(0xFFFFD166);
const _cyan = Color(0xFF64DEF5);
const _green = Color(0xFF76E0B2);

enum _StoreSection { featured, gems, coins, membership, collection }

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.initialKind});
  final StoreProductKind? initialKind;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  _StoreSection _section = _StoreSection.featured;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  InAppPurchaseService? _purchaseService;
  Timer? _refreshTimer;
  bool _busy = false;
  bool _onlyUnowned = false;

  bool get _arabic => context.read<AppSettings>().isArabic;
  String _tr(String ar, String en) => _arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _section = switch (widget.initialKind) {
      StoreProductKind.gems => _StoreSection.gems,
      StoreProductKind.coins => _StoreSection.coins,
      StoreProductKind.subscription => _StoreSection.membership,
      StoreProductKind.categoryPass => _StoreSection.collection,
      _ => _StoreSection.featured,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _purchaseService = context.read<InAppPurchaseService>();
      _purchaseService!.addDeliveryListener(_onDelivered);
      unawaited(_refresh());
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _purchaseService?.removeDeliveryListener(_onDelivered);
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    CrossPromoService? promo;
    try {
      promo = context.read<CrossPromoService>();
    } catch (_) {}
    String? uid;
    try {
      uid = app.user?.uid;
    } catch (_) {}
    await Future.wait([
      context.read<InAppPurchaseService>().loadProducts(),
      app.loadCurrency(),
      app.loadCategoryState(),
      app.loadCharacterState(),
      app.loadLevelData(),
      if (promo != null) promo.checkInstallation(),
      if (promo != null) promo.checkRewardClaimed(uid: uid),
    ]);
  }

  void _onDelivered(String id) => unawaited(_showDelivered(id));

  Future<void> _showDelivered(String id) async {
    if (!mounted) return;
    final app = context.read<AppState>();
    await Future.wait([app.loadCurrency(), app.loadCategoryState()]);
    if (!mounted) return;
    _snack(_tr('تم تسليم مشترياتك وتحديث حسابك.',
        'Your purchase was delivered and your account updated.'));
    final product = StoreCatalog.byId(id);
    if (product != null && (product.coins > 0 || product.gems > 0)) {
      showCurrencyRewardOverlay(context,
          coins: product.coins, gems: product.gems);
    }
  }

  void _selectSection(_StoreSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(context.read<AppSettings>().playHaptic());
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message,
            textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr),
        backgroundColor:
            error ? const Color(0xFF863548) : const Color(0xFF17645B),
        behavior: SnackBarBehavior.floating,
      ));
  }

  bool _owned(StoreProduct product, AppState app) =>
      product.kind == StoreProductKind.subscription
          ? app.isVip
          : product.kind == StoreProductKind.categoryPass
              ? app.hasPermanentCategoryPass ||
                  app.ownedStoreProducts.contains(product.id)
              : product.oneTime && app.ownedStoreProducts.contains(product.id);

  String _title(StoreProduct product) {
    if (_arabic) return product.title;
    return switch (product.id) {
      'gems_80' => 'Pocket of gems',
      'gems_500' => 'Gem chest',
      'gems_1200' => 'Gem vault',
      'coins_5000' => 'Coin pouch',
      'coins_25000' => 'Coin chest',
      'coins_100000' => 'Coin vault',
      'pack_starter' => 'Starter bundle',
      'pack_value' => 'Explorer bundle',
      'pack_champion' => 'Champion bundle',
      'vip_monthly' => 'Champions Club',
      'category_all_access' => 'All categories pass',
      _ => product.title,
    };
  }

  String _subtitle(StoreProduct product) => _arabic
      ? product.subtitle
      : switch (product.kind) {
          StoreProductKind.gems =>
            'Unlock categories and grow your collection.',
          StoreProductKind.coins =>
            'More coins for characters and in-game items.',
          StoreProductKind.bundle => 'Coins and gems together in one purchase.',
          StoreProductKind.subscription =>
            'Premium categories and no forced ads while your membership is active.',
          StoreProductKind.categoryPass =>
            'Own every current premium category with one purchase.',
        };

  Color _accent(StoreProduct product) => switch (product.kind) {
        StoreProductKind.coins => _gold,
        StoreProductKind.gems => _cyan,
        StoreProductKind.bundle => _purple,
        StoreProductKind.subscription => _gold,
        StoreProductKind.categoryPass => _green,
      };

  IconData _icon(StoreProduct product) => switch (product.kind) {
        StoreProductKind.coins => Icons.monetization_on_rounded,
        StoreProductKind.gems => Icons.diamond_rounded,
        StoreProductKind.bundle => Icons.inventory_2_rounded,
        StoreProductKind.subscription => Icons.workspace_premium_rounded,
        StoreProductKind.categoryPass => Icons.auto_awesome_motion_rounded,
      };

  Future<void> _buyProduct(StoreProduct product) async {
    final iap = context.read<InAppPurchaseService>();
    final app = context.read<AppState>();
    if (_busy ||
        iap.isPurchasing ||
        _owned(product, app) ||
        !app.isCommerceReady) {
      return;
    }
    final details = iap.getProductDetails(product.id);
    if (!iap.isAvailable || details == null || details.price.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<AppSettings>().playHaptic();
      if (!mounted) return;
      final confirmed = await _confirmProduct(product, details.price);
      if (!confirmed || !mounted) return;
      // Only the delivery event may report success; opening billing is not delivery.
      final launched = await iap.buyProduct(product.id);
      if (!launched && mounted) {
        await app.loadCategoryState();
        if (!mounted) return;
        _snack(iap.getExplanation(product.id), error: true);
      }
    } catch (_) {
      _snack(
          _tr('تعذر فتح عملية الشراء. حاول مجدداً.',
              'Could not start your purchase. Please try again.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmProduct(StoreProduct product, String price) =>
      _confirmSheet(
        title: _title(product),
        subtitle: _subtitle(product),
        icon: _icon(product),
        accent: _accent(product),
        body: [
          if (product.coins > 0 || product.gems > 0)
            _rewardSummary(product.coins, product.gems),
          if (product.kind == StoreProductKind.categoryPass)
            _benefit(
                Icons.lock_open_rounded,
                _tr('فتح دائم لجميع الفئات المميزة الحالية',
                    'Permanent access to all current premium categories')),
          if (product.kind == StoreProductKind.subscription) ...[
            _benefit(
                Icons.category_rounded,
                _tr('جميع الفئات المميزة طوال صلاحية الاشتراك',
                    'All premium categories while your membership is active')),
            _benefit(
                Icons.block_rounded,
                _tr('بدون إعلانات إجبارية؛ إعلانات المكافآت اختيارية',
                    'No forced ads; reward ads remain optional')),
          ],
          const SizedBox(height: 14),
          _receiptRow(
              _tr('المبلغ الإجمالي', 'Total'),
              product.kind == StoreProductKind.subscription
                  ? '$price / ${_tr('شهر', 'month')}'
                  : price),
          const SizedBox(height: 12),
          Text(
              product.kind == StoreProductKind.subscription
                  ? _tr(
                      'اشتراك شهري يتجدد تلقائياً. تُحصّل الدفعة عند التأكيد، ثم كل شهر ما لم تلغِ التجديد عبر اشتراكات Google Play قبل موعد التجديد. يظل الوصول متاحاً حتى نهاية الفترة المدفوعة بعد الإلغاء. راجع السعر والفترة في نافذة Google Play قبل الدفع.',
                      'A monthly, automatically renewing subscription. Payment is charged at confirmation and every month until you cancel renewal in Google Play subscriptions before the renewal date. Access continues until the paid period ends after cancellation. Review the price and billing period in Google Play before paying.')
                  : product.oneTime
                      ? _tr(
                          'شراء لمرة واحدة. راجع السعر النهائي في Google Play قبل التأكيد.',
                          'One-time purchase. Review the final price in Google Play before confirming.')
                      : _tr(
                          'تُضاف العملات بعد تأكيد الدفع وتسليم العملية. راجع السعر النهائي في Google Play.',
                          'Currency is added after payment confirmation and delivery. Review the final price in Google Play.'),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.7)),
        ],
        button: _tr('المتابعة إلى الدفع', 'Continue to payment'),
      );

  Future<bool> _confirmSheet(
          {required String title,
          required String subtitle,
          required IconData icon,
          required Color accent,
          required List<Widget> body,
          required String button}) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: _surface,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        constraints: const BoxConstraints(maxWidth: 580),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (sheetContext) => Directionality(
          textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                              color: _muted.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10)))),
                  Row(children: [
                    _iconTile(icon, accent, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22)))
                  ]),
                  const SizedBox(height: 10),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, height: 1.6)),
                  const SizedBox(height: 20),
                  ...body,
                  const SizedBox(height: 20),
                  _StoreButton(
                      label: button,
                      icon: Icons.lock_outline_rounded,
                      accent: accent,
                      onPressed: () => Navigator.of(sheetContext).pop(true)),
                  const SizedBox(height: 6),
                  TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(_tr('إلغاء', 'Cancel'),
                          style: const TextStyle(color: _muted))),
                ]),
          )),
        ),
      ) ??
      false;

  Future<void> _exchange(CoinExchange exchange) async {
    if (_busy || context.read<InAppPurchaseService>().isPurchasing) return;
    final app = context.read<AppState>();
    if (app.gems < exchange.gemCost) {
      _snack(
          _tr('تحتاج ${_number(exchange.gemCost - app.gems)} جوهرة إضافية.',
              'You need ${_number(exchange.gemCost - app.gems)} more gems.'),
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await _confirmSheet(
        title: _tr('تحويل الجواهر إلى نقود', 'Exchange gems for coins'),
        subtitle: _tr('سيُخصم المبلغ من رصيد جواهرك داخل اللعبة.',
            'The cost will be deducted from your in-game gem balance.'),
        icon: Icons.currency_exchange_rounded,
        accent: _gold,
        body: [
          _receiptRow(_tr('الجواهر المطلوبة', 'Gem cost'),
              '${_number(exchange.gemCost)} ${_tr('جوهرة', 'gems')}'),
          const SizedBox(height: 12),
          _receiptRow(_tr('النقود التي تحصل عليها', 'Coins received'),
              '${_number(exchange.coins)} ${_tr('قطعة', 'coins')}')
        ],
        button: _tr('تأكيد التحويل', 'Confirm exchange'),
      );
      if (!confirmed || !mounted) return;
      final success = await context
          .read<NativeBridgeService>()
          .buyCurrency(coinAmount: exchange.coins, gemCost: exchange.gemCost);
      await app.loadCurrency();
      if (!mounted) return;
      if (success) {
        showCurrencyRewardOverlay(context, coins: exchange.coins, gems: 0);
      } else {
        _snack(
            _tr('لم يكتمل التحويل. تحقق من رصيدك وحاول مجدداً.',
                'The exchange did not complete. Check your balance and try again.'),
            error: true);
      }
    } catch (_) {
      _snack(
          _tr('تعذر تحويل الجواهر الآن.', 'Could not exchange gems right now.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _categoryOwned(GameCategory category, AppState app) =>
      app.hasPermanentCategoryPass ||
      app.unlockedCategories.any((name) =>
          GameCategory.normalize(name) ==
          GameCategory.normalize(category.name));

  Future<void> _unlockCategory(GameCategory category) async {
    final app = context.read<AppState>();
    if (_busy ||
        context.read<InAppPurchaseService>().isPurchasing ||
        _categoryOwned(category, app)) {
      return;
    }
    if (app.gems < category.gemCost) {
      _snack(
          _tr('تحتاج ${_number(category.gemCost - app.gems)} جوهرة إضافية.',
              'You need ${_number(category.gemCost - app.gems)} more gems.'),
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await _confirmSheet(
          title: category.name,
          subtitle: _tr('امتلاك دائم لهذه الفئة، دون اشتراك.',
              'Permanent ownership of this category, with no subscription.'),
          icon: Icons.category_rounded,
          accent: _cyan,
          body: [
            _receiptRow(_tr('التكلفة', 'Cost'),
                '${category.gemCost} ${_tr('جوهرة', 'gems')}'),
            const SizedBox(height: 10),
            _receiptRow(_tr('رصيدك بعد الشراء', 'Balance after purchase'),
                '${_number(app.gems - category.gemCost)} ${_tr('جوهرة', 'gems')}')
          ],
          button: _tr('امتلاك الفئة', 'Unlock category'));
      if (!confirmed || !mounted) return;
      final success = await app.unlockCategoryWithGems(category.name,
          gemCost: category.gemCost);
      _snack(
          success
              ? _tr('أصبحت فئة ${category.name} ملكك بشكل دائم.',
                  'You now permanently own ${category.name}.')
              : _tr('لم يكتمل فتح الفئة. حاول مجدداً.',
                  'The category could not be unlocked. Please try again.'),
          error: !success);
    } catch (_) {
      _snack(
          _tr('تعذر شراء الفئة الآن.',
              'Could not unlock this category right now.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rentCategory(GameCategory category) async {
    final app = context.read<AppState>();
    if (_busy ||
        context.read<InAppPurchaseService>().isPurchasing ||
        app.isCategoryUnlocked(category.name)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final watched = await context.read<AdService>().showActionRewardedAd();
      if (!mounted) return;
      if (!watched) {
        _snack(
            _tr('الإعلان غير متاح أو لم تكتمل مشاهدته.',
                'The ad is unavailable or was not watched to completion.'),
            error: true);
        return;
      }
      final unlocked = await app.rentCategoryWithAd(category.name, hours: 24);
      _snack(
          unlocked
              ? _tr('فئة ${category.name} متاحة لك لمدة 24 ساعة.',
                  '${category.name} is available for 24 hours.')
              : _tr('تعذر تفعيل الفئة الآن.',
                  'Could not activate the category right now.'),
          error: !unlocked);
    } catch (_) {
      _snack(
          _tr('تعذر تفعيل تجربة الفئة.', 'Could not start the category trial.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _watchAd() async {
    if (_busy) return;
    final ads = context.read<AdService>();
    if (!ads.canWatchAd) return;
    setState(() => _busy = true);
    try {
      final reward = await ads.showRewardedAd();
      if (!mounted) return;
      if (reward == null) {
        _snack(
            _tr('الإعلان غير متاح أو لم تكتمل مشاهدته.',
                'The ad is unavailable or was not watched to completion.'),
            error: true);
        return;
      }
      await context.read<NativeBridgeService>().grantCurrency(
          coins: reward['coins'] ?? 0, gems: reward['gems'] ?? 0);
      if (!mounted) return;
      await context.read<AppState>().loadCurrency();
      if (!mounted) return;
      showCurrencyRewardOverlay(context,
          coins: reward['coins'] ?? 0, gems: reward['gems'] ?? 0);
    } catch (_) {
      _snack(
          _tr('تعذر استلام مكافأة الإعلان الآن.',
              'Could not receive the ad reward right now.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimDailyReward() async {
    if (_busy) return;
    final app = context.read<AppState>();
    if (app.claimedToday ||
        !app.dailyStreakLoaded ||
        !app.isOnline ||
        app.user == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final reward = await app.claimDailyStreak();
      if (!mounted) return;
      if (reward != null) {
        showCurrencyRewardOverlay(context,
            coins: reward['coins'] ?? 0, gems: reward['gems'] ?? 0);
      } else {
        _snack(
            _tr('تعذر استلام الهدية الآن. حاول مجدداً.',
                'Could not claim your gift right now. Please try again.'),
            error: true);
      }
    } catch (_) {
      _snack(
          _tr('تعذر استلام الهدية الآن.',
              'Could not claim your gift right now.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restorePurchases() async {
    final iap = context.read<InAppPurchaseService>();
    if (_busy ||
        iap.isRestoring ||
        iap.status == PurchaseFlowStatus.launching ||
        iap.status == PurchaseFlowStatus.verifying) {
      return;
    }
    setState(() => _busy = true);
    try {
      final success = await iap.restorePurchases();
      if (!mounted) return;
      final app = context.read<AppState>();
      await Future.wait([app.loadCategoryState(), app.loadCurrency()]);
      _snack(
          success
              ? _tr(
                  'تمت مراجعة المشتريات. ستظهر الحقوق النشطة بعد تأكيدها من المتجر.',
                  'Purchases checked. Active entitlements appear after store confirmation.')
              : _tr(
                  iap.error.isNotEmpty
                      ? iap.error
                      : 'تعذر استعادة المشتريات الآن. أعد المحاولة لاحقاً.',
                  'Could not restore purchases. Check your Google Play account and connection.'),
          error: !success);
    } catch (_) {
      _snack(
          _tr('تعذر استعادة المشتريات الآن.',
              'Could not restore purchases right now.'),
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageSubscription() async {
    try {
      final success =
          await context.read<InAppPurchaseService>().manageSubscriptions();
      if (!success) {
        _snack(
            _tr('تعذر فتح إدارة الاشتراكات الآن.',
                'Could not open subscription management right now.'),
            error: true);
      }
    } catch (_) {
      _snack(
          _tr('تعذر فتح إدارة الاشتراكات الآن.',
              'Could not open subscription management right now.'),
          error: true);
    }
  }

  Future<void> _retryPurchases() async {
    final iap = context.read<InAppPurchaseService>();
    final retryVerification = iap.status == PurchaseFlowStatus.failed;
    await iap.loadProducts();
    if (mounted && retryVerification) await _restorePurchases();
  }

  Future<void> _openCharacters() async {
    if (_busy) return;
    await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const CharacterSelectScreen()));
    if (!mounted) return;
    final app = context.read<AppState>();
    await Future.wait([app.loadCharacterState(), app.loadCurrency()]);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final iap = context.watch<InAppPurchaseService>();
    final ads = context.watch<AdService>();
    final settings = context.watch<AppSettings>();
    final disabled = _busy || iap.isPurchasing;
    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _background,
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF16152F), _background, Color(0xFF071826)],
                  stops: [0, 0.55, 1])),
          child: SafeArea(
              child: Column(children: [
            _header(app),
            if (_showStatus(iap)) _purchaseStatus(iap),
            _tabs(),
            Expanded(
                child: RefreshIndicator(
              color: _cyan,
              backgroundColor: _surface,
              onRefresh: _refresh,
              child: LayoutBuilder(builder: (context, constraints) {
                final padding = constraints.maxWidth >= 800 ? 28.0 : 16.0;
                return ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padding, 18, padding, 24),
                  children: [
                    Center(
                        child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_section == _StoreSection.featured) ...[
                              _featured(iap, app, disabled),
                              const SizedBox(height: 22),
                              _sectionTitle(
                                  _tr('اختر طريقتك للعب', 'Make it your game'),
                                  _tr('عملات، عضوية، وفئات تملكها',
                                      'Currency, membership and a collection of your own')),
                              const SizedBox(height: 12),
                              _discoveryTiles(),
                              const SizedBox(height: 22),
                              _sectionTitle(
                                  _tr('باقات تجمع النقود والجواهر',
                                      'Coins and gems, together'),
                                  _tr('المحتويات واضحة قبل كل عملية شراء',
                                      'See exactly what is included before you buy')),
                              const SizedBox(height: 12),
                              _productGrid(
                                  StoreCatalog.products
                                      .where((p) =>
                                          p.kind == StoreProductKind.bundle &&
                                          p.id != 'pack_starter')
                                      .toList(),
                                  iap,
                                  app,
                                  disabled),
                              const SizedBox(height: 22),
                              _freeRewards(app, ads, disabled),
                            ],
                            if (_section == _StoreSection.gems) ...[
                              _sectionTitle(
                                  _tr('رصيدك من الجواهر، خيارات أكثر',
                                      'More gems. More possibilities.'),
                                  _tr('لفتح الفئات وشراء الشخصيات وتحويلها إلى نقود',
                                      'Unlock categories, collect characters or exchange for coins')),
                              const SizedBox(height: 16),
                              _productGrid(
                                  StoreCatalog.products
                                      .where((p) =>
                                          p.kind == StoreProductKind.gems)
                                      .toList(),
                                  iap,
                                  app,
                                  disabled),
                              const SizedBox(height: 22),
                              _freeRewards(app, ads, disabled),
                            ],
                            if (_section == _StoreSection.coins) ...[
                              _sectionTitle(
                                  _tr('نقود لتوسيع مجموعتك',
                                      'Coins for your collection'),
                                  _tr('شراء مباشر من المتجر أو تحويل جواهرك',
                                      'Buy through the store or exchange your gems')),
                              const SizedBox(height: 16),
                              _productGrid(
                                  StoreCatalog.products
                                      .where((p) =>
                                          p.kind == StoreProductKind.coins)
                                      .toList(),
                                  iap,
                                  app,
                                  disabled),
                              const SizedBox(height: 24),
                              _sectionTitle(
                                  _tr('تحويل الجواهر إلى نقود',
                                      'Exchange gems for coins'),
                                  _tr('تستخدم رصيدك داخل اللعبة، دون دفعة مالية',
                                      'Spend your in-game gems, with no cash payment')),
                              const SizedBox(height: 12),
                              _exchanges(app, disabled),
                            ],
                            if (_section == _StoreSection.membership)
                              _membership(iap, app, disabled),
                            if (_section == _StoreSection.collection)
                              _collection(iap, app, disabled),
                            const SizedBox(height: 24),
                            _footer(iap),
                          ]),
                    ))
                  ],
                );
              }),
            )),
          ])),
        ),
      ),
    );
  }

  Widget _header(AppState app) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
        child: Row(children: [
          IconButton(
              tooltip: _tr('العودة', 'Back'),
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  foregroundColor: Colors.white),
              icon: Icon(_arabic
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_tr('متجر التحدّي', 'Challenge Store'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800))),
          _walletChip(app.coins, Icons.monetization_on_rounded, _gold,
              _tr('نقود', 'coins'), () => _selectSection(_StoreSection.coins)),
          const SizedBox(width: 8),
          _walletChip(app.gems, Icons.diamond_rounded, _cyan,
              _tr('جواهر', 'gems'), () => _selectSection(_StoreSection.gems)),
        ]),
      );

  Widget _walletChip(int amount, IconData icon, Color color, String label,
          VoidCallback onTap) =>
      Semantics(
        label: '$label ${_number(amount)}',
        button: true,
        child: Material(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 6),
                Text(_number(amount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(width: 5),
                Icon(Icons.add_rounded, size: 15, color: color),
              ]),
            ),
          ),
        ),
      );

  Widget _tabs() {
    final tabs = <(_StoreSection, String, IconData)>[
      (
        _StoreSection.featured,
        _tr('المميزة', 'Featured'),
        Icons.auto_awesome_rounded
      ),
      (_StoreSection.gems, _tr('الجواهر', 'Gems'), Icons.diamond_rounded),
      (
        _StoreSection.coins,
        _tr('النقود', 'Coins'),
        Icons.monetization_on_rounded
      ),
      (
        _StoreSection.membership,
        _tr('العضوية', 'Membership'),
        Icons.workspace_premium_rounded
      ),
      (
        _StoreSection.collection,
        _tr('الفئات والشخصيات', 'Categories & characters'),
        Icons.grid_view_rounded
      ),
    ];
    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: Row(
            children: tabs.map((tab) {
          final selected = _section == tab.$1;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Semantics(
              selected: selected,
              button: true,
              child: Material(
                color: selected
                    ? _purple.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectSection(tab.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected
                                ? _purple.withValues(alpha: 0.5)
                                : Colors.transparent)),
                    child: Row(children: [
                      Icon(tab.$3,
                          size: 17, color: selected ? _purple : _muted),
                      const SizedBox(width: 7),
                      Text(tab.$2,
                          style: TextStyle(
                              color: selected ? Colors.white : _muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))
                    ]),
                  ),
                ),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }

  bool _showStatus(InAppPurchaseService iap) =>
      iap.isLoading ||
      iap.isRestoring ||
      !iap.isAvailable ||
      iap.error.isNotEmpty ||
      (iap.status != PurchaseFlowStatus.idle &&
          iap.status != PurchaseFlowStatus.delivered);

  Widget _purchaseStatus(InAppPurchaseService iap) {
    final processing = iap.isPurchasing || iap.isLoading;
    final error = !iap.isAvailable || iap.status == PurchaseFlowStatus.failed;
    final color = error ? const Color(0xFFFFA5A5) : _cyan;
    final message = iap.isLoading
        ? _tr('جارٍ تحميل الأسعار من Google Play…',
            'Loading prices from Google Play…')
        : iap.isRestoring
            ? _tr('جارٍ مراجعة المشتريات…', 'Checking previous purchases…')
            : iap.status == PurchaseFlowStatus.pending
                ? _tr(
                    'الدفع معلّق. ستُضاف مشترياتك بعد تأكيده، ويمكنك متابعة اللعب.',
                    'Payment is pending. Your purchase arrives after confirmation; you can keep playing.')
                : iap.status == PurchaseFlowStatus.verifying
                    ? _tr('جارٍ تأكيد الدفع وتسليم مشترياتك…',
                        'Confirming payment and delivering your purchase…')
                    : iap.status == PurchaseFlowStatus.launching
                        ? _tr('جارٍ فتح نافذة الدفع الآمنة…',
                            'Opening the secure payment sheet…')
                        : iap.status == PurchaseFlowStatus.canceled
                            ? _tr(
                                'تم إلغاء عملية الشراء.', 'Purchase canceled.')
                            : iap.status == PurchaseFlowStatus.failed
                                ? _tr(
                                    iap.error.isEmpty
                                        ? 'تعذر إتمام الشراء. استخدم استعادة المشتريات لإعادة التحقق.'
                                        : iap.error,
                                    'Your purchase could not be completed. Use Restore purchases to check its status.')
                                : _tr(
                                    iap.error.isNotEmpty
                                        ? iap.error
                                        : 'المتجر غير متاح حالياً. أعد المحاولة أو استخدم رصيدك داخل اللعبة.',
                                    'The store is currently unavailable. Retry or use your in-game balance.');
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        if (processing)
          SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: color))
        else
          Icon(error ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
              size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 12, height: 1.4))),
        if (error && !processing)
          TextButton(
              onPressed: _retryPurchases,
              style: TextButton.styleFrom(
                  foregroundColor: color, visualDensity: VisualDensity.compact),
              child: Text(_tr('إعادة المحاولة', 'Retry'))),
        if (iap.status == PurchaseFlowStatus.pending &&
            !iap.isRestoring &&
            !_busy)
          TextButton(
            onPressed: _restorePurchases,
            style: TextButton.styleFrom(
                foregroundColor: color, visualDensity: VisualDensity.compact),
            child: Text(_tr('التحقق', 'Check status')),
          ),
      ]),
    );
  }

  Widget _featured(InAppPurchaseService iap, AppState app, bool disabled) {
    final product = StoreCatalog.byId('pack_starter')!;
    return _panel(
      accent: _purple,
      gradient: const [Color(0xFF292247), Color(0xFF172036)],
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        return Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _pill(
                    _tr('بداية جديدة • شراء لمرة واحدة',
                        'A fresh start • One-time purchase'),
                    _purple),
                const SizedBox(height: 12),
                Text(_title(product),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.3)),
                const SizedBox(height: 6),
                Text(_subtitle(product),
                    style: const TextStyle(
                        color: Color(0xFFB9B2D3), fontSize: 13, height: 1.6)),
                const SizedBox(height: 15),
                _rewardSummary(product.coins, product.gems),
                const SizedBox(height: 18),
                SizedBox(
                    width: compact ? double.infinity : 290,
                    child: _purchaseButton(product, iap, disabled,
                        owned: _owned(product, app))),
              ])),
          if (!compact) ...[
            const SizedBox(width: 18),
            _ProductArt(
                icon: Icons.inventory_2_rounded,
                accent: _purple,
                size: constraints.maxWidth > 750 ? 156 : 110,
                bundle: true)
          ],
        ]);
      }),
    );
  }

  Widget _discoveryTiles() => _responsiveWrap(minWidth: 210, children: [
        _discovery(Icons.diamond_rounded, _cyan, _tr('الجواهر', 'Gems'),
            _tr('افتح ما تحب', 'Unlock what you love'), _StoreSection.gems),
        _discovery(
            Icons.workspace_premium_rounded,
            _gold,
            _tr('العضوية المميزة', 'Plus membership'),
            _tr('فئات أكثر، دون إعلانات إجبارية',
                'More categories, no forced ads'),
            _StoreSection.membership),
        _discovery(
            Icons.auto_awesome_motion_rounded,
            _green,
            _tr('مجموعتك', 'Your collection'),
            _tr('فئات وشخصيات بطابعك', 'Categories and characters, your way'),
            _StoreSection.collection),
      ]);

  Widget _discovery(IconData icon, Color color, String title, String subtitle,
          _StoreSection section) =>
      Material(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _selectSection(section),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(children: [
                _iconTile(icon, color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              color: _muted, fontSize: 11, height: 1.4))
                    ])),
                Icon(Icons.chevron_right_rounded,
                    textDirection:
                        _arabic ? TextDirection.rtl : TextDirection.ltr,
                    color: _muted,
                    size: 20),
              ])),
        ),
      );

  Widget _productGrid(List<StoreProduct> products, InAppPurchaseService iap,
          AppState app, bool disabled) =>
      _responsiveWrap(
          minWidth: 220,
          children: products
              .map((product) => _productCard(product, iap, app, disabled))
              .toList());

  Widget _productCard(StoreProduct product, InAppPurchaseService iap,
      AppState app, bool disabled) {
    final accent = _accent(product);
    final owned = _owned(product, app);
    return _panel(
      accent: accent,
      padding: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
              child: _pill(
                  product.oneTime
                      ? _tr('شراء لمرة واحدة', 'One-time purchase')
                      : product.kind == StoreProductKind.bundle
                          ? _tr('نقود + جواهر', 'Coins + gems')
                          : _tr('رصيد داخل اللعبة', 'In-game currency'),
                  accent)),
          if (owned)
            const Icon(Icons.check_circle_rounded, color: _green, size: 20)
        ]),
        const SizedBox(height: 10),
        Center(
            child: _ProductArt(
                icon: _icon(product),
                accent: accent,
                size: 84,
                bundle: product.kind == StoreProductKind.bundle)),
        const SizedBox(height: 12),
        Text(_title(product),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_subtitle(product),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.6)),
        const SizedBox(height: 13),
        _rewardSummary(product.coins, product.gems, centered: true),
        const SizedBox(height: 18),
        _purchaseButton(product, iap, disabled, owned: owned),
      ]),
    );
  }

  Widget _purchaseButton(
      StoreProduct product, InAppPurchaseService iap, bool disabled,
      {bool owned = false}) {
    final price = iap.getProductDetails(product.id)?.price;
    final available = iap.isAvailable && price != null && price.isNotEmpty;
    final checkingOwnership = !context.read<AppState>().isCommerceReady;
    final button = _StoreButton(
      label: owned
          ? product.kind == StoreProductKind.subscription
              ? _tr('إدارة الاشتراك', 'Manage membership')
              : _tr('تم الامتلاك', 'Owned')
          : checkingOwnership
              ? _tr('جارٍ التحقق من حسابك…', 'Checking your account…')
              : iap.isLoading
                  ? _tr('جارٍ تحميل السعر…', 'Loading price…')
                  : available
                      ? product.kind == StoreProductKind.subscription
                          ? '$price / ${_tr('شهر', 'month')}'
                          : price
                      : _tr('غير متاح حالياً', 'Currently unavailable'),
      icon: owned
          ? Icons.check_circle_outline_rounded
          : Icons.shopping_bag_outlined,
      accent: _accent(product),
      loading: iap.activeProductId == product.id && iap.isPurchasing,
      onPressed: owned
          ? product.kind == StoreProductKind.subscription && !disabled
              ? _manageSubscription
              : null
          : available && !disabled && !iap.isLoading && !checkingOwnership
              ? () => _buyProduct(product)
              : null,
    );
    if (owned || checkingOwnership || iap.isLoading || available) return button;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      button,
      const SizedBox(height: 8),
      Text(
          _tr(iap.getExplanation(product.id),
              'Google Play has not made this product available to your store account. Check its active purchase option and country.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.5)),
      TextButton.icon(
          onPressed: disabled ? null : () => iap.loadProducts(),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(_tr('تحديث المنتجات', 'Refresh products'))),
    ]);
  }

  Widget _membership(InAppPurchaseService iap, AppState app, bool disabled) {
    final product = StoreCatalog.byId('vip_monthly')!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle(
          _tr('تجربة أوسع، كل شهر', 'A richer experience, every month'),
          _tr('مزايا واضحة طوال فترة العضوية',
              'Clear benefits throughout your membership')),
      const SizedBox(height: 16),
      _panel(
        accent: _gold,
        gradient: const [Color(0xFF332C24), Color(0xFF1C2135)],
        child: LayoutBuilder(builder: (context, constraints) {
          final intro =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pill(
                app.isVip
                    ? _tr('عضويتك مفعّلة', 'Your membership is active')
                    : _tr('عضوية شهرية', 'Monthly membership'),
                app.isVip ? _green : _gold),
            const SizedBox(height: 14),
            Text(_title(product),
                style: const TextStyle(
                    color: _gold, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_subtitle(product),
                style:
                    const TextStyle(color: _muted, fontSize: 14, height: 1.6)),
            const SizedBox(height: 20),
            _benefit(
                Icons.grid_view_rounded,
                _tr('وصول لجميع الفئات المميزة',
                    'Access to every premium category')),
            const SizedBox(height: 12),
            _benefit(Icons.block_rounded,
                _tr('بدون إعلانات إجبارية', 'No forced ads')),
            const SizedBox(height: 12),
            _benefit(
                Icons.videocam_outlined,
                _tr('مكافآت الإعلانات تبقى اختيارية',
                    'Reward ads remain optional')),
            if (app.isVip && app.vipExpiresAtMillis > 0) ...[
              const SizedBox(height: 16),
              Text(
                  _tr('الفترة الحالية متاحة حتى ${_expiry(app.vipExpiresAtMillis)}',
                      'Current access is valid through ${_expiry(app.vipExpiresAtMillis)}'),
                  style: const TextStyle(color: _green, fontSize: 12)),
            ],
          ]);
          final action =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(
                child: _ProductArt(
                    icon: Icons.workspace_premium_rounded,
                    accent: _gold,
                    size: 100)),
            const SizedBox(height: 16),
            _purchaseButton(product, iap, disabled, owned: app.isVip),
            const SizedBox(height: 10),
            Text(
                _tr('يتجدد تلقائياً كل شهر. يمكنك إلغاء التجديد من Google Play في أي وقت؛ يستمر الوصول حتى نهاية الفترة المدفوعة.',
                    'Renews automatically every month. Cancel renewal in Google Play at any time; access continues until the paid period ends.'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: _muted, fontSize: 11, height: 1.7)),
          ]);
          return constraints.maxWidth >= 620
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: intro),
                  const SizedBox(width: 32),
                  Expanded(flex: 2, child: action)
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 20), action]);
        }),
      ),
      const SizedBox(height: 16),
      _panel(
          child: Row(children: [
        const Icon(Icons.lock_open_rounded, color: _green),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _tr('تفضّل امتلاك الفئات بشكل دائم؟',
                  'Prefer to own your categories?'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              _tr('بطاقة الفئات تُشترى مرة واحدة، ولا تزيل الإعلانات.',
                  'The categories pass is purchased once and keeps ads unchanged.'),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5))
        ])),
        const SizedBox(width: 12),
        TextButton(
            onPressed: () => _selectSection(_StoreSection.collection),
            child: Text(_tr('عرض البطاقة', 'View pass'),
                style: const TextStyle(color: _green))),
      ])),
    ]);
  }

  Widget _exchanges(AppState app, bool disabled) => _responsiveWrap(
        minWidth: 190,
        children: StoreCatalog.coinExchanges
            .map((exchange) => _panel(
                  accent: _gold,
                  padding: 16,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.currency_exchange_rounded,
                            color: _gold, size: 30),
                        const SizedBox(height: 12),
                        Text(_number(exchange.coins),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        Text(_tr('قطعة نقدية', 'coins'),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        const SizedBox(height: 16),
                        _StoreButton(
                            label:
                                '${_number(exchange.gemCost)} ${_tr('جوهرة', 'gems')}',
                            icon: Icons.diamond_rounded,
                            accent: _cyan,
                            onPressed:
                                disabled ? null : () => _exchange(exchange)),
                        if (app.gems < exchange.gemCost) ...[
                          const SizedBox(height: 8),
                          Text(
                              _tr('تحتاج ${_number(exchange.gemCost - app.gems)} جوهرة إضافية',
                                  'Need ${_number(exchange.gemCost - app.gems)} more gems'),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: _muted, fontSize: 10))
                        ],
                      ]),
                ))
            .toList(),
      );

  Widget _collection(InAppPurchaseService iap, AppState app, bool disabled) {
    final pass = StoreCatalog.byId('category_all_access')!;
    final ownedCount = CategoryCatalog.premiumCategories
        .where((cat) => _categoryOwned(cat, app))
        .length;
    final categories = CategoryCatalog.premiumCategories
        .where((cat) =>
            (!_onlyUnowned || !_categoryOwned(cat, app)) &&
            GameCategory.normalize(cat.name)
                .contains(GameCategory.normalize(_searchController.text)))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle(
          _tr('مجموعتك، بطابعك', 'Build your own collection'),
          _tr('$ownedCount من ${CategoryCatalog.premiumCategories.length} فئة مميزة مملوكة بشكل دائم',
              '$ownedCount of ${CategoryCatalog.premiumCategories.length} premium categories permanently owned')),
      const SizedBox(height: 16),
      _panel(
          accent: _green,
          child: LayoutBuilder(builder: (context, constraints) {
            final content = Row(children: [
              _iconTile(Icons.auto_awesome_motion_rounded, _green, size: 50),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_title(pass),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(_subtitle(pass),
                        style: const TextStyle(
                            color: _muted, fontSize: 12, height: 1.6)),
                    const SizedBox(height: 8),
                    _pill(
                        _tr('امتلاك دائم • دون اشتراك',
                            'Permanent ownership • No subscription'),
                        _green)
                  ]))
            ]);
            final action = _purchaseButton(pass, iap, disabled,
                owned: _owned(pass, app) ||
                    ownedCount == CategoryCatalog.premiumCategories.length);
            return constraints.maxWidth >= 660
                ? Row(children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    SizedBox(width: 220, child: action)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [content, const SizedBox(height: 18), action]);
          })),
      const SizedBox(height: 16),
      _characters(app, disabled),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
              child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: _tr('ابحث عن فئة تحبها', 'Find a category you love'),
              hintStyle: const TextStyle(color: _muted),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: _muted, size: 20),
              filled: true,
              fillColor: _surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _cyan)),
            ),
          )),
          const SizedBox(width: 12),
          FilterChip(
              label: Text(_tr('غير المملوكة', 'Unowned')),
              selected: _onlyUnowned,
              onSelected: (value) => setState(() => _onlyUnowned = value),
              backgroundColor: _surface,
              selectedColor: _cyan.withValues(alpha: 0.16),
              labelStyle:
                  TextStyle(color: _onlyUnowned ? _cyan : _muted, fontSize: 12),
              checkmarkColor: _cyan,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)))
        ],
      ),
      const SizedBox(height: 14),
      if (categories.isEmpty)
        Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
                _tr('لا توجد فئات تطابق البحث.',
                    'No categories match your search.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted)))
      else
        _responsiveWrap(
            minWidth: 175,
            children: categories
                .map((cat) => _categoryCard(cat, app, disabled))
                .toList()),
    ]);
  }

  Widget _characters(AppState app, bool disabled) {
    final character = app.selectedCharacter;
    final count = CharacterCatalog.all.where(app.isCharacterUnlocked).length;
    return _panel(
        child: Row(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
              width: 58,
              height: 58,
              color: character.color.withValues(alpha: 0.12),
              child: Image.asset(character.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_rounded, color: _purple)))),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_tr('شخصيات التحدّي', 'Challenge characters'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(
            _tr('$count من ${CharacterCatalog.all.length} شخصيات متاحة • اختر هويتك',
                '$count of ${CharacterCatalog.all.length} characters available • Choose your identity'),
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5))
      ])),
      const SizedBox(width: 12),
      TextButton(
          onPressed: disabled ? null : _openCharacters,
          child: Text(_tr('استكشف', 'Explore'),
              style: const TextStyle(color: _purple))),
    ]));
  }

  Widget _categoryCard(GameCategory category, AppState app, bool disabled) {
    final owned = _categoryOwned(category, app);
    final rentalHours = app.getCategoryRemainingRentalHours(category.name);
    final available = app.isCategoryUnlocked(category.name);
    final accent = owned
        ? _green
        : available
            ? _gold
            : _cyan;
    return _panel(
        padding: 14,
        accent: accent,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              height: 96,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.06)),
              child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(category.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.category_rounded,
                          color: accent, size: 38)))),
          const SizedBox(height: 12),
          Text(category.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(height: 10),
          if (owned)
            Center(
                child:
                    _pill(_tr('مملوكة بشكل دائم', 'Permanently owned'), _green))
          else if (app.isVip)
            Center(
                child: _pill(
                    _tr('متاحة ضمن العضوية', 'Included with membership'),
                    _gold))
          else ...[
            if (rentalHours > 0) ...[
              Center(
                  child: _pill(
                      _tr('التجربة: $rentalHours ساعة متبقية',
                          'Trial: $rentalHours hours left'),
                      _gold)),
              const SizedBox(height: 10)
            ],
            _StoreButton(
                label:
                    '${category.gemCost} ${_tr('جوهرة • للأبد', 'gems • forever')}',
                icon: Icons.diamond_rounded,
                accent: _cyan,
                compact: true,
                onPressed: disabled ? null : () => _unlockCategory(category)),
            if (!available)
              TextButton.icon(
                  onPressed: disabled ? null : () => _rentCategory(category),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
                  label: Text(
                      _tr('إعلان • تجربة 24 ساعة', 'Ad • 24-hour trial'),
                      style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      minimumSize: const Size(0, 42),
                      visualDensity: VisualDensity.compact)),
          ],
        ]));
  }

  Widget _freeRewards(AppState app, AdService ads, bool disabled) {
    final daily = app.todayReward;
    final dailyAvailable = app.dailyStreakLoaded &&
        !app.claimedToday &&
        app.isOnline &&
        app.user != null;
    final adLabel = ads.watchesLeft == 0
        ? _tr('تم الوصول للحد اليومي', 'Daily limit reached')
        : !ads.canWatchAd
            ? _tr('بعد ${_duration(ads.cooldownRemaining)}',
                'Available in ${_duration(ads.cooldownRemaining)}')
            : _tr('مشاهدة إعلان', 'Watch an ad');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle(
          _tr('مكافآت تستحق العودة', 'A reason to come back'),
          _tr('هدية يومية ومكافآت اختيارية، دون شراء',
              'A daily gift and optional rewards, with no purchase')),
      const SizedBox(height: 12),
      _responsiveWrap(minWidth: 260, children: [
        _panel(
            accent: _green,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _iconTile(Icons.card_giftcard_rounded, _green, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_tr('هدية اليوم', 'Your daily gift'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text(
                              _tr('اليوم ${app.streakDay > 0 ? app.streakDay : 1} من سلسلة العودة',
                                  'Day ${app.streakDay > 0 ? app.streakDay : 1} of your streak'),
                              style:
                                  const TextStyle(color: _muted, fontSize: 11))
                        ]))
                  ]),
                  const SizedBox(height: 14),
                  _rewardSummary(daily['coins'] ?? 0, daily['gems'] ?? 0),
                  const SizedBox(height: 16),
                  _StoreButton(
                      label: app.claimedToday
                          ? _tr('تم الاستلام • عد غداً',
                              'Claimed • Come back tomorrow')
                          : !app.dailyStreakLoaded
                              ? _tr('جارٍ تحميل الهدية…', 'Loading your gift…')
                              : app.user == null
                                  ? _tr('سجّل الدخول لاستلام الهدية',
                                      'Sign in to claim your gift')
                                  : !app.isOnline
                                      ? _tr('تحتاج اتصالاً بالإنترنت',
                                          'Internet connection needed')
                                      : _tr('استلام الهدية', 'Claim gift'),
                      icon: app.claimedToday
                          ? Icons.check_rounded
                          : Icons.redeem_rounded,
                      accent: _green,
                      onPressed: dailyAvailable && !disabled
                          ? _claimDailyReward
                          : null),
                ])),
        _panel(
            accent: _cyan,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _iconTile(Icons.play_circle_outline_rounded, _cyan,
                        size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_tr('مكافأة المشاهدة', 'Watch and earn'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text(
                              _tr('${ads.watchesLeft} من ${AdService.maxDailyWatches} مشاهدات متبقية اليوم',
                                  '${ads.watchesLeft} of ${AdService.maxDailyWatches} watches left today'),
                              style:
                                  const TextStyle(color: _muted, fontSize: 11))
                        ]))
                  ]),
                  const SizedBox(height: 14),
                  _rewardSummary(AdService.rewardCoins, AdService.rewardGems),
                  const SizedBox(height: 16),
                  _StoreButton(
                      label: adLabel,
                      icon: Icons.play_arrow_rounded,
                      accent: _cyan,
                      onPressed: ads.canWatchAd && !disabled ? _watchAd : null),
                ])),
        Builder(
          builder: (context) {
            CrossPromoService? promo;
            try {
              promo = context.watch<CrossPromoService>();
            } catch (_) {}
            if (promo == null) return const SizedBox.shrink();
            final claimed = promo.isRewardClaimed;
            final installed = promo.isMillionaireInstalled;
            final isClaiming = promo.isClaiming;
            final promoService = promo;
            return _panel(
              accent: _gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _iconTile(Icons.diamond_rounded, _gold, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tr('مكافأة تحميل تحدي المليون',
                                'Million Challenge Reward'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            claimed
                                ? _tr('تم استلام الجائزة بنجاح ✓',
                                    'Reward claimed ✓')
                                : installed
                                    ? _tr('اللعبة مثبتة • استلم هديتك الآن!',
                                        'Game installed • Claim now!')
                                    : _tr(
                                        'حمّل اللعبة واحصل على 80 جوهرة فوراً',
                                        'Download & get 80 gems instantly'),
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _rewardSummary(0, CrossPromoService.downloadRewardGems),
                  const SizedBox(height: 16),
                  _StoreButton(
                    label: claimed
                        ? _tr('تم استلام الـ 80 جوهرة ✓', '80 Gems Claimed ✓')
                        : isClaiming
                            ? _tr('جارٍ الاستلام…', 'Claiming…')
                            : installed
                                ? _tr('استلام 80 جوهرة الآن 💎',
                                    'Claim 80 Gems Now 💎')
                                : _tr('تحميل اللعبة (+80 💎)',
                                    'Download Game (+80 💎)'),
                    icon: claimed
                        ? Icons.check_rounded
                        : installed
                            ? Icons.card_giftcard_rounded
                            : Icons.file_download_outlined,
                    accent: _gold,
                    onPressed: disabled || claimed || isClaiming
                        ? null
                        : () async {
                            if (installed) {
                              final res = await promoService
                                  .claimDownloadReward(context);
                              if (res == CrossPromoClaimResult.success &&
                                  context.mounted) {
                                _snack(_tr(
                                    'تمت إضافة 80 جوهرة إلى رصيدك بنجاح! 💎🎉',
                                    '80 gems added to your balance successfully! 💎🎉'));
                              }
                            } else {
                              CrossPromoMillionaireDialog.show(context);
                            }
                          },
                  ),
                ],
              ),
            );
          },
        ),
      ]),
    ]);
  }

  Widget _footer(InAppPurchaseService iap) => Column(children: [
        Divider(color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 8),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              TextButton.icon(
                  onPressed: _busy ||
                          iap.isRestoring ||
                          iap.status == PurchaseFlowStatus.launching ||
                          iap.status == PurchaseFlowStatus.verifying
                      ? null
                      : _restorePurchases,
                  icon: const Icon(Icons.restore_rounded, size: 17),
                  label: Text(_tr('استعادة المشتريات', 'Restore purchases')),
                  style: TextButton.styleFrom(foregroundColor: _muted)),
              TextButton.icon(
                  onPressed: _busy ? null : _manageSubscription,
                  icon: const Icon(Icons.manage_accounts_outlined, size: 17),
                  label: Text(_tr('إدارة الاشتراكات', 'Manage subscriptions')),
                  style: TextButton.styleFrom(foregroundColor: _muted)),
              TextButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen())),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 17),
                  label: Text(_tr('سياسة الخصوصية', 'Privacy policy')),
                  style: TextButton.styleFrom(foregroundColor: _muted)),
            ]),
        const SizedBox(height: 6),
        Text(
            _tr('الدفع عبر Google Play • الأسعار بعملة حساب المتجر',
                'Payments through Google Play • Prices in your store currency'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 6),
        Text(
            _tr('إدارة الاشتراكات تعرض العضوية الشهرية في حساب Google Play الذي اشتريتها به. باقات العملات والجواهر تظهر في سجل الطلبات.',
                'Subscription management shows monthly memberships in the Google Play account used to buy them. Currency bundles appear in order history.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.5)),
        const SizedBox(height: 6),
        Text(
            _tr('تستعيد الاستعادة الاشتراكات والمحتوى الدائم. العملات المستهلكة لا تُعاد إضافتها.',
                'Restoration checks subscriptions and permanent content. Spent currency is not granted again.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _muted.withValues(alpha: 0.75),
                fontSize: 10,
                height: 1.5)),
      ]);

  Widget _sectionTitle(String title, String subtitle) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5)),
      ]);

  Widget _rewardSummary(int coins, int gems, {bool centered = false}) => Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            if (coins > 0)
              _currencyReward(coins, Icons.monetization_on_rounded, _gold,
                  _tr('نقود', 'coins')),
            if (gems > 0)
              _currencyReward(
                  gems, Icons.diamond_rounded, _cyan, _tr('جوهرة', 'gems'))
          ]);

  Widget _currencyReward(
          int amount, IconData icon, Color color, String label) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.16))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(_number(amount),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: _muted, fontSize: 11))
          ]));

  Widget _receiptRow(String label, String value) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: _muted, fontSize: 13))),
        const SizedBox(width: 14),
        Flexible(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)))
      ]);

  Widget _benefit(IconData icon, String text) => Row(children: [
        Icon(icon, color: _green, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.6)))
      ]);

  Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.4)));

  Widget _iconTile(IconData icon, Color accent, {double size = 42}) =>
      Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accent, size: size * 0.52));

  Widget _panel(
          {required Widget child,
          Color? accent,
          List<Color>? gradient,
          double padding = 20}) =>
      Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
              color: gradient == null ? _surface : null,
              gradient: gradient == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: gradient),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: (accent ?? Colors.white)
                      .withValues(alpha: accent == null ? 0.07 : 0.2))),
          child: child);

  Widget _responsiveWrap(
          {required List<Widget> children, required double minWidth}) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + 12) / (minWidth + 12)).floor().clamp(1, 5);
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });

  String _number(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _duration(Duration duration) => _tr(
      '${(duration.inSeconds / 60).ceil()} دقيقة',
      '${(duration.inSeconds / 60).ceil()} min');
  String _expiry(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton(
      {required this.label,
      required this.icon,
      required this.accent,
      required this.onPressed,
      this.loading = false,
      this.compact = false});
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: _background,
          disabledBackgroundColor: accent.withValues(alpha: 0.07),
          disabledForegroundColor: _muted,
          minimumSize: Size(double.infinity, compact ? 44 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: accent, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: compact ? 16 : 18),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w800)))
            ]));
}

class _ProductArt extends StatelessWidget {
  const _ProductArt(
      {required this.icon,
      required this.accent,
      required this.size,
      this.bundle = false});
  final IconData icon;
  final Color accent;
  final double size;
  final bool bundle;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0)
                ]))),
        Transform.rotate(
            angle: -0.14,
            child: Container(
                width: size * 0.64,
                height: size * 0.64,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.16),
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.27),
                          accent.withValues(alpha: 0.06)
                        ]),
                    border: Border.all(color: accent.withValues(alpha: 0.42)),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.1), blurRadius: 22)
                    ]))),
        Icon(icon, size: size * 0.46, color: accent),
        Positioned(
            top: size * 0.08,
            right: size * 0.08,
            child: Icon(Icons.auto_awesome_rounded,
                size: size * 0.16, color: accent.withValues(alpha: 0.75))),
        if (bundle) ...[
          Positioned(
              bottom: size * 0.08,
              right: size * 0.03,
              child:
                  Icon(Icons.diamond_rounded, size: size * 0.29, color: _cyan)),
          Positioned(
              bottom: size * 0.13,
              left: size * 0.04,
              child: Icon(Icons.monetization_on_rounded,
                  size: size * 0.31, color: _gold)),
        ],
      ]));
}
