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
import '../../widgets/game_store_widgets.dart';
import '../character/character_select_screen.dart';
import 'resource_shop_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../../widgets/adaptive_asset_image.dart';

const _background = storeNavy;
const _surface = Color(0xFF26105C);
const _muted = Color(0xFFCCBDE8);
const _purple = Color(0xFFE3ADFF);
const _gold = storeGold;
const _cyan = Color(0xFF74EEFF);
const _green = Color(0xFF64F119);
const _red = Color(0xFFFF5252);

// These supplied banners include price artwork; cover that area with live billing
// UI so a price baked into an image can never become the checkout price label.
const _offerArtwork = {
  'pack_starter': (
    asset: 'assets/store/offer_starter.webp',
    aspectRatio: 2640 / 604,
    price: Rect.fromLTRB(.610, .650, .844, .925),
  ),
  'pack_value': (
    asset: 'assets/store/offer_explorer.webp',
    aspectRatio: 2572 / 684,
    price: Rect.fromLTRB(.589, .707, .857, .935),
  ),
  'pack_champion': (
    asset: 'assets/store/offer_champion.webp',
    aspectRatio: 2544 / 656,
    price: Rect.fromLTRB(.598, .719, .817, .952),
  ),
};

const _currencyArtwork = {
  'coins_5000': (
    asset: 'assets/store/coins_5000.webp',
    art: Rect.fromLTRB(.054, .047, .960, .758),
  ),
  'coins_25000': (
    asset: 'assets/store/coins_25000.webp',
    art: Rect.fromLTRB(.048, .033, .955, .765),
  ),
  'coins_100000': (
    asset: 'assets/store/coins_100000.webp',
    art: Rect.fromLTRB(.034, .028, .960, .765),
  ),
  'gems_80': (
    asset: 'assets/store/gems_80.webp',
    art: Rect.fromLTRB(.028, .019, .972, .785),
  ),
  'gems_500': (
    asset: 'assets/store/gems_500.webp',
    art: Rect.fromLTRB(.036, .024, .966, .785),
  ),
  'gems_1200': (
    asset: 'assets/store/gems_1200.webp',
    art: Rect.fromLTRB(.037, .026, .967, .787),
  ),
};

enum _StoreSection { featured, gems, resources, coins, membership, collection }

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
  final PageController _offerController = PageController();
  int _offerIndex = 0;
  InAppPurchaseService? _purchaseService;
  Timer? _refreshTimer;
  Timer? _offerAutoPlayTimer;
  bool _busy = false;
  bool _onlyUnowned = false;

  bool get _arabic => context.read<AppSettings>().isArabic;
  String _tr(String ar, String en) => _arabic ? ar : en;

  void _startOfferAutoPlay() {
    _offerAutoPlayTimer?.cancel();
    _offerAutoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_section != _StoreSection.featured) return;
      if (!_offerController.hasClients) return;
      if (_busy || ModalRoute.of(context)?.isCurrent != true) return;
      if (MediaQuery.of(context).disableAnimations) return;
      if (_offerController.position.isScrollingNotifier.value) return;
      final offersCount = StoreCatalog.products
          .where((p) => p.kind == StoreProductKind.bundle)
          .length;
      if (offersCount <= 1) return;
      final next = (_offerIndex + 1) % offersCount;
      _offerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _section = switch (widget.initialKind) {
      StoreProductKind.gems => _StoreSection.gems,
      StoreProductKind.resource => _StoreSection.resources,
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
    if (_section == _StoreSection.featured) {
      _startOfferAutoPlay();
    }
  }

  @override
  void dispose() {
    _purchaseService?.removeDeliveryListener(_onDelivered);
    _refreshTimer?.cancel();
    _offerAutoPlayTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _offerController.dispose();
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
      app.loadEconomy(),
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
    await Future.wait(
        [app.loadCurrency(), app.loadCategoryState(), app.loadEconomy()]);
    if (!mounted) return;
    _snack(_tr('تم تسليم مشترياتك وتحديث حسابك.',
        'Your purchase was delivered and your account updated.'));
    final product = StoreCatalog.byId(id);
    if (product != null &&
        product.kind != StoreProductKind.subscription &&
        (product.coins > 0 || product.gems > 0)) {
      showCurrencyRewardOverlay(context,
          coins: product.coins, gems: product.gems);
    }
  }

  void _selectSection(_StoreSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(context.read<AppSettings>().playHaptic());
    if (section == _StoreSection.featured) {
      _startOfferAutoPlay();
    } else {
      _offerAutoPlayTimer?.cancel();
    }
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
      'keys_1' => '1 Key',
      'keys_10' => '10 Keys',
      'hearts_1' => '1 Extra Heart',
      'hearts_10' => '10 Extra Hearts',
      'tickets_1' => '1 Category Ticket',
      'tickets_10' => '10 Category Tickets',
      'resources_3_each' => 'Play Pack',
      'resources_10_each' => 'Mega Play Pack',
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
          StoreProductKind.resource =>
            'Additional play resources saved to your account.',
          StoreProductKind.subscription =>
            'Premium categories and no forced ads while your membership is active.',
          StoreProductKind.categoryPass =>
            'Own every current premium category with one purchase.',
        };

  Color _accent(StoreProduct product) => switch (product.kind) {
        StoreProductKind.coins => _gold,
        StoreProductKind.gems => _cyan,
        StoreProductKind.bundle => _purple,
        StoreProductKind.resource => _purple,
        StoreProductKind.subscription => _gold,
        StoreProductKind.categoryPass => _green,
      };

  IconData _icon(StoreProduct product) => switch (product.kind) {
        StoreProductKind.coins => Icons.monetization_on_rounded,
        StoreProductKind.gems => Icons.diamond_rounded,
        StoreProductKind.bundle => Icons.inventory_2_rounded,
        StoreProductKind.resource => Icons.key_rounded,
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
          if (product.coins > 0 ||
              product.gems > 0 ||
              product.keys > 0 ||
              product.tickets > 0 ||
              product.hearts > 0)
            _rewardSummary(product.coins, product.gems,
                keys: product.keys,
                tickets: product.tickets,
                hearts: product.hearts),
          if (product.kind == StoreProductKind.categoryPass)
            _benefit(
                Icons.lock_open_rounded,
                _tr('فتح دائم لجميع الفئات المميزة الحالية',
                    'Permanent access to all current premium categories')),
          if (product.kind == StoreProductKind.subscription) ...[
            _benefit(
                Icons.card_giftcard_rounded,
                _tr('حزمة مكافآت الانضمام: 100 جوهرة + 1000 قطعة + 3 مفاتيح وتذاكر وقلوب',
                    'Welcome pack: 100 gems + 1,000 coins + 3 keys, tickets & hearts')),
            _benefit(
                Icons.category_rounded,
                _tr('جميع الفئات المميزة طوال صلاحية الاشتراك',
                    'All premium categories while your membership is active')),
            _benefit(
                Icons.block_rounded,
                _tr('بدون إعلانات إجبارية؛ إعلانات المكافآت اختيارية',
                    'No forced ads; reward ads remain optional')),
            _benefit(
                Icons.military_tech_rounded,
                _tr('شارة العضوية المميزة VIP وهيبة الأبطال',
                    'Prestige VIP badge and club status')),
          ],
          if (product.kind == StoreProductKind.resource) ...[
            _benefit(
                Icons.check_circle_outline_rounded,
                _tr('إضافة رصيد الموارد فورياً إلى حسابك',
                    'Resources added instantly to your balance')),
            _benefit(
                Icons.cloud_done_rounded,
                _tr('رصيد دائم محفوظ بحسابك ومتاح دائماً',
                    'Permanent balance saved to your account and ready anytime')),
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
                  Center(child: _iconTile(icon, accent, size: 50)),
                  const SizedBox(height: 12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22)),
                  const SizedBox(height: 10),
                  Text(subtitle,
                      textAlign: TextAlign.center,
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
                  Center(
                    child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: Text(_tr('إلغاء', 'Cancel'),
                            style: const TextStyle(color: _muted))),
                  ),
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

  Future<void> _buyResourceOffer(
      String offerId, Map<String, dynamic> offer, String currency) async {
    if (_busy || context.read<InAppPurchaseService>().isPurchasing) return;
    final app = context.read<AppState>();
    if (!app.economyLoaded || app.economyError != null) {
      _snack(
          app.economyError ??
              _tr('خدمة الأرصدة غير متاحة حالياً.',
                  'Resources service unavailable.'),
          error: true);
      return;
    }
    final price = (offer[currency] as num?)?.toInt() ?? 0;
    final isCoins = currency == 'coins';
    final userBalance = isCoins ? app.coins : app.gems;
    final currencyName =
        isCoins ? _tr('قطعة نقدية', 'coins') : _tr('جوهرة', 'gems');
    if (userBalance < price) {
      _snack(
          _tr('تحتاج ${_number(price - userBalance)} $currencyName إضافية.',
              'You need ${_number(price - userBalance)} more $currencyName.'),
          error: true);
      return;
    }
    final grants = offer['grants'] is Map
        ? Map<String, dynamic>.from(offer['grants'] as Map)
        : <String, dynamic>{'${offer['resource']}': offer['amount']};
    final grantSummary = _resourceGrantLabel(grants);

    setState(() => _busy = true);
    try {
      final confirmed = await _confirmSheet(
        title: _tr('تأكيد الشراء', 'Confirm Purchase'),
        subtitle: _tr(
            'شراء $grantSummary مقابل ${_number(price)} $currencyName.',
            'Purchase $grantSummary for ${_number(price)} $currencyName.'),
        icon: isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded,
        accent: isCoins ? _gold : _cyan,
        body: [
          _receiptRow(
              _tr('المبلغ المطلوب', 'Cost'), '${_number(price)} $currencyName'),
          const SizedBox(height: 12),
          _receiptRow(
              _tr('المحتوى المستلم', 'Resources received'), grantSummary),
        ],
        button: _tr('تأكيد الشراء', 'Confirm Purchase'),
      );
      if (!confirmed || !mounted) return;
      await app.economyAction({
        'action': 'buy',
        'offerId': offerId,
        'currency': currency,
      });
      if (!mounted) return;
      _snack(_tr('تمت إضافة الرصيد إلى حسابك بنجاح.',
          'Resources added to your account.'));
      await app.loadEconomy();
      await app.loadCurrency();
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString(), error: true);
      final app = context.read<AppState>();
      await app.loadCurrency();
      await app.loadEconomy();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _categoryOwned(GameCategory category, AppState app) =>
      app.hasPermanentCategoryPass ||
      app.economyWallet.owned.any((name) =>
          GameCategory.normalize(name) ==
          GameCategory.normalize(category.name)) ||
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
              ? _tr('تجربة فئة ${category.name} جاهزة لمباراة واحدة.',
                  '${category.name} is ready for one match.')
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

  Future<void> _categoryAction(
      GameCategory category, Map<String, dynamic> data, String description,
      {String successMessage = 'تم تفعيل التصنيف.'}) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Center(
                    child: Text(category.name, textAlign: TextAlign.center)),
                content: Text(description, textAlign: TextAlign.center),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد')),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context
          .read<AppState>()
          .economyAction({...data, 'category': category.name});
      if (mounted) _snack(successMessage);
    } catch (error) {
      if (mounted) _snack(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rentalOptions(GameCategory category) async {
    final app = context.read<AppState>();
    await app.loadEconomy();
    if (!mounted) return;
    if (!app.economyLoaded || app.economyError != null) {
      _snack(
          app.economyError ??
              _tr('تعذر تحميل عروض الاستئجار. حاول مجدداً.',
                  'Could not load rental offers. Please try again.'),
          error: true);
      return;
    }
    final offers = app.economyWallet.rentalPrices;
    String durationLabel(String duration) {
      final days = (offers[duration] as Map?)?['days'] ?? 7;
      return switch (duration) {
        'day' => _tr('يوم واحد', '1 day'),
        'week' => _tr('أسبوع (7 أيام)', '1 week (7 days)'),
        'month' => _tr('شهر (30 يوماً)', '1 month (30 days)'),
        _ => _tr('$days يوم', '$days days'),
      };
    }

    final remainingHours = app.getCategoryRemainingRentalHours(category.name);

    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB8000000),
      elevation: 0,
      builder: (ctx) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 38),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.75),
                        width: 1.8,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40FFD54F),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Color(0xE6000000),
                          blurRadius: 32,
                          spreadRadius: 8,
                          offset: Offset(0, 12),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF26105C),
                          Color(0xFF180838),
                          Color(0xFF0F0424),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 46, 18, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameStoreText(
                          _tr('استئجار التصنيف', 'Rent Category'),
                          size: 23,
                          color: const Color(0xFFFFD54F),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: _cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _cyan.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.category_rounded,
                                  color: _cyan, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                category.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            'اختر المدة المناسبة للاستمتاع بالتصنيف في كافة التحديات والمباريات:',
                            'Select a duration to enjoy this category in all match modes:',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                        if (remainingHours > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _gold.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: _gold, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _tr(
                                      'الاستئجار الحالي: $remainingHours ساعة متبقية • الاستئجار الجديد يمدد رصيدك',
                                      'Current rental: $remainingHours hours left • Extends existing duration',
                                    ),
                                    style: const TextStyle(
                                        color: _gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (app.economyWallet.rentalVouchers > 0) ...[
                          const SizedBox(height: 14),
                          _buildRentalVoucherPill(
                            ctx: ctx,
                            durationText:
                                _tr('أسبوع (7 أيام)', '1 week (7 days)'),
                            titleText: _tr('قسيمة استئجار', 'Rental voucher'),
                          ),
                        ],
                        const SizedBox(height: 14),
                        for (final entry in offers.entries)
                          _buildDurationRentalCard(
                            ctx: ctx,
                            durationKey: entry.key,
                            durationText: durationLabel(entry.key),
                            offerMap: entry.value as Map,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            '✓ يفتح التصنيف فوراً لجميع المباريات والمنافسات مع إمكانية التمديد في أي وقت.',
                            '✓ Unlocks immediately for all challenges with the ability to extend anytime.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted.withValues(alpha: 0.8),
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF5B1FAF),
                            Color(0xFF26105C),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFD54F),
                          width: 2.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FFD54F),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: ClipOval(
                        child: adaptiveAssetImage(
                          category.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.timer_rounded,
                            color: Color(0xFFFFD54F),
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (choice != null && mounted) {
      final duration = durationLabel(choice['duration'] as String);
      final price = choice['currency'] == 'voucher'
          ? _tr('قسيمة أسبوعية واحدة', '1 weekly rental voucher')
          : '${(offers[choice['duration']] as Map)[choice['currency']]} ${choice['currency'] == 'coins' ? _tr('قطعة', 'coins') : _tr('جوهرة', 'gems')}';
      await _categoryAction(
          category,
          choice,
          _tr('استئجار تصنيف «${category.name}» لمدة $duration مقابل $price.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.',
              'Rent ${category.name} for $duration for $price.\nThe duration extends your current rental if it is still active.'),
          successMessage: _tr(
              'تم استئجار تصنيف «${category.name}» لمدة $duration.',
              '${category.name} is rented for $duration.'));
    }
  }

  Widget _buildDurationRentalCard({
    required BuildContext ctx,
    required String durationKey,
    required String durationText,
    required Map offerMap,
  }) {
    final hasCoins = offerMap.containsKey('coins');
    final hasGems = offerMap.containsKey('gems');
    final isWeek = durationKey == 'week';
    final isMonth = durationKey == 'month';

    final badgeText = isWeek
        ? _tr('الأكثر طلباً ⭐', 'Popular ⭐')
        : isMonth
            ? _tr('أفضل توفير 💎', 'Best Value 💎')
            : null;
    final badgeColor = isWeek ? _gold : _cyan;

    final durationIcon = isMonth
        ? Icons.workspace_premium_rounded
        : isWeek
            ? Icons.bolt_rounded
            : Icons.today_rounded;
    final durationIconColor = isMonth
        ? _purple
        : isWeek
            ? _gold
            : _cyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: (isWeek
                  ? _gold
                  : isMonth
                      ? _purple
                      : Colors.white)
              .withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(durationIcon, color: durationIconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                durationText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: badgeColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasCoins)
                Expanded(
                  child: _buildRentalOptionPill(
                    ctx: ctx,
                    durationKey: durationKey,
                    currencyKey: 'coins',
                    durationText: durationText,
                    priceAmount: offerMap['coins'],
                    priceCurrencyText: _tr('قطعة', 'coins'),
                    isCoins: true,
                  ),
                ),
              if (hasCoins && hasGems) const SizedBox(width: 8),
              if (hasGems)
                Expanded(
                  child: _buildRentalOptionPill(
                    ctx: ctx,
                    durationKey: durationKey,
                    currencyKey: 'gems',
                    durationText: durationText,
                    priceAmount: offerMap['gems'],
                    priceCurrencyText: _tr('جوهرة', 'gems'),
                    isCoins: false,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRentalOptionPill({
    required BuildContext ctx,
    required String durationKey,
    required String currencyKey,
    required String durationText,
    required dynamic priceAmount,
    required String priceCurrencyText,
    required bool isCoins,
  }) {
    final semanticsText = '$durationText • $priceAmount $priceCurrencyText';
    final accentColor = isCoins ? _gold : _cyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(ctx, {
          'action': 'rent',
          'duration': durationKey,
          'currency': currencyKey,
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.16),
                accentColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCoins
                          ? Icons.monetization_on_rounded
                          : Icons.diamond_rounded,
                      color: accentColor,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$priceAmount',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      priceCurrencyText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    semanticsText,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRentalVoucherPill({
    required BuildContext ctx,
    required String durationText,
    required String titleText,
  }) {
    final semanticsText = '$titleText • $durationText';
    const greenAccent = Color(0xFF00E676);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pop(ctx, {
          'action': 'rent',
          'duration': 'week',
          'currency': 'voucher',
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: greenAccent.withValues(alpha: 0.6),
              width: 1.5,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B5E3C),
                Color(0xFF0E3824),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3300E676),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: greenAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tr('قسيمة استئجار مجانية جاهزة! 🎟️',
                              'Free Rental Voucher Ready! 🎟️'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tr('استأجر لمدة أسبوع كامل مجاناً دون إنفاق أي رصيد',
                              'Rent for a full week for free without spending currency'),
                          style: TextStyle(
                            color: greenAccent.withValues(alpha: 0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: greenAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _tr('استخدام', 'Use'),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    semanticsText,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _openCharacters([int? initialIndex]) async {
    if (_busy) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => CharacterSelectScreen(initialIndex: initialIndex)));
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                Color(0xFF100A32),
                Color(0xFF171044),
                Color(0xFF0C0829)
              ])),
          child: Column(children: [
            _tabs(),
            Expanded(
                child: SafeArea(
                    top: false,
                    child: RefreshIndicator(
                      color: _cyan,
                      backgroundColor: _surface,
                      onRefresh: _refresh,
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 28),
                        children: [
                          Center(
                              child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showStatus(iap)) _purchaseStatus(iap),
                                  if (_section == _StoreSection.featured) ...[
                                    _sectionTitle(
                                        _tr('عروض المتجر', 'SPECIAL OFFERS'),
                                        _tr('باقات لمغامرتك القادمة',
                                            'GEAR UP FOR YOUR NEXT ADVENTURE')),
                                    const SizedBox(height: 12),
                                    _featured(iap, app, disabled),
                                    const SizedBox(height: 24),
                                    _quickRewards(app, ads, disabled),
                                    const SizedBox(height: 24),
                                    _sectionTitle(_tr('النقود', 'COINS'), '',
                                        action: Tooltip(
                                            message: _tr('النقود', 'Coins'),
                                            child: TextButton(
                                                onPressed: () => _selectSection(
                                                    _StoreSection.coins),
                                                child: Text(
                                                    _tr('عرض الكل', 'View all'),
                                                    style: const TextStyle(
                                                        color: _purple))))),
                                    const SizedBox(height: 14),
                                    _productGrid(
                                        StoreCatalog.products
                                            .where((p) =>
                                                p.kind ==
                                                StoreProductKind.coins)
                                            .toList(),
                                        iap,
                                        app,
                                        disabled),
                                    const SizedBox(height: 24),
                                    _sectionTitle(_tr('الجواهر', 'GEMS'), ''),
                                    const SizedBox(height: 14),
                                    _productGrid(
                                        StoreCatalog.products
                                            .where((p) =>
                                                p.kind == StoreProductKind.gems)
                                            .toList(),
                                        iap,
                                        app,
                                        disabled),
                                    const SizedBox(height: 24),
                                    _sectionTitle(
                                        _tr('أرصدة اللعب', 'PLAY RESOURCES'),
                                        _tr('المفاتيح والقلوب وتذاكر التصنيفات',
                                            'Keys, hearts and challenge tickets'),
                                        action: Tooltip(
                                            message: _tr('أرصدة اللعب',
                                                'Play resources'),
                                            child: TextButton(
                                                onPressed: () => _selectSection(
                                                    _StoreSection.resources),
                                                child: Text(
                                                    _tr('عرض الكل', 'View all'),
                                                    style: const TextStyle(
                                                        color: _purple))))),
                                    const SizedBox(height: 14),
                                    _featuredResources(iap, app, disabled),
                                    const SizedBox(height: 24),
                                    _sectionTitle(
                                        _tr('عبّر عن نفسك', 'EXPRESS YOURSELF'),
                                        ''),
                                    const SizedBox(height: 14),
                                    _characterShowcase(app, disabled),
                                  ],
                                  if (_section == _StoreSection.gems) ...[
                                    _sectionTitle(
                                        _tr('رصيدك من الجواهر، خيارات أكثر',
                                            'More gems. More possibilities.'),
                                        _tr('افتح الفئات واجمع شخصياتك المفضلة',
                                            'Unlock categories and collect your favorites')),
                                    const SizedBox(height: 16),
                                    _productGrid(
                                        StoreCatalog.products
                                            .where((p) =>
                                                p.kind == StoreProductKind.gems)
                                            .toList(),
                                        iap,
                                        app,
                                        disabled),
                                    const SizedBox(height: 24),
                                    _freeRewards(app, ads, disabled),
                                    const SizedBox(height: 24),
                                    _resourcesTeaser(app),
                                  ],
                                  if (_section == _StoreSection.resources) ...[
                                    _sectionTitle(
                                        _tr('أرصدة اللعب والتحديات',
                                            'PLAY RESOURCES'),
                                        _tr('مفاتيح المباريات وقلوب المراحل وتذاكر التصنيفات',
                                            'Keys for matches, hearts for stages, tickets for categories')),
                                    const SizedBox(height: 16),
                                    _resourceBalancesHUD(app),
                                    const SizedBox(height: 24),
                                    if (app
                                        .economyWallet.offers.isNotEmpty) ...[
                                      _sectionTitle(
                                          _tr('شحن بالنقود أو الجواهر',
                                              'EXCHANGE CURRENCY'),
                                          _tr('استبدل نقودك أو جواهرك بأرصدة اللعب',
                                              'Use your in-game coins or gems')),
                                      const SizedBox(height: 14),
                                      _inGameExchangeGrid(app, disabled),
                                      const SizedBox(height: 24),
                                    ],
                                    _sectionTitle(
                                        _tr('باقات المتجر', 'STORE PACKS'),
                                        _tr('شراء مباشر وآمن عبر Google Play',
                                            'Direct, secure payment via Google Play')),
                                    const SizedBox(height: 14),
                                    _resourceGrid(
                                        StoreCatalog.products
                                            .where((p) =>
                                                p.kind ==
                                                StoreProductKind.resource)
                                            .toList(),
                                        iap,
                                        app,
                                        disabled),
                                    const SizedBox(height: 24),
                                    _loyaltyAndMilestonesPanel(app),
                                  ],
                                  if (_section == _StoreSection.coins) ...[
                                    _sectionTitle(
                                        _tr('نقود لتوسيع مجموعتك',
                                            'Coins for your collection'),
                                        _tr('شراء مباشر أو تحويل جواهرك',
                                            'Buy directly or exchange your gems')),
                                    const SizedBox(height: 16),
                                    _productGrid(
                                        StoreCatalog.products
                                            .where((p) =>
                                                p.kind ==
                                                StoreProductKind.coins)
                                            .toList(),
                                        iap,
                                        app,
                                        disabled),
                                    const SizedBox(height: 24),
                                    _sectionTitle(
                                        _tr('تحويل الجواهر إلى نقود',
                                            'Exchange gems for coins'),
                                        _tr('استخدم جواهرك داخل اللعبة',
                                            'Use your in-game gems')),
                                    const SizedBox(height: 14),
                                    _exchanges(app, disabled),
                                  ],
                                  if (_section == _StoreSection.membership)
                                    _membership(iap, app, disabled),
                                  if (_section == _StoreSection.collection)
                                    _collection(iap, app, disabled),
                                  const SizedBox(height: 28),
                                  _footer(iap),
                                ]),
                          ))
                        ],
                      ),
                    ))),
          ]),
        ),
      ),
    );
  }

  Widget _tabs() {
    final tabs = <(_StoreSection, String, int)>[
      (_StoreSection.featured, _tr('المميزة', 'Featured'), 0),
      (_StoreSection.resources, _tr('أرصدة اللعب', 'Resources'), 2),
      (_StoreSection.gems, _tr('الجواهر', 'Gems'), 1),
      (_StoreSection.membership, _tr('العضوية', 'Membership'), 3),
      (
        _StoreSection.collection,
        _tr('الفئات والشخصيات', 'Categories & characters'),
        4
      ),
    ];
    final compact = MediaQuery.sizeOf(context).height < 500;
    final height = compact ? 80.0 : 92.0;
    return SizedBox(
      key: const ValueKey('store-top-navigation'),
      width: double.infinity,
      child: Stack(children: [
        const Positioned.fill(child: GameStoreTopBarArtwork()),
        SafeArea(
            bottom: false,
            child: SizedBox(
                height: height,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: compact ? 58 : 66,
                          child: Center(
                              child: IconButton(
                            key: const ValueKey('store-back-button'),
                            tooltip: _tr('العودة', 'Back'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            padding: const EdgeInsets.all(4),
                            icon: SizedBox(
                                width: height * .54,
                                height: height * .64,
                                child: GameStoreNavigationBack(
                                    pointRight: _arabic)),
                          ))),
                      for (final tab in tabs)
                        Expanded(child: _navigationTab(tab, height)),
                    ]))),
      ]),
    );
  }

  Widget _navigationTab((_StoreSection, String, int) tab, double height) {
    final selected = tab.$1 == _section ||
        (tab.$1 == _StoreSection.featured && _section == _StoreSection.coins);
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: tab.$2,
        child: InkWell(
          onTap: () => _selectSection(tab.$1),
          child: Stack(children: [
            if (selected)
              const Positioned.fill(
                  top: 3, bottom: 3, child: GameStoreNavigationSelection()),
            if (!selected)
              PositionedDirectional(
                  end: 0,
                  top: height * .1,
                  bottom: height * .1,
                  child: Container(width: 1, color: const Color(0x4478DDF8))),
            Positioned.fill(child: LayoutBuilder(builder: (context, area) {
              final iconSize = (area.maxWidth - 12).clamp(0.0, height * .56);
              final caption = area.maxWidth < 110
                  ? switch (tab.$1) {
                      _StoreSection.resources => _tr('الأرصدة', 'Resources'),
                      _StoreSection.collection =>
                        _tr('المقتنيات', 'Collection'),
                      _ => tab.$2,
                    }
                  : tab.$2;
              return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            height: height * .58,
                            child: Center(
                                child: GameStoreNavIcon(
                                    index: tab.$3, size: iconSize))),
                        SizedBox(
                            height: height * .21,
                            child: selected
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: GameStoreText(caption, size: 16))
                                : null),
                      ]));
            })),
          ]),
        ),
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
    final offers = StoreCatalog.products
        .where((p) => p.kind == StoreProductKind.bundle)
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      // Keep the complete supplied artwork visible, including characters above
      // its frame, and give every carousel page the same height.
      final artworkHeight = constraints.maxWidth / (2572 / 684);
      return Column(children: [
        SizedBox(
          height: artworkHeight + 40,
          child: PageView.builder(
            controller: _offerController,
            itemCount: offers.length,
            onPageChanged: (index) {
              setState(() => _offerIndex = index);
              _startOfferAutoPlay();
            },
            itemBuilder: (context, index) {
              final product = offers[index];
              final artwork = _offerArtwork[product.id]!;
              final price = iap.getProductDetails(product.id)?.price;
              final canBuy = !disabled &&
                  !iap.isLoading &&
                  app.isCommerceReady &&
                  iap.isAvailable &&
                  price != null &&
                  price.isNotEmpty &&
                  !_owned(product, app);
              return Column(children: [
                SizedBox(
                  height: artworkHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AspectRatio(
                      aspectRatio: artwork.aspectRatio,
                      child: LayoutBuilder(builder: (context, banner) {
                        final priceRect = Rect.fromLTRB(
                          banner.maxWidth * artwork.price.left,
                          banner.maxHeight * artwork.price.top,
                          banner.maxWidth * artwork.price.right,
                          banner.maxHeight * artwork.price.bottom,
                        );
                        return Semantics(
                          label: _title(product),
                          child: Stack(children: [
                            Positioned.fill(
                                child: InkWell(
                                    onTap: canBuy
                                        ? () => _buyProduct(product)
                                        : null,
                                    child: adaptiveAssetImage(artwork.asset,
                                        key: ValueKey(
                                            'store-offer-${product.id}'),
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true))),
                            Positioned.fromRect(
                                rect: priceRect,
                                child: _purchaseButton(product, iap, disabled,
                                    owned: _owned(product, app),
                                    compact: true,
                                    glossy: true)),
                            Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                    child: IconButton(
                                        tooltip:
                                            _tr('العرض التالي', 'Next offer'),
                                        onPressed: () {
                                          _offerController.animateToPage(
                                              (index + 1) % offers.length,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeOutCubic);
                                          _startOfferAutoPlay();
                                        },
                                        // The arrow is already part of the supplied image.
                                        icon: const SizedBox(
                                            width: 24, height: 24)))),
                          ]),
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(children: [
                        Expanded(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child:
                                    GameStoreText(_title(product), size: 16))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Row(children: [
                                  const Icon(Icons.monetization_on_rounded,
                                      color: _gold, size: 17),
                                  GameStoreText(
                                      ' ${_number(product.coins)}  +  ',
                                      size: 15),
                                  const Icon(Icons.diamond_rounded,
                                      color: _cyan, size: 17),
                                  GameStoreText(' ${_number(product.gems)}',
                                      size: 15),
                                ]))),
                      ]),
                    )),
              ]);
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < offers.length; i++)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                    label: _tr('العرض ${i + 1}', 'Offer ${i + 1}'),
                    selected: i == _offerIndex,
                    button: true,
                    child: InkResponse(
                        onTap: () {
                          _offerController.animateToPage(i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic);
                          _startOfferAutoPlay();
                        },
                        child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _offerIndex
                                    ? Colors.white
                                    : const Color(0xFF78718A)))))),
        ]),
      ]);
    });
  }

  Widget _productGrid(List<StoreProduct> products, InAppPurchaseService iap,
          AppState app, bool disabled) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 2
            : 3;
        final cellWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final viewport = MediaQuery.sizeOf(context);
        // Every card uses the same frame and footer, including on short screens.
        final maxWidth = viewport.height < 500
            ? ((viewport.height - 110) * .71).clamp(110.0, 240.0)
            : 320.0;
        final width = cellWidth.clamp(0.0, maxWidth);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 16,
          children: [
            for (final product in products)
              SizedBox(
                  width: width,
                  child: _productCard(product, iap, app, disabled)),
          ],
        );
      });

  Widget _productCard(StoreProduct product, InAppPurchaseService iap,
      AppState app, bool disabled) {
    final artwork = _currencyArtwork[product.id]!;
    final price = iap.getProductDetails(product.id)?.price;
    final owned = _owned(product, app);
    final canBuy = !disabled &&
        !iap.isLoading &&
        app.isCommerceReady &&
        iap.isAvailable &&
        price != null &&
        price.isNotEmpty &&
        !owned;
    final amount =
        product.kind == StoreProductKind.gems ? product.gems : product.coins;
    final unit = product.kind == StoreProductKind.gems
        ? _tr('جوهرة', 'gems')
        : _tr('نقود', 'coins');
    return Semantics(
      label:
          '${_title(product)}, ${_number(amount)} $unit, ${_subtitle(product)}',
      child: GameStoreCurrencyCard(
        key: ValueKey('store-currency-card-${product.id}'),
        asset: artwork.asset,
        art: artwork.art,
        imageKey: ValueKey('store-product-${product.id}'),
        priceKey: ValueKey('store-price-${product.id}'),
        onPressed: canBuy ? () => _buyProduct(product) : null,
        priceButton: _purchaseButton(product, iap, disabled,
            owned: owned, compact: true, glossy: true),
      ),
    );
  }

  Widget _quickRewards(AppState app, AdService ads, bool disabled) {
    final dailyAvailable = app.dailyStreakLoaded &&
        !app.claimedToday &&
        app.isOnline &&
        app.user != null;
    final dailyLabel = app.claimedToday
        ? _tr('تم', 'CLAIMED')
        : !app.dailyStreakLoaded
            ? _tr('تحميل…', 'LOADING…')
            : app.user == null
                ? _tr('دخول', 'SIGN IN')
                : !app.isOnline
                    ? _tr('اتصل', 'OFFLINE')
                    : _tr('مجاناً', 'FREE');
    final dailyHint = app.claimedToday
        ? _tr('تم استلام هدية اليوم', 'Today’s gift claimed')
        : !app.dailyStreakLoaded
            ? _tr('جارٍ تحميل الهدية اليومية', 'Loading your daily gift')
            : app.user == null
                ? _tr(
                    'سجّل الدخول لاستلام الهدية', 'Sign in to claim your gift')
                : !app.isOnline
                    ? _tr(
                        'تحتاج اتصالاً بالإنترنت', 'Internet connection needed')
                    : _tr('استلام الهدية اليومية', 'Claim your daily gift');
    final watchLabel = ads.watchesLeft == 0
        ? _tr('غداً', 'TOMORROW')
        : !ads.canWatchAd
            ? _duration(ads.cooldownRemaining)
            : '+${AdService.rewardCoins}';
    final watchHint = ads.watchesLeft == 0
        ? _tr('تم الوصول للحد اليومي', 'Daily limit reached')
        : !ads.canWatchAd
            ? _tr('بعد ${_duration(ads.cooldownRemaining)}',
                'Available in ${_duration(ads.cooldownRemaining)}')
            : _tr('مشاهدة إعلان للحصول على المكافأة',
                'Watch an ad to earn your reward');
    return Column(children: [
      _sectionTitle(_tr('هدايا ومكافآت', 'FEELING LUCKY?'), ''),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final width =
            stacked ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: width,
                  child: _rewardTicket(
                      id: 'daily',
                      title: _tr('هدية يومية', 'Daily gift'),
                      asset: 'assets/store/reward_daily.webp',
                      frame: const Rect.fromLTRB(.10, .21, .90, .909),
                      button: const Rect.fromLTRB(.125, .291, .486, .780),
                      label: dailyLabel,
                      tooltip: dailyHint,
                      available: dailyAvailable && !disabled,
                      onTap: _claimDailyReward)),
              SizedBox(
                  width: width,
                  child: _rewardTicket(
                      id: 'watch',
                      title: _tr('شاهد واربح', 'Watch and earn'),
                      asset: 'assets/store/reward_watch.webp',
                      frame: const Rect.fromLTRB(.044, .05, .946, .925),
                      button: const Rect.fromLTRB(.07, .15, .477, .75),
                      label: watchLabel,
                      tooltip: watchHint,
                      available: ads.canWatchAd && !disabled,
                      onTap: _watchAd)),
            ]);
      }),
    ]);
  }

  Widget _rewardTicket(
          {required String id,
          required String title,
          required String asset,
          required Rect frame,
          required Rect button,
          required String label,
          required bool available,
          required VoidCallback onTap,
          required String tooltip}) =>
      Semantics(
        label: '$title. $tooltip',
        child: Tooltip(
          message: tooltip,
          child: GameStoreRewardBanner(
            key: ValueKey('store-reward-$id'),
            asset: asset,
            sourceFrame: frame,
            sourceButton: button,
            imageKey: ValueKey('store-reward-art-$id'),
            actionKey: ValueKey('store-reward-action-$id'),
            onPressed: available ? onTap : null,
            action: _StoreButton(
                label: label,
                icon: Icons.check_rounded,
                accent: _green,
                compact: true,
                glossy: true,
                onPressed: available ? onTap : null),
          ),
        ),
      );
  Widget _characterShowcase(AppState app, bool disabled) => LayoutBuilder(
      key: const ValueKey('store-character-showcase'),
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final columns = constraints.maxWidth < 600 ? 1 : 2;
        final maxWidth = viewport.height < 500
            ? ((viewport.height - 120) * 1452 / 1026).clamp(220.0, 360.0)
            : 460.0;
        final width = ((constraints.maxWidth - (columns - 1) * 12) / columns)
            .clamp(0.0, maxWidth);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final character in [
              CharacterCatalog.all[2],
              CharacterCatalog.all[7],
              ...CharacterCatalog.all.skip(8),
            ])
              SizedBox(
                width: width,
                child: GameStoreCharacterCard(
                  key: ValueKey('store-character-${character.id}'),
                  gems: character.unlock.kind == CharacterUnlockKind.gems,
                  title: character.nameAr,
                  avatarAsset: (character.index == 2 || character.index == 7)
                      ? null
                      : character.asset,
                  label: app.isCharacterUnlocked(character)
                      ? _tr('تم الامتلاك', 'Owned')
                      : character.unlock.isLevelGated
                          ? _tr('المستوى ${character.unlock.value}',
                              'Level ${character.unlock.value}')
                          : '${_number(character.unlock.value)} ${character.unlock.kind == CharacterUnlockKind.coins ? _tr('نقود', 'coins') : _tr('جواهر', 'gems')}',
                  onPressed: disabled
                      ? null
                      : () => _openCharacters(character.index),
                ),
              ),
          ],
        );
      });
  Widget _purchaseButton(
      StoreProduct product, InAppPurchaseService iap, bool disabled,
      {bool owned = false,
      bool compact = false,
      bool glossy = false,
      bool imageButton = false}) {
    final price = iap.getProductDetails(product.id)?.price;
    final available = iap.isAvailable && price != null && price.isNotEmpty;
    final checkingOwnership = !context.read<AppState>().isCommerceReady;
    final button = _StoreButton(
      compact: compact,
      glossy: glossy,
      imageButton: imageButton,
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
    if (compact || owned || checkingOwnership || iap.isLoading || available) {
      return Tooltip(
        message: available ? _title(product) : iap.getExplanation(product.id),
        child: button,
      );
    }
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
      LayoutBuilder(builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final maxWidth = viewport.height < 500
            ? ((viewport.height - 100) * (3168 / 1344)).clamp(400.0, 960.0)
            : 960.0;
        return Center(
            child: SizedBox(
          width: constraints.maxWidth.clamp(0.0, maxWidth),
          child: Semantics(
            label:
                '${_title(product)}. ${_subtitle(product)}. ${_tr('وصول لجميع الفئات المميزة. بدون إعلانات إجبارية. مكافآت الإعلانات تبقى اختيارية.', 'Access to every premium category. No forced ads. Reward ads remain optional.')}',
            child: GameStoreMembershipCard(
              priceButton: _purchaseButton(product, iap, disabled,
                  owned: app.isVip, compact: true, imageButton: true),
            ),
          ),
        ));
      }),
      if (app.isVip) ...[
        const SizedBox(height: 12),
        Center(
            child: _pill(
                _tr('عضويتك مفعّلة', 'Your membership is active'), _green)),
        if (app.vipExpiresAtMillis > 0) ...[
          const SizedBox(height: 8),
          Text(
              _tr('الفترة الحالية متاحة حتى ${_expiry(app.vipExpiresAtMillis)}',
                  'Current access is valid through ${_expiry(app.vipExpiresAtMillis)}'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _green, fontSize: 12)),
        ],
      ],
      const SizedBox(height: 16),
      _vipWelcomeBonusCard(app, disabled),
      const SizedBox(height: 20),
      _vipPerksShowcase(),
      const SizedBox(height: 16),
      Text(
          _tr('يتجدد تلقائياً كل شهر. يمكنك إلغاء التجديد من Google Play في أي وقت؛ يستمر الوصول حتى نهاية الفترة المدفوعة.',
              'Renews automatically every month. Cancel renewal in Google Play at any time; access continues until the paid period ends.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.7)),
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

  Widget _vipWelcomeBonusCard(AppState app, bool disabled) {
    final canClaim = app.canClaimVipBonus;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C104D),
            Color(0xFF1E0A36),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 8),
                GameStoreText(
                  _tr('هدية الانضمام الفورية للأبطال 🎁',
                      'Instant Champions Welcome Pack 🎁'),
                  size: 18,
                  color: const Color(0xFFFFD54F),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFFFD54F), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tr(
              'باقة حصرية تضاف لرصيدك فوراً عند الاشتراك لتنطلق بقوة الأبطال:',
              'Exclusive instant resource bundle granted to empower your journey:',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFE2D9F3), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _vipRewardCapsule(
                  '100', _tr('جوهرة', 'Gems'), Icons.diamond_rounded, _cyan),
              _vipRewardCapsule('1,000', _tr('قطعة', 'Coins'),
                  Icons.monetization_on_rounded, _gold),
              _vipRewardCapsule('3', _tr('مفاتيح', 'Keys'),
                  Icons.vpn_key_rounded, const Color(0xFFFFB74D)),
              _vipRewardCapsule('3', _tr('تذاكر', 'Tickets'),
                  Icons.confirmation_number_rounded, _purple),
              _vipRewardCapsule(
                  '3', _tr('قلوب', 'Hearts'), Icons.favorite_rounded, _red),
            ],
          ),
          if (app.isVip) ...[
            const SizedBox(height: 14),
            if (canClaim)
              ElevatedButton.icon(
                key: const ValueKey('claim-vip-bonus-button'),
                onPressed: disabled || _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final ok = await app.claimVipBonus();
                          if (ok && mounted) {
                            showCurrencyRewardOverlay(context,
                                coins: 1000, gems: 100);
                            _snack(_tr(
                                'تهانينا! تم استلام هدية نادي الأبطال بنجاح 💎🪙🗝️',
                                'Congratulations! Champions Club gift claimed successfully 💎🪙🗝️'));
                          } else if (mounted) {
                            _snack(
                                _tr('تعذر استلام هدية العضوية. حدّث الأرصدة وحاول مجددًا.',
                                    'Could not claim your membership gift. Refresh your balance and try again.'),
                                error: true);
                          }
                        } catch (e) {
                          if (mounted) _snack(e.toString(), error: true);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.black87, size: 20),
                label: Text(
                  _tr('استلام هدية نادي الأبطال الآن',
                      'Claim Champions Club Gift Now'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              )
            else
              _pill(
                  _tr('تم استلام هدية العضوية لهذه الدورة ✓',
                      'Membership gift claimed for current period ✓'),
                  _green),
          ],
        ],
      ),
    );
  }

  Widget _vipRewardCapsule(
      String amount, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(amount,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _vipPerksShowcase() {
    final perks = [
      (
        icon: Icons.category_rounded,
        color: _cyan,
        title: _tr('فتح كل الفئات والتصنيفات', 'All Categories Unlocked'),
        desc: _tr(
            'وصول كامل وغير محدود لجميع الفئات والتصنيفات المميزة طوال مدة اشتراكك دون تذاكر أو استئجار.',
            'Unlimited access to all premium categories throughout your subscription without tickets or rentals.'),
      ),
      (
        icon: Icons.block_rounded,
        color: _green,
        title: _tr('لعب نقي 100% بدون إعلانات إجبارية', 'Zero Forced Ads'),
        desc: _tr(
            'استمتع باللعب المتواصل والمباريات دون أي فواصل إعلانية مزعجة. إعلانات المكافآت تبقى اختيارية.',
            'Enjoy seamless matches without intrusive popups. Reward ads remain optional.'),
      ),
      (
        icon: Icons.workspace_premium_rounded,
        color: _gold,
        title: _tr('شارة وتاج عضوية VIP الفاخرة', 'Royal VIP Crown Badge'),
        desc: _tr(
            'بطاقة عضوية الأبطال المميزة مع عرض حالة اشتراكك ومزاياه في المتجر.',
            'Your Champions Club membership card displays your active status and benefits in the store.'),
      ),
      (
        icon: Icons.card_giftcard_rounded,
        color: _purple,
        title: _tr('باقة موارد مستمرة مع كل تجديد', 'Renewable Resource Gifts'),
        desc: _tr(
            'استلم 100 جوهرة و1000 قطعة و3 مفاتيح و3 تذاكر و3 قلوب من زر هدية العضوية مرة واحدة لكل دورة اشتراك شهري.',
            'Claim 100 gems, 1,000 coins, 3 keys, 3 tickets and 3 hearts using the membership gift button once per monthly cycle.'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: GameStoreText(
                _tr('المزايا الملكية الحصرية', 'Royal VIP Privileges'),
                size: 20,
                color: const Color(0xFFFFD54F),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tr('ارتقِ بتجربة اللعب لأعلى مستويات الاحتراف',
              'Elevate your gaming to the highest competitive level'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        _responsiveWrap(
          minWidth: 260,
          children: perks.map((perk) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: perk.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: perk.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(perk.icon, color: perk.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          perk.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          perk.desc,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
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
              child: adaptiveAssetImage(character.asset,
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
    final adReady =
        (app.economyWallet.adPermits[GameCategory.normalize(category.name)] ??
                0) >
            0;
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
                  child: adaptiveAssetImage(category.assetPath,
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
                      _tr('الاستئجار: $rentalHours ساعة متبقية',
                          'Rental: $rentalHours hours left'),
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
            const SizedBox(height: 8),
            _rentalButton(category, disabled),
            if (adReady) ...[
              const SizedBox(height: 4),
              const Text('تصريح مباراة واحدة جاهز',
                  style: TextStyle(color: _green, fontSize: 12)),
            ],
            if (!available &&
                !adReady &&
                CategoryCatalog.allowsAd(category.name))
              TextButton.icon(
                  onPressed: disabled ? null : () => _rentCategory(category),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
                  label: Text(_tr('إعلان • مباراة واحدة', 'Ad • one match'),
                      style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      minimumSize: const Size(0, 42),
                      visualDensity: VisualDensity.compact)),
          ],
          if (!owned && app.economyWallet.categoryVouchers > 0)
            TextButton(
                onPressed: disabled
                    ? null
                    : () => _categoryAction(category, {'action': 'ownVoucher'},
                        'امتلاك دائم باستخدام قسيمة واحدة'),
                child: const Text('استخدام قسيمة امتلاك')),
        ]));
  }

  Widget _rentalButton(GameCategory category, bool disabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : () => _rentalOptions(category),
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              adaptiveAssetImage(
                'assets/store/btn_rent_green.png',
                height: 44,
                fit: BoxFit.contain,
              ),
              const Opacity(
                opacity: 0.0,
                child: Text(
                  'إستئجار',
                  style: TextStyle(fontSize: 1),
                ),
              ),
              const Opacity(
                opacity: 0.0,
                child: Text(
                  'استئجار',
                  style: TextStyle(fontSize: 1),
                ),
              ),
              const Opacity(
                opacity: 0.0,
                child: Text(
                  'استئجار يوم / أسبوع / شهر',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freeRewards(AppState app, AdService ads, bool disabled) {
    CrossPromoService? promo;
    try {
      promo = context.watch<CrossPromoService>();
    } catch (_) {}
    final daily = app.todayReward;
    final dailyAvailable = app.dailyStreakLoaded &&
        !app.claimedToday &&
        app.isOnline &&
        app.user != null;
    final dailyLabel = app.claimedToday
        ? _tr('تم الاستلام • عد غداً', 'Claimed • Come back tomorrow')
        : !app.dailyStreakLoaded
            ? _tr('جارٍ تحميل الهدية…', 'Loading your gift…')
            : app.user == null
                ? _tr(
                    'سجّل الدخول لاستلام الهدية', 'Sign in to claim your gift')
                : !app.isOnline
                    ? _tr(
                        'تحتاج اتصالاً بالإنترنت', 'Internet connection needed')
                    : _tr('استلام الهدية', 'Claim gift');
    final watchLabel = ads.watchesLeft == 0
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
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 600 ? 1 : 3;
        final viewport = MediaQuery.sizeOf(context);
        final maxWidth = viewport.height < 500
            ? ((viewport.height - 110) * .83).clamp(120.0, 260.0)
            : 320.0;
        final width = ((constraints.maxWidth - (columns - 1) * 12) / columns)
            .clamp(0.0, maxWidth);
        return Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 18,
            children: [
              SizedBox(
                  width: width,
                  child: _returnRewardCard(
                      id: 'daily',
                      asset: 'assets/store/return_daily.webp',
                      frame: const Rect.fromLTRB(.020, .027, .978, .980),
                      title: _tr('هدية اليوم', 'Your daily gift'),
                      label: dailyLabel,
                      available: dailyAvailable && !disabled,
                      onTap: _claimDailyReward,
                      labels: [
                        GameStoreArtworkLabel(
                            area: const Rect.fromLTRB(.12, .297, .711, .365),
                            cleanStrip:
                                const Rect.fromLTRB(.12, .367, .711, .380),
                            child: _artworkText(
                                _tr('اليوم ${app.streakDay > 0 ? app.streakDay : 1} من سلسلة العودة',
                                    'Day ${app.streakDay > 0 ? app.streakDay : 1} of your streak'),
                                size: 18)),
                        GameStoreArtworkLabel(
                            area: const Rect.fromLTRB(.145, .515, .352, .583),
                            cleanStrip:
                                const Rect.fromLTRB(.129, .515, .140, .583),
                            child: _artworkText(
                                '${_number(daily['gems'] ?? 0)} ${_tr('جوهرة', 'gems')}',
                                color: _cyan)),
                        GameStoreArtworkLabel(
                            area: const Rect.fromLTRB(.540, .515, .765, .583),
                            cleanStrip:
                                const Rect.fromLTRB(.523, .515, .533, .583),
                            child: _artworkText(
                                '${_number(daily['coins'] ?? 0)} ${_tr('نقود', 'coins')}',
                                color: _gold)),
                      ])),
              SizedBox(
                  width: width,
                  child: _returnRewardCard(
                      id: 'watch',
                      asset: 'assets/store/return_watch.webp',
                      frame: const Rect.fromLTRB(.021, .019, .991, .980),
                      title: _tr('مكافأة المشاهدة', 'Watch and earn'),
                      label: watchLabel,
                      available: ads.canWatchAd && !disabled,
                      onTap: _watchAd,
                      labels: [
                        GameStoreArtworkLabel(
                            area: const Rect.fromLTRB(.09, .290, .715, .355),
                            cleanStrip:
                                const Rect.fromLTRB(.09, .360, .715, .372),
                            child: _artworkText(
                                _tr('${ads.watchesLeft} من ${AdService.maxDailyWatches} مشاهدات متبقية اليوم',
                                    '${ads.watchesLeft} of ${AdService.maxDailyWatches} watches left today'),
                                size: 18)),
                      ])),
              if (promo != null)
                SizedBox(
                    width: width, child: _downloadRewardCard(promo, disabled)),
            ]);
      }),
    ]);
  }

  Widget _artworkText(String label,
          {Color color = Colors.white, double size = 22}) =>
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: GameStoreText(label, color: color, size: size)));

  Widget _returnRewardCard(
          {required String id,
          required String asset,
          required Rect frame,
          required String title,
          required String label,
          required bool available,
          required VoidCallback onTap,
          required List<GameStoreArtworkLabel> labels}) =>
      Semantics(
          label: title,
          child: GameStoreReturnRewardCard(
            key: ValueKey('store-return-$id'),
            asset: asset,
            sourceFrame: frame,
            imageKey: ValueKey('store-return-art-$id'),
            actionKey: ValueKey('store-return-action-$id'),
            onPressed: available ? onTap : null,
            labels: [
              ...labels,
              const GameStoreArtworkLabel(
                  area: Rect.fromLTRB(.125, .775, .880, .894),
                  cleanStrip: Rect.fromLTRB(.135, .775, .145, .894))
            ],
            action: _StoreButton(
                label: label,
                icon: Icons.card_giftcard_rounded,
                accent: _green,
                compact: true,
                imageButton: true,
                onPressed: available ? onTap : null),
          ));

  Widget _downloadRewardCard(CrossPromoService promo, bool disabled) {
    final claimed = promo.isRewardClaimed;
    final installed = promo.isMillionaireInstalled;
    final claiming = promo.isClaiming;
    final status = claimed
        ? _tr('تم استلام الجائزة بنجاح ✓', 'Reward claimed ✓')
        : installed
            ? _tr('اللعبة مثبتة • استلم هديتك الآن!',
                'Game installed • Claim now!')
            : _tr('حمّل اللعبة واحصل على 80 جوهرة', 'Download & earn 80 gems');
    final label = claimed
        ? _tr('تم استلام الـ 80 جوهرة ✓', '80 Gems Claimed ✓')
        : claiming
            ? _tr('جارٍ الاستلام…', 'Claiming…')
            : installed
                ? _tr('استلام 80 جوهرة الآن', 'Claim 80 Gems Now')
                : _tr('تحميل اللعبة (+80 جوهرة)', 'Download Game (+80 gems)');
    return _returnRewardCard(
        id: 'download',
        asset: 'assets/store/return_download.webp',
        frame: const Rect.fromLTRB(.020, .023, .978, .984),
        title: _tr('مكافأة تحميل تحدي المليون', 'Million Challenge Reward'),
        label: label,
        available: !disabled && !claimed && !claiming,
        onTap: () => _claimPromoReward(promo),
        labels: [
          GameStoreArtworkLabel(
              area: const Rect.fromLTRB(.14, .319, .72, .386),
              cleanStrip: const Rect.fromLTRB(.14, .390, .72, .405),
              child: _artworkText(status,
                  color: claimed ? _green : Colors.white, size: 18))
        ]);
  }

  Future<void> _claimPromoReward(CrossPromoService promo) async {
    if (_busy || promo.isClaiming || promo.isRewardClaimed) return;
    if (promo.isMillionaireInstalled) {
      final result = await promo.claimDownloadReward(context);
      if (result == CrossPromoClaimResult.success && mounted) {
        _snack(_tr('تمت إضافة 80 جوهرة إلى رصيدك بنجاح! 💎🎉',
            '80 gems added to your balance successfully! 💎🎉'));
      }
    } else {
      CrossPromoMillionaireDialog.show(context);
    }
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

  Widget _sectionTitle(String title, String subtitle, {Widget? action}) =>
      LayoutBuilder(
          builder: (context, constraints) => Column(children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Container(
                              height: 2,
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                Colors.transparent,
                                Color(0xFF8E83A5)
                              ])))),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: (constraints.maxWidth - 24) * .6),
                          child: GameStoreText(title, size: 23, maxLines: 2)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(
                              height: 2,
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                Color(0xFF8E83A5),
                                Colors.transparent
                              ])))),
                    ]),
                    if (action != null)
                      PositionedDirectional(
                        end: 0,
                        child: FittedBox(fit: BoxFit.scaleDown, child: action),
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty &&
                    MediaQuery.sizeOf(context).height >= 500) ...[
                  const SizedBox(height: 5),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _muted, fontSize: 11, height: 1.5)),
                ],
              ]));

  Widget _rewardSummary(int coins, int gems,
          {int keys = 0,
          int tickets = 0,
          int hearts = 0,
          bool centered = false}) =>
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            if (coins > 0)
              _currencyReward(coins, Icons.monetization_on_rounded, _gold,
                  _tr('نقود', 'coins')),
            if (gems > 0)
              _currencyReward(
                  gems, Icons.diamond_rounded, _cyan, _tr('جوهرة', 'gems')),
            if (keys > 0)
              _currencyReward(keys, Icons.vpn_key_rounded,
                  const Color(0xFFFFB74D), _tr('مفاتيح', 'keys')),
            if (tickets > 0)
              _currencyReward(tickets, Icons.confirmation_number_rounded,
                  _purple, _tr('تذاكر', 'tickets')),
            if (hearts > 0)
              _currencyReward(
                  hearts, Icons.favorite_rounded, _red, _tr('قلوب', 'hearts')),
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
      GameStoreFrame(
          padding: EdgeInsets.all(padding),
          colors: gradient == null
              ? const [Color(0xFF7012BC), Color(0xFF33116B)]
              : [gradient.first, const Color(0xFF481174)],
          child: child);

  Widget _responsiveWrap(
          {required List<Widget> children, required double minWidth}) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + 12) / (minWidth + 12)).floor().clamp(1, 5);
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });

  String _resourceGrantLabel(Map<String, dynamic> grants) {
    if (!_arabic) {
      return grants.entries.map((entry) {
        final name = switch (entry.key) {
          'keys' => entry.value == 1 ? 'key' : 'keys',
          'hearts' => entry.value == 1 ? 'heart' : 'hearts',
          'tickets' => entry.value == 1 ? 'ticket' : 'tickets',
          'categoryVouchers' =>
            entry.value == 1 ? 'permanent voucher' : 'permanent vouchers',
          'rentalVouchers' =>
            entry.value == 1 ? 'rental voucher' : 'rental vouchers',
          _ => entry.key,
        };
        return '${entry.value} $name';
      }).join(' + ');
    }
    return resourceGrantText(grants);
  }

  Widget _resourceBalancesHUD(AppState app) {
    final wallet = app.economyWallet;
    return LayoutBuilder(builder: (context, constraints) {
      final cardRow = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _resourceCard(
              asset: 'assets/store/hud_keys.webp',
              title: _tr('المفاتيح', 'Keys'),
              value: app.economyLoaded ? '${wallet.totalKeys}' : '…',
              badgeText: app.economyLoaded
                  ? _tr('${wallet.dailyKeys} يومية • ${wallet.keys} إضافية',
                      '${wallet.dailyKeys} daily • ${wallet.keys} extra')
                  : _tr('جارٍ التحميل…', 'Loading…'),
              badgeBg: const Color(0xFF382613),
              badgeTextColor: const Color(0xFFFFB834),
              hint: _tr('مفتاح لكل مباراة كاملة', '1 key per match'),
              defaultBakedValue: 10,
              defaultBakedBadge: '2 يومية • 8 إضافية',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _resourceCard(
              asset: 'assets/store/hud_hearts.webp',
              title: _tr('القلوب', 'Hearts'),
              value: app.economyLoaded ? '${wallet.totalHearts}' : '…',
              badgeText: app.economyLoaded
                  ? _tr('${wallet.dailyHearts} يومية • ${wallet.hearts} إضافية',
                      '${wallet.dailyHearts} daily • ${wallet.hearts} extra')
                  : _tr('جارٍ التحميل…', 'Loading…'),
              badgeBg: const Color(0xFF40142A),
              badgeTextColor: const Color(0xFFFF4D94),
              hint: _tr('محاولات لتحدي المراحل', 'Saved stage attempts'),
              defaultBakedValue: 9,
              defaultBakedBadge: '3 يومية • 6 إضافية',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _resourceCard(
              asset: 'assets/store/hud_tickets.webp',
              title: _tr('تذاكر التصنيفات', 'Tickets'),
              value: app.economyLoaded ? '${wallet.tickets}' : '…',
              badgeText: app.economyLoaded
                  ? _tr('${wallet.tickets} تذاكر محفوظة',
                      '${wallet.tickets} tickets saved')
                  : _tr('جارٍ التحميل…', 'Loading…'),
              badgeBg: const Color(0xFF132A3E),
              badgeTextColor: const Color(0xFF4DD0E1),
              hint: _tr('تفتح أي تصنيف لمباراة', '1 match unlock'),
              defaultBakedValue: 8,
              defaultBakedBadge: '8 تذاكر محفوظة',
            ),
          ),
        ],
      );

      return _panel(
        padding: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: cardRow,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33E4B8FF)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _cyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.economyLoaded
                          ? _tr(
                              'المفاتيح والقلوب اليومية تُستكمل إلى 3 عند منتصف الليل UTC. الأرصدة الإضافية محفوظة بحسابك دائماً.',
                              'Daily keys and hearts replenish to 3 at midnight UTC. Extra balance remains saved permanently.')
                          : (app.economyError ??
                              _tr('جارٍ الاتصال بخدمة الأرصدة…',
                                  'Connecting to resources service…')),
                      style: const TextStyle(
                          color: _muted, fontSize: 11, height: 1.5),
                    ),
                  ),
                ]),
                if (wallet.nextResetMillis > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.timer_outlined, color: _gold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _tr(
                        'التجديد القادم: ${_formatDateTime(wallet.nextResetMillis)}',
                        'Next reset: ${_formatDateTime(wallet.nextResetMillis)}',
                      ),
                      style: const TextStyle(color: _gold, fontSize: 11),
                    ),
                  ]),
                ],
              ]),
            ),
            if (wallet.categoryVouchers > 0 || wallet.rentalVouchers > 0) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (wallet.categoryVouchers > 0)
                  _pill(
                      _tr('قسائم امتلاك تصنيف: ${wallet.categoryVouchers}',
                          'Permanent vouchers: ${wallet.categoryVouchers}'),
                      _green),
                if (wallet.rentalVouchers > 0)
                  _pill(
                      _tr('قسائم استئجار أسبوعية: ${wallet.rentalVouchers}',
                          'Weekly rental vouchers: ${wallet.rentalVouchers}'),
                      _cyan),
              ]),
            ],
            if (!app.economyLoaded && !app.isOnline) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: app.loadEconomy,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_tr('إعادة محاولة الاتصال', 'Retry connection')),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _resourceCard({
    required String asset,
    required String title,
    required String value,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    required String hint,
    required int defaultBakedValue,
    required String defaultBakedBadge,
  }) {
    final needsValueOverlay = value != '$defaultBakedValue' || !_arabic;
    final needsBadgeOverlay = badgeText != defaultBakedBadge || !_arabic;
    return Semantics(
      label: '$title: $value, $badgeText, $hint',
      child: Tooltip(
        message: '$title: $value\n$badgeText\n$hint',
        child: AspectRatio(
          aspectRatio: 1118 / 912,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: adaptiveAssetImage(
                    asset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                if (!_arabic)
                  Positioned(
                    top: h * 0.44,
                    left: w * 0.08,
                    right: w * 0.08,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF280E46),
                        borderRadius: BorderRadius.circular(h * 0.03),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: GameStoreText(title,
                            size: (h * 0.12).clamp(9.0, 15.0)),
                      ),
                    ),
                  ),
                if (needsValueOverlay)
                  Positioned(
                    top: h * 0.53,
                    left: w * 0.22,
                    right: w * 0.22,
                    child: Container(
                      height: h * 0.14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF280E46),
                        borderRadius: BorderRadius.circular(h * 0.03),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (h * 0.16).clamp(11.0, 22.0),
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Baloo',
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (needsBadgeOverlay)
                  Positioned(
                    top: h * 0.69,
                    left: w * 0.12,
                    right: w * 0.12,
                    child: Container(
                      height: h * 0.11,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(h * 0.055),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: (h * 0.08).clamp(8.0, 11.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_arabic)
                  Positioned(
                    bottom: h * 0.06,
                    left: w * 0.06,
                    right: w * 0.06,
                    child: Container(
                      color: const Color(0xFF1B1826),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          hint,
                          style: TextStyle(
                            color: _muted.withValues(alpha: 0.8),
                            fontSize: (h * 0.07).clamp(7.0, 10.0),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String? _exchangeOfferAsset(String offerId, Map<String, dynamic> grants) {
    switch (offerId) {
      case 'keys_1':
        return 'assets/store/exchange_keys_1.webp';
      case 'keys_3':
        return 'assets/store/exchange_keys_3.webp';
      case 'hearts_1':
        return 'assets/store/exchange_hearts_1.webp';
      case 'hearts_3':
        return 'assets/store/exchange_hearts_3.webp';
      case 'tickets_1':
        return 'assets/store/exchange_tickets_1.webp';
      case 'tickets_3':
        return 'assets/store/exchange_tickets_3.webp';
      case 'play_bundle':
        return 'assets/store/exchange_bundle_3.webp';
      case 'play_bundle_large':
        return 'assets/store/exchange_bundle_10.webp';
      default:
        if (grants.containsKey('keys') && grants['keys'] == 1) {
          return 'assets/store/exchange_keys_1.webp';
        }
        if (grants.containsKey('keys') && (grants['keys'] ?? 0) >= 3) {
          return 'assets/store/exchange_keys_3.webp';
        }
        if (grants.containsKey('hearts') && grants['hearts'] == 1) {
          return 'assets/store/exchange_hearts_1.webp';
        }
        if (grants.containsKey('hearts') && (grants['hearts'] ?? 0) >= 3) {
          return 'assets/store/exchange_hearts_3.webp';
        }
        if (grants.containsKey('tickets') && grants['tickets'] == 1) {
          return 'assets/store/exchange_tickets_1.webp';
        }
        if (grants.containsKey('tickets') && (grants['tickets'] ?? 0) >= 3) {
          return 'assets/store/exchange_tickets_3.webp';
        }
        if (grants.length > 1) {
          return 'assets/store/exchange_bundle_3.webp';
        }
        return null;
    }
  }

  Widget _inGameExchangeGrid(AppState app, bool disabled) {
    final offers = app.economyWallet.offers.entries.toList();
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      final columns = isNarrow ? 1 : 2;
      const spacing = 12.0;
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.center,
        children: [
          for (final entry in offers)
            SizedBox(
              width: width,
              child: _inGameExchangeCard(entry.key, entry.value, app, disabled),
            ),
        ],
      );
    });
  }

  Widget _inGameExchangeCard(
      String offerId, dynamic rawOffer, AppState app, bool disabled) {
    final offer = Map<String, dynamic>.from(rawOffer as Map);
    final grants = offer['grants'] is Map
        ? Map<String, dynamic>.from(offer['grants'] as Map)
        : <String, dynamic>{'${offer['resource']}': offer['amount']};
    final title = _resourceGrantLabel(grants);
    final coinsPrice = (offer['coins'] as num?)?.toInt() ?? 0;
    final gemsPrice = (offer['gems'] as num?)?.toInt() ?? 0;
    final asset = _exchangeOfferAsset(offerId, grants);

    if (asset == null) {
      final hasKeys = grants.containsKey('keys');
      final hasHearts = grants.containsKey('hearts');
      final accent = (hasKeys && hasHearts) || grants.length > 1
          ? _purple
          : hasKeys
              ? _gold
              : hasHearts
                  ? storePink
                  : _cyan;

      return _panel(
        accent: accent,
        padding: 14,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _iconTile(
              grants.length > 1
                  ? Icons.all_inclusive_rounded
                  : hasKeys
                      ? Icons.key_rounded
                      : hasHearts
                          ? Icons.favorite_rounded
                          : Icons.confirmation_number_rounded,
              accent,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameStoreText(title, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      _tr('إضافة فورية إلى رصيد حسابك',
                          'Added instantly to your account'),
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (coinsPrice > 0)
                _StoreButton(
                  compact: true,
                  label: '${_number(coinsPrice)} ${_tr('قطعة', 'coins')}',
                  icon: Icons.monetization_on_rounded,
                  accent: _gold,
                  onPressed:
                      disabled || !app.economyLoaded || app.coins < coinsPrice
                          ? null
                          : () => _buyResourceOffer(offerId, offer, 'coins'),
                ),
              if (gemsPrice > 0)
                _StoreButton(
                  compact: true,
                  label: '${_number(gemsPrice)} ${_tr('جوهرة', 'gems')}',
                  icon: Icons.diamond_rounded,
                  accent: _cyan,
                  onPressed:
                      disabled || !app.economyLoaded || app.gems < gemsPrice
                          ? null
                          : () => _buyResourceOffer(offerId, offer, 'gems'),
                ),
            ],
          ),
        ]),
      );
    }

    final hasEnoughCoins = app.coins >= coinsPrice;
    final hasEnoughGems = app.gems >= gemsPrice;

    return Semantics(
      label:
          '$title: ${_number(coinsPrice)} ${_tr('قطعة', 'coins')}، ${_number(gemsPrice)} ${_tr('جوهرة', 'gems')}',
      child: Tooltip(
        message:
            '$title\n${_number(coinsPrice)} ${_tr('قطعة', 'coins')} • ${_number(gemsPrice)} ${_tr('جوهرة', 'gems')}',
        child: AspectRatio(
          aspectRatio: 1168 / 450,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: adaptiveAssetImage(
                    asset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                if (!_arabic)
                  Positioned(
                    top: h * 0.18,
                    right: w * 0.16,
                    left: w * 0.36,
                    bottom: h * 0.48,
                    child: Container(
                      color: const Color(0xFF1B0D36),
                      alignment: Alignment.centerRight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GameStoreText(title,
                                size: (h * 0.14).clamp(10.0, 16.0)),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _tr('إضافة فورية إلى رصيد حسابك',
                                  'Added instantly to your account'),
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: (h * 0.08).clamp(8.0, 11.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: w * 0.365,
                  width: w * 0.31,
                  top: h * 0.53,
                  height: h * 0.30,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(h * 0.08),
                      onTap: disabled || !app.economyLoaded
                          ? null
                          : () {
                              if (!hasEnoughCoins) {
                                _snack(
                                  _tr('تحتاج ${_number(coinsPrice - app.coins)} قطعة نقدية إضافية.',
                                      'You need ${_number(coinsPrice - app.coins)} more coins.'),
                                  error: true,
                                );
                              } else {
                                _buyResourceOffer(offerId, offer, 'coins');
                              }
                            },
                      child: Stack(
                        children: [
                          if (!hasEnoughCoins)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(h * 0.08),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.lock_outline_rounded,
                                    color: Colors.white70,
                                    size: (h * 0.14).clamp(10.0, 16.0)),
                              ),
                            ),
                          if (!_arabic)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(h * 0.08),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF7CE424),
                                      Color(0xFF43980B)
                                    ],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${_number(coinsPrice)} Coins',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: (h * 0.11).clamp(9.0, 14.0),
                                      fontFamily: 'Baloo',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.055,
                  width: w * 0.29,
                  top: h * 0.53,
                  height: h * 0.30,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(h * 0.08),
                      onTap: disabled || !app.economyLoaded
                          ? null
                          : () {
                              if (!hasEnoughGems) {
                                _snack(
                                  _tr('تحتاج ${_number(gemsPrice - app.gems)} جوهرة إضافية.',
                                      'You need ${_number(gemsPrice - app.gems)} more gems.'),
                                  error: true,
                                );
                              } else {
                                _buyResourceOffer(offerId, offer, 'gems');
                              }
                            },
                      child: Stack(
                        children: [
                          if (!hasEnoughGems)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(h * 0.08),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.lock_outline_rounded,
                                    color: Colors.white70,
                                    size: (h * 0.14).clamp(10.0, 16.0)),
                              ),
                            ),
                          if (!_arabic)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(h * 0.08),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF7CE424),
                                      Color(0xFF43980B)
                                    ],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${_number(gemsPrice)} Gems',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: (h * 0.11).clamp(9.0, 14.0),
                                      fontFamily: 'Baloo',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String? _resourceProductAsset(String id) {
    return switch (id) {
      'resources_3_each' => 'assets/store/pack_resources_3.webp',
      'resources_10_each' => 'assets/store/pack_resources_10.webp',
      'keys_1' => 'assets/store/pack_keys_1.webp',
      'hearts_1' => 'assets/store/pack_hearts_1.webp',
      'tickets_1' => 'assets/store/pack_tickets_1.webp',
      'keys_10' => 'assets/store/pack_keys_1.webp',
      'hearts_10' => 'assets/store/pack_hearts_1.webp',
      'tickets_10' => 'assets/store/pack_tickets_1.webp',
      _ => null,
    };
  }

  double _resourceProductAspect(String id) {
    if (id.startsWith('resources_')) return 1016 / 1412;
    return 768 / 1216;
  }

  Widget _resourceGrid(List<StoreProduct> products, InAppPurchaseService iap,
          AppState app, bool disabled) =>
      LayoutBuilder(builder: (context, constraints) {
        final bundles =
            products.where((p) => p.id.startsWith('resources_')).toList();
        final singles =
            products.where((p) => !p.id.startsWith('resources_')).toList();

        final maxWidth = constraints.maxWidth;
        final bundleColumns = maxWidth < 400 ? 2 : (maxWidth < 800 ? 2 : 4);
        final singleColumns = maxWidth < 400 ? 3 : (maxWidth < 800 ? 3 : 6);

        final bundleWidth =
            ((maxWidth - (bundleColumns - 1) * 10) / bundleColumns)
                .clamp(110.0, 320.0);
        final singleWidth =
            ((maxWidth - (singleColumns - 1) * 8) / singleColumns)
                .clamp(80.0, 220.0);

        return Column(
          children: [
            if (bundles.isNotEmpty) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final product in bundles)
                    SizedBox(
                      width: bundleWidth,
                      child: _resourceProductCard(product, iap, app, disabled),
                    ),
                ],
              ),
              if (singles.isNotEmpty) const SizedBox(height: 14),
            ],
            if (singles.isNotEmpty) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 12,
                children: [
                  for (final product in singles)
                    SizedBox(
                      width: singleWidth,
                      child: _resourceProductCard(product, iap, app, disabled),
                    ),
                ],
              ),
            ],
          ],
        );
      });

  bool _isAdProduct(String id) =>
      id == 'keys_1' || id == 'hearts_1' || id == 'tickets_1';

  String _adResourceKey(String id) => switch (id) {
        'keys_1' => 'keys',
        'hearts_1' => 'hearts',
        'tickets_1' => 'tickets',
        _ => '',
      };

  Future<void> _claimResourceWithAd(String productId) async {
    if (_busy) return;
    final app = context.read<AppState>();
    AdService? adService;
    try {
      adService = context.read<AdService>();
    } catch (_) {}
    final resourceKey = _adResourceKey(productId);
    if (resourceKey.isEmpty) return;

    final resourceName = switch (resourceKey) {
      'keys' => _tr('مفتاح إضافي', 'Extra Key'),
      'hearts' => _tr('قلب إضافي', 'Extra Heart'),
      'tickets' => _tr('تذكرة تصنيف', 'Category Ticket'),
      _ => '',
    };

    setState(() => _busy = true);
    try {
      final watched = await adService?.showActionRewardedAd() ?? false;
      if (!mounted) return;
      if (!watched) {
        _snack(
          _tr('الإعلان غير متاح حالياً أو لم تكتمل مشاهدته.',
              'The ad is currently unavailable or was not watched to completion.'),
          error: true,
        );
        return;
      }
      final granted = await app.claimAdResource(resourceKey);
      if (mounted && granted) {
        _snack(_tr('تمت إضافة $resourceName بنجاح!',
            '$resourceName added successfully!'));
      }
    } catch (_) {
      if (mounted) {
        _snack(
            _tr('تعذر إضافة المكافأة. حاول مجدداً.',
                'Could not add reward. Try again.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _resourceProductCard(StoreProduct product, InAppPurchaseService iap,
      AppState app, bool disabled) {
    final details = iap.getProductDetails(product.id);
    final price = details?.price;
    final isAd = _isAdProduct(product.id);
    final canBuy = isAd
        ? (!disabled && !_busy)
        : (!disabled &&
            !iap.isLoading &&
            app.isCommerceReady &&
            iap.isAvailable &&
            price != null &&
            price.isNotEmpty);

    final asset = _resourceProductAsset(product.id);
    if (asset == null) {
      return const SizedBox.shrink();
    }

    final is10Pack = product.id.endsWith('_10');
    final aspectRatio = _resourceProductAspect(product.id);
    final buttonLabel = isAd ? _tr('إعلان مجاني', 'Free Ad') : price;
    final semanticPrice = isAd
        ? _tr('إعلان مجاني', 'Free Ad')
        : (canBuy ? price : _tr('غير متاح حالياً', 'Unavailable'));

    return Semantics(
      label: '${_title(product)}: ${_subtitle(product)}, $semanticPrice',
      child: Tooltip(
        message: '${_title(product)}\n${_subtitle(product)}\n$semanticPrice',
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: adaptiveAssetImage(
                    asset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                if (is10Pack)
                  Positioned(
                    top: h * 0.08,
                    left: w * 0.35,
                    right: w * 0.35,
                    child: Container(
                      height: h * 0.08,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38154D),
                        borderRadius: BorderRadius.circular(h * 0.04),
                        border: Border.all(
                            color: const Color(0xFFFFB834), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+10',
                          style: TextStyle(
                            color: const Color(0xFFFFD52A),
                            fontWeight: FontWeight.w900,
                            fontSize: (h * 0.055).clamp(10.0, 16.0),
                            fontFamily: 'Baloo',
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isAd)
                  Positioned(
                    top: h * 0.08,
                    left: w * 0.28,
                    right: w * 0.28,
                    child: Container(
                      height: h * 0.08,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F264A),
                        borderRadius: BorderRadius.circular(h * 0.04),
                        border: Border.all(
                            color: const Color(0xFF29B6F6), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _tr('إعلان', 'AD'),
                          style: TextStyle(
                            color: const Color(0xFF4FC3F7),
                            fontWeight: FontWeight.w900,
                            fontSize: (h * 0.055).clamp(10.0, 16.0),
                            fontFamily: 'Baloo',
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_arabic || is10Pack)
                  Positioned(
                    top: h * 0.55,
                    left: w * 0.08,
                    right: w * 0.08,
                    child: Container(
                      color: const Color(0xFF1B0D36),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GameStoreText(_title(product),
                                size: (h * 0.065).clamp(10.0, 15.0)),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _subtitle(product),
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: (h * 0.045).clamp(7.0, 10.0)),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: h * 0.77,
                  bottom: h * 0.055,
                  left: w * 0.085,
                  right: w * 0.085,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(h * 0.04),
                      onTap: canBuy
                          ? () => isAd
                              ? _claimResourceWithAd(product.id)
                              : _buyProduct(product)
                          : null,
                      child: canBuy
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(h * 0.04),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isAd
                                      ? const [
                                          Color(0xFF29B6F6),
                                          Color(0xFF0288D1),
                                        ]
                                      : const [
                                          Color(0xFF7CE424),
                                          Color(0xFF43980B),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isAd
                                            ? const Color(0xFF0288D1)
                                            : const Color(0xFF43980B))
                                        .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isAd) ...[
                                    Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: (h * 0.065).clamp(11.0, 16.0),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        buttonLabel ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize:
                                              (h * 0.065).clamp(11.0, 18.0),
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Baloo',
                                          shadows: const [
                                            Shadow(
                                              color: Color(0x80000000),
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ((!isAd && iap.isLoading)
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(h * 0.04),
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: (h * 0.08).clamp(12.0, 20.0),
                                    height: (h * 0.08).clamp(12.0, 20.0),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white70),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(h * 0.04),
                                    color: const Color(0xFF26304A),
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                        _tr('غير متاح حالياً', 'Unavailable'),
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  ),
                                )),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _featuredResources(
      InAppPurchaseService iap, AppState app, bool disabled) {
    final products = StoreCatalog.products
        .where((p) => p.kind == StoreProductKind.resource)
        .toList();
    return Column(children: [
      _resourceGrid(products, iap, app, disabled),
      const SizedBox(height: 12),
      _resourcesTeaser(app),
    ]);
  }

  Widget _resourcesTeaser(AppState app) {
    final wallet = app.economyWallet;
    return _panel(
      accent: _purple,
      padding: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD52A), Color(0xFFFF259F)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF259F).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.key_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameStoreText(_tr('أرصدة اللعب والمباريات', 'Play Resources'),
                  size: 16),
              const SizedBox(height: 3),
              Text(
                _tr('مفاتيحك: ${wallet.totalKeys} • قلوبك: ${wallet.totalHearts} • تذاكرك: ${wallet.tickets}',
                    'Keys: ${wallet.totalKeys} • Hearts: ${wallet.totalHearts} • Tickets: ${wallet.tickets}'),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          _StoreButton(
            compact: true,
            label: _tr('عرض الأرصدة', 'View all'),
            icon: Icons.arrow_forward_rounded,
            accent: _purple,
            onPressed: () => _selectSection(_StoreSection.resources),
          ),
        ]),
      ]),
    );
  }

  Widget _loyaltyAndMilestonesPanel(AppState app) {
    final wallet = app.economyWallet;
    return _panel(
      padding: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _iconTile(Icons.military_tech_rounded, _gold, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameStoreText(
                  _tr('مكافآت الوفاء والتقدم في المراحل',
                      'Loyalty & Stage Milestones'),
                  size: 16),
              const SizedBox(height: 2),
              Text(
                _tr('أرصدة مجانية تكافئ استمرارك وإنجازاتك في اللعب',
                    'Free resources rewarding your consistency and achievements'),
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B0B3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33E4B8FF)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.stars_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              Text(
                  _tr('مكافآت وفاء الدخول اليومي',
                      'Daily streak loyalty rewards'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const Spacer(),
              _pill(
                  _tr('سلسلتك: ${wallet.streak} يوم',
                      'Streak: ${wallet.streak} d'),
                  _gold),
            ]),
            const SizedBox(height: 8),
            Text(
              _tr(
                '• اليوم 7: 3 مفاتيح وتذكرتان\n• اليوم 14: 3 مفاتيح وقلب\n• اليوم 21: 4 مفاتيح\n• اليوم 30: 5 مفاتيح وقلبان و3 تذاكر وقسيمة استئجار أسبوعية',
                '• Day 7: 3 keys + 2 tickets\n• Day 14: 3 keys + 1 heart\n• Day 21: 4 keys\n• Day 30: 5 keys + 2 hearts + 3 tickets + 1 rental voucher',
              ),
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B0B3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33E4B8FF)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.flag_rounded, color: _cyan, size: 18),
              const SizedBox(width: 8),
              Text(
                  _tr('مكافآت تقدمك في المراحل',
                      'Stage progression milestones'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Text(
              _tr(
                '• كل 10 مراحل: تذكرة تصنيف واحدة\n• المرحلة 10: مفتاحان إضافيان\n• المرحلة 25: 3 مفاتيح وقسيمة استئجار أسبوعية\n• المرحلة 50 و100: قسيمة امتلاك تصنيف دائم\n• المرحلة 75: 5 مفاتيح وقلبان إضافيان',
                '• Every 10 stages: 1 category ticket\n• Stage 10: 2 extra keys\n• Stage 25: 3 keys + weekly rental voucher\n• Stage 50 & 100: Permanent category voucher\n• Stage 75: 5 keys + 2 hearts',
              ),
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.6),
            ),
          ]),
        ),
        if (wallet.rewardLog.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_tr('آخر المكافآت المستلمة', 'Recent rewards earned'),
              style: const TextStyle(
                  color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          for (final reward in wallet.rewardLog.reversed.take(4))
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: _green, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${switch (reward['kind']) {
                      'welcome' => _tr('هدية البداية', 'Starter gift'),
                      'campaign' => _tr('المرحلة ${reward['stage']}',
                          'Stage ${reward['stage']}'),
                      'login' => _tr('وفاء اليوم ${reward['streak']}',
                          'Day ${reward['streak']} loyalty'),
                      _ => _tr('مهمة اللعب', 'Play mission')
                    }}: ${_resourceGrantLabel(Map<String, dynamic>.from(reward['grants'] as Map? ?? {}))}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ]),
            ),
        ],
      ]),
    );
  }

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hour:$minute';
  }

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
      this.compact = false,
      this.glossy = false,
      this.imageButton = false});
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;
  final bool glossy;
  final bool imageButton;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    if (imageButton) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFFE0E4D9),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: FractionallySizedBox(
            widthFactor: .72,
            heightFactor: .56,
            child: loading
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                : FittedBox(
                    fit: BoxFit.contain,
                    child: GameStoreMembershipPrice(label))),
      );
    }
    if (glossy) {
      return GameStoreGlossySurface(
        enabled: enabled,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFFE0E4D9),
            shadowColor: Colors.transparent,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const FittedBox(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              : FittedBox(
                  fit: BoxFit.scaleDown, child: GameStoreText(label, size: 23)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? const [Color(0xFF73FB12), Color(0xFF35BE0C)]
                : const [Color(0xFF49933B), Color(0xFF2A652A)]),
        borderRadius: BorderRadius.circular(compact ? 3 : 8),
        border: Border.all(
            color: enabled ? const Color(0xFF9AFF60) : const Color(0xFF5B8A52),
            width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF18640D), offset: Offset(0, 3))
        ],
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFE0E4D9),
          shadowColor: Colors.transparent,
          minimumSize: Size(compact ? 0 : double.infinity, compact ? 42 : 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12, vertical: compact ? 5 : 9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 3 : 8)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    if (!compact) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                        child: compact
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: GameStoreText(label, size: 23))
                            : GameStoreText(label, size: 15, maxLines: 3)),
                  ]),
      ),
    );
  }
}
