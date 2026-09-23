import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../models/game_category.dart';
import '../../services/ad_service.dart';
import '../../services/native_bridge_service.dart';
import '../../services/in_app_purchase_service.dart';
import '../../widgets/currency_reward_overlay.dart';
import '../character/character_select_screen.dart';

class _CoinItem {
  const _CoinItem({
    required this.label,
    required this.coinAmount,
    required this.gemCost,
    required this.tag,
  });

  final String label;
  final int coinAmount;
  final int gemCost;
  final String tag;
}

const List<_CoinItem> _kCoinItems = <_CoinItem>[
  _CoinItem(label: '1,500', coinAmount: 1500, gemCost: 15, tag: 'سريع'),
  _CoinItem(label: '6,000', coinAmount: 6000, gemCost: 55, tag: 'شائع'),
  _CoinItem(label: '14,000', coinAmount: 14000, gemCost: 120, tag: 'شخصية'),
  _CoinItem(label: '35,000', coinAmount: 35000, gemCost: 290, tag: 'قيمة'),
  _CoinItem(label: '90,000', coinAmount: 90000, gemCost: 700, tag: 'كبير'),
];

class _BundleItem {
  const _BundleItem({
    required this.id,
    required this.title,
    required this.coins,
    required this.gems,
    required this.price,
    required this.originalPrice,
    required this.tag,
    required this.tagColor,
    required this.colors,
    required this.icon,
    this.multiplier = '',
    this.subtitle = '',
    this.ctaColors = const [Color(0xFF22C55E), Color(0xFF16A34A)],
    this.ctaShadowColor = const Color(0xFF14532D),
    this.ctaTextColor = Colors.white,
  });

  final String id;
  final String title;
  final int coins;
  final int gems;
  final String price;
  final String originalPrice;
  final String tag;
  final Color tagColor;
  final List<Color> colors;
  final IconData icon;
  final String multiplier;
  final String subtitle;
  final List<Color> ctaColors;
  final Color ctaShadowColor;
  final Color ctaTextColor;
}

const List<_BundleItem> _kSpecialBundles = <_BundleItem>[
  _BundleItem(
    id: 'pack_starter',
    title: 'حزمة المبتدئ الخارقة',
    subtitle: 'عرض الترحيب الحصري لمرة واحدة',
    multiplier: 'قيمة 5X ⚡',
    coins: 10000,
    gems: 100,
    price: r'$0.99',
    originalPrice: r'$4.99',
    tag: 'خصم 80% 🔥',
    tagColor: Color(0xFFEF4444),
    colors: [Color(0xFF3B0764), Color(0xFF1E1035)],
    icon: Icons.bolt_rounded,
    ctaColors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF15803D)],
    ctaShadowColor: Color(0xFF14532D),
    ctaTextColor: Colors.white,
  ),
  _BundleItem(
    id: 'pack_value',
    title: 'باقة القيمة الذهبية',
    subtitle: 'الخيار الأكثر شعبية وتفضيلاً',
    multiplier: 'قيمة 4X ⭐',
    coins: 35000,
    gems: 600,
    price: r'$2.99',
    originalPrice: r'$9.99',
    tag: 'الأكثر طلباً 🏆',
    tagColor: Color(0xFF38BDF8),
    colors: [Color(0xFF0C2A4A), Color(0xFF041525)],
    icon: Icons.auto_awesome_rounded,
    ctaColors: [Color(0xFFFFDF73), Color(0xFFF59E0B), Color(0xFFD97706)],
    ctaShadowColor: Color(0xFF78350F),
    ctaTextColor: Color(0xFF451A03),
  ),
  _BundleItem(
    id: 'pack_champion',
    title: 'باقة الأبطال الملكية',
    subtitle: 'أعلى قيمة وسيطرة لنجوم الصدارة',
    multiplier: 'أعلى توفير 💎',
    coins: 100000,
    gems: 1800,
    price: r'$9.99',
    originalPrice: r'$24.99',
    tag: 'الباقة الملكية 👑',
    tagColor: Color(0xFFF59E0B),
    colors: [Color(0xFF381A02), Color(0xFF1A0A00)],
    icon: Icons.workspace_premium_rounded,
    ctaColors: [Color(0xFFFFE082), Color(0xFFF59E0B), Color(0xFFB45309)],
    ctaShadowColor: Color(0xFF78350F),
    ctaTextColor: Color(0xFF451A03),
  ),
];

class _GemStoreItem {
  const _GemStoreItem({
    required this.id,
    required this.title,
    required this.gems,
    required this.price,
    required this.tag,
    required this.tagColor,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String title;
  final int gems;
  final String price;
  final String tag;
  final Color tagColor;
  final List<Color> colors;
  final IconData icon;
}

const List<_GemStoreItem> _kGemStoreItems = <_GemStoreItem>[
  _GemStoreItem(
    id: 'gems_80',
    title: 'كيس جواهر صغير',
    gems: 80,
    price: r'$0.99',
    tag: 'شحن سريع 💎',
    tagColor: Color(0xFF38BDF8),
    colors: [Color(0xFF0C2A4A), Color(0xFF041525)],
    icon: Icons.diamond_outlined,
  ),
  _GemStoreItem(
    id: 'gems_500',
    title: 'صندوق جواهر متوسط',
    gems: 500,
    price: r'$4.99',
    tag: 'الأكثر طلباً ⭐',
    tagColor: Color(0xFFF59E0B),
    colors: [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
    icon: Icons.diamond_rounded,
  ),
  _GemStoreItem(
    id: 'gems_1200',
    title: 'حقيبة جواهر كبيرة',
    gems: 1200,
    price: r'$9.99',
    tag: 'أعلى توفير 🔥',
    tagColor: Color(0xFF10B981),
    colors: [Color(0xFF064E3B), Color(0xFF022C22)],
    icon: Icons.all_inclusive_rounded,
  ),
];


class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _busy = false;
  void Function(String)? _onProductDelivered;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final iap = context.read<InAppPurchaseService>();
      _onProductDelivered = (productId) {
        if (!mounted) return;
        final appState = context.read<AppState>();
        appState.loadCategoryState();
        appState.loadCurrency();
        _showSnack('تم استلام مشترياتك وتحديث رصيدك بنجاح! 🎉');
      };
      iap.addDeliveryListener(_onProductDelivered!);
    });
  }

  @override
  void dispose() {
    if (_onProductDelivered != null) {
      try {
        context
            .read<InAppPurchaseService>()
            .removeDeliveryListener(_onProductDelivered!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _haptic() async {
    await context.read<AppSettings>().playHaptic();
  }

  Future<void> _openCharacters() async {
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    await _haptic();
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const CharacterSelectScreen()),
    );
    if (!mounted) return;
    await appState.loadCharacterState();
    await appState.loadCurrency();
  }

  Future<void> _watchRewardedAd() async {
    if (_busy) return;
    final adService = context.read<AdService>();
    final native = context.read<NativeBridgeService>();
    final appState = context.read<AppState>();
    await _haptic();

    if (!adService.canWatchAd) {
      final remaining = adService.cooldownRemaining;
      _showSnack(
        adService.watchesLeft == 0
            ? 'وصلت إلى الحد اليومي للإعلانات المكافأة.'
            : 'الإعلان التالي بعد ${_formatDuration(remaining)}.',
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);
    final reward = await adService.showRewardedAd();
    if (!mounted) return;
    setState(() => _busy = false);

    if (reward == null) {
      _showSnack('تعذر تشغيل الإعلان أو تم إغلاقه قبل اكتماله.', isError: true);
      return;
    }

    try {
      await native.grantCurrency(
        coins: reward['coins'] ?? 0,
        gems: reward['gems'] ?? 0,
      );
      await appState.loadCurrency();
    } catch (_) {
      if (!mounted) return;
      _showSnack('اكتمل الإعلان، لكن تعذر تسليم المكافأة الآن.', isError: true);
      return;
    }

    if (!mounted) return;
    showCurrencyRewardOverlay(
      context,
      coins: reward['coins'] ?? 0,
      gems: reward['gems'] ?? 0,
    );
  }

  Future<void> _buyCoins(_CoinItem item) async {
    if (_busy) return;
    final appState = context.read<AppState>();
    final native = context.read<NativeBridgeService>();
    await _haptic();

    if (appState.gems < item.gemCost) {
      _showSnack('رصيد الجواهر غير كاف لهذه الحزمة.', isError: true);
      return;
    }

    final ok = await _confirm(
      'تأكيد التحويل',
      'تحويل ${_compactNumber(item.gemCost)} جوهرة إلى ${item.label} كوين؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final success = await native.buyCurrency(
        coinAmount: item.coinAmount,
        gemCost: item.gemCost,
      );
      if (!mounted) return;
      if (success) {
        await appState.loadCurrency();
        _showSnack('تمت إضافة ${item.label} كوين.');
      } else {
        _showSnack('فشلت عملية التحويل.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ أثناء العملية: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rentCategory(GameCategory cat) async {
    if (_busy) return;
    final adService = context.read<AdService>();
    final appState = context.read<AppState>();
    await _haptic();

    setState(() => _busy = true);
    try {
      final watched = await adService.showActionRewardedAd();
      if (!mounted) return;

      if (!watched) {
        _showSnack('تعذر تشغيل الإعلان أو تم إغلاقه قبل اكتماله.', isError: true);
        return;
      }

      final success = await appState.rentCategoryWithAd(cat.name, hours: 24);
      if (!mounted) return;
      if (success) {
        _showSnack('تم فتح فئة "${cat.name}" لمدة 24 ساعة! 🎉');
      } else {
        _showSnack('حدث خطأ أثناء تفعيل الفئة.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockCategory(GameCategory cat) async {
    if (_busy) return;
    final appState = context.read<AppState>();
    await _haptic();

    if (appState.gems < cat.gemCost) {
      _showSnack('رصيد الجواهر غير كافٍ (تحتاج ${cat.gemCost} جوهرة).', isError: true);
      return;
    }

    final ok = await _confirm(
      'امتلاك الفئة للأبد',
      'فتح فئة "${cat.name}" بشكل دائم مقابل ${cat.gemCost} جوهرة؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final success = await appState.unlockCategoryWithGems(cat.name, gemCost: cat.gemCost);
      if (!mounted) return;
      if (success) {
        _showSnack('تم شراء فئة "${cat.name}" بشكل دائم! 🎉');
      } else {
        _showSnack('فشلت عملية الشراء.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyBundle(_BundleItem bundle) async {
    if (_busy) return;
    final iap = context.read<InAppPurchaseService>();
    await _haptic();

    final ok = await _confirm(
      bundle.title,
      'تأكيد الحصول على ${bundle.title} (${bundle.coins} كوين + ${bundle.gems} جوهرة) مقابل ${bundle.price}؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final success = await iap.buyProduct(bundle.id);
      if (!mounted) return;
      if (!success) {
        final exp = iap.getExplanation(bundle.id);
        _showSnack(exp.isNotEmpty ? exp : 'تعذر إتمام عملية الشراء.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('حدث خطأ أثناء الاتصال بالمتجر: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyVipPass() async {
    if (_busy) return;
    final appState = context.read<AppState>();
    final iap = context.read<InAppPurchaseService>();
    await _haptic();

    if (appState.isVip) {
      _showSnack('العضوية المميزة VIP مفعلة بالفعل على حسابك! 👑');
      return;
    }

    final ok = await _confirm(
      'اشتراك VIP المميز',
      'تفعيل اشتراك VIP (فتح جميع الفئات الـ 45 + بدون إعلانات + 5,000 كوين + 500 جوهرة) مقابل 4.99\$ شهرياً؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final vipId = iap.products.containsKey('vip_monthly')
        ? 'vip_monthly'
        : (iap.products.containsKey('vip_pass') ? 'vip_pass' : 'vip_monthly');
    try {
      final success = await iap.buyProduct(vipId);
      if (!mounted) return;
      if (!success) {
        final exp = iap.getExplanation(vipId);
        _showSnack(exp.isNotEmpty ? exp : 'تعذر تفعيل العضوية المميزة.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('حدث خطأ أثناء الاتصال بالمتجر: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyGemItem(_GemStoreItem item) async {
    if (_busy) return;
    final iap = context.read<InAppPurchaseService>();
    await _haptic();

    final ok = await _confirm(
      item.title,
      'تأكيد شراء ${item.title} (${item.gems} جوهرة) مقابل ${item.price}؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final success = await iap.buyProduct(item.id);
      if (!mounted) return;
      if (!success) {
        final exp = iap.getExplanation(item.id);
        _showSnack(exp.isNotEmpty ? exp : 'تعذر إتمام عملية الشراء.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('حدث خطأ أثناء الاتصال بالمتجر: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF081328),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              content: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'تأكيد',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final adService = context.watch<AdService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF071126),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset('assets/ui/bg_main.png', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF030712).withValues(alpha: 0.56),
                      const Color(0xFF071126).withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _Header(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: _StoreDashboard(
                      coins: appState.coins,
                      gems: appState.gems,
                      adService: adService,
                      selectedCharacter: appState.selectedCharacter,
                      unlockedCharacters: CharacterCatalog.all
                          .where(appState.isCharacterUnlocked)
                          .length,
                      busy: _busy,
                      appState: appState,
                      onOpenCharacters: _openCharacters,
                      onWatchAd: _watchRewardedAd,
                      onBuyCoins: _buyCoins,
                      onRentCategory: _rentCategory,
                      onUnlockCategory: _unlockCategory,
                      onBuyBundle: _buyBundle,
                      onBuyGem: _buyGemItem,
                      onBuyVip: _buyVipPass,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.16),
                    child: const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFFACC15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreDashboard extends StatelessWidget {
  const _StoreDashboard({
    required this.coins,
    required this.gems,
    required this.adService,
    required this.selectedCharacter,
    required this.unlockedCharacters,
    required this.busy,
    required this.appState,
    required this.onOpenCharacters,
    required this.onWatchAd,
    required this.onBuyCoins,
    required this.onRentCategory,
    required this.onUnlockCategory,
    required this.onBuyBundle,
    required this.onBuyGem,
    required this.onBuyVip,
  });

  final int coins;
  final int gems;
  final AdService adService;
  final GameCharacter selectedCharacter;
  final int unlockedCharacters;
  final bool busy;
  final AppState appState;
  final VoidCallback onOpenCharacters;
  final VoidCallback onWatchAd;
  final void Function(_CoinItem item) onBuyCoins;
  final void Function(GameCategory cat) onRentCategory;
  final void Function(GameCategory cat) onUnlockCategory;
  final void Function(_BundleItem bundle) onBuyBundle;
  final void Function(_GemStoreItem item) onBuyGem;
  final VoidCallback onBuyVip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 760 ? 12.0 : 16.0;
        final gap = constraints.maxWidth < 760 ? 10.0 : 12.0;
        final bundleColumns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
                ? 2
                : 1;
        final coinColumns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
        final categoryColumns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 520
                    ? 3
                    : constraints.maxWidth >= 330
                        ? 2
                        : 1;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                2,
                horizontalPadding,
                14,
              ),
              sliver: SliverToBoxAdapter(
                child: _StoreOverview(
                  coins: coins,
                  gems: gems,
                  adService: adService,
                  selectedCharacter: selectedCharacter,
                  unlockedCharacters: unlockedCharacters,
                  busy: busy,
                  onOpenCharacters: onOpenCharacters,
                  onWatchAd: onWatchAd,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                14,
              ),
              sliver: SliverToBoxAdapter(
                child: _VipPassCard(
                  isVip: appState.isVip,
                  busy: busy,
                  onTap: onBuyVip,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.local_fire_department_rounded,
                  title: 'العروض الحصرية والباقات',
                  subtitle: 'أفضل قيمة لتعزيز رصيدك فوراً وشراء ما تريد',
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                18,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: bundleColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: bundleColumns == 1
                      ? 126
                      : bundleColumns == 2
                          ? 190
                          : 200,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final bundle = _kSpecialBundles[index];
                    return _BundleCard(
                      bundle: bundle,
                      busy: busy,
                      onTap: () => onBuyBundle(bundle),
                    );
                  },
                  childCount: _kSpecialBundles.length,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.diamond_rounded,
                  title: 'باقات الجواهر',
                  subtitle: 'اشحن الجواهر مباشرة لفتح الفئات وتطوير حسابك',
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                18,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: bundleColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: bundleColumns == 1
                      ? 110
                      : bundleColumns == 2
                          ? 180
                          : 190,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final gemItem = _kGemStoreItems[index];
                    return _GemStoreCard(
                      item: gemItem,
                      busy: busy,
                      onTap: () => onBuyGem(gemItem),
                    );
                  },
                  childCount: _kGemStoreItems.length,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  title: 'الفئات المميزة',
                  subtitle: 'استأجر 24 ساعة بمشاهدة إعلان 🎥 أو امتلكها للأبد 💎',
                  color: Color(0xFFFACC15),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                20,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: categoryColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: 148,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = CategoryCatalog.premiumCategories[index];
                    return _CategoryStoreCard(
                      category: cat,
                      isUnlocked: appState.isCategoryUnlocked(cat.name),
                      hoursLeft: appState.getCategoryRemainingRentalHours(cat.name),
                      isPermanent: appState.isVip ||
                          appState.unlockedCategories.any(
                              (u) => GameCategory.normalize(u) == GameCategory.normalize(cat.name)),
                      busy: busy,
                      onRent: () => onRentCategory(cat),
                      onUnlock: () => onUnlockCategory(cat),
                    );
                  },
                  childCount: CategoryCatalog.premiumCategories.length,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.currency_exchange_rounded,
                  title: 'تحويل الجواهر',
                  subtitle: 'حوّل الجواهر إلى كوين لفتح الشخصيات',
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                22,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: coinColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: 168,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _kCoinItems[index];
                    return _CoinPackCard(
                      item: item,
                      affordable: gems >= item.gemCost,
                      busy: busy,
                      onTap: () => onBuyCoins(item),
                    );
                  },
                  childCount: _kCoinItems.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'المتجر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'الشخصيات، الرصيد، وتحويل الجواهر',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'رجوع',
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOverview extends StatelessWidget {
  const _StoreOverview({
    required this.coins,
    required this.gems,
    required this.adService,
    required this.selectedCharacter,
    required this.unlockedCharacters,
    required this.busy,
    required this.onOpenCharacters,
    required this.onWatchAd,
  });

  final int coins;
  final int gems;
  final AdService adService;
  final GameCharacter selectedCharacter;
  final int unlockedCharacters;
  final bool busy;
  final VoidCallback onOpenCharacters;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final wallet = _WalletPanel(coins: coins, gems: gems);
        final characters = _CharacterStorePanel(
          character: selectedCharacter,
          unlockedCharacters: unlockedCharacters,
          onOpen: onOpenCharacters,
        );
        final ads = _AdRewardPanel(
          adService: adService,
          busy: busy,
          onWatchAd: onWatchAd,
        );

        if (!wide) {
          return Column(
            children: <Widget>[
              wallet,
              const SizedBox(height: 10),
              characters,
              const SizedBox(height: 10),
              ads,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 5, child: wallet),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: characters),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: ads),
            ],
          ),
        );
      },
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel({
    required this.coins,
    required this.gems,
  });

  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(accent: const Color(0xFFFACC15)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFACC15),
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'رصيدك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'الرصيد المستخدم لفتح الشخصيات',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _BalanceCard(
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFFACC15),
                  value: _compactNumber(coins),
                  label: 'كوين',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceCard(
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFF38BDF8),
                  value: _compactNumber(gems),
                  label: 'جوهرة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterStorePanel extends StatelessWidget {
  const _CharacterStorePanel({
    required this.character,
    required this.unlockedCharacters,
    required this.onOpen,
  });

  final GameCharacter character;
  final int unlockedCharacters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(accent: character.color),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: character.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: character.color.withValues(alpha: 0.38),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  character.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: character.color,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'الشخصيات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'المختار: ${character.nameAr}',
                      style: TextStyle(
                        color: character.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _TagPill(
                text: '$unlockedCharacters/${CharacterCatalog.all.length}',
                color: character.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            character.tagAr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.groups_rounded,
            label: 'فتح وتغيير الشخصيات',
            color: const Color(0xFF4338CA),
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _AdRewardPanel extends StatelessWidget {
  const _AdRewardPanel({
    required this.adService,
    required this.busy,
    required this.onWatchAd,
  });

  final AdService adService;
  final bool busy;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    final progress =
        (adService.watchesToday / AdService.maxDailyWatches).clamp(0.0, 1.0);
    final canWatch = adService.canWatchAd && !busy;
    final status = adService.watchesLeft == 0
        ? 'اكتمل حد الإعلانات اليومي'
        : adService.cooldownRemaining > Duration.zero
            ? 'الإعلان التالي بعد ${_formatDuration(adService.cooldownRemaining)}'
            : '${adService.watchesLeft} إعلانات متاحة اليوم';

    return Container(
      decoration: _panelDecoration(accent: const Color(0xFF34D399)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.ondemand_video_rounded,
                  color: Color(0xFF34D399),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'مكافأة الإعلان',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.09),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF34D399),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'شاهد إعلاناً',
            color: const Color(0xFF166534),
            onTap: canWatch ? onWatchAd : null,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          height: 2,
          width: 76,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({
    required this.item,
    required this.affordable,
    required this.busy,
    required this.onTap,
  });

  final _CoinItem item;
  final bool affordable;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = affordable && !busy;
    final rate = (item.coinAmount / item.gemCost).round();

    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Container(
        decoration: _panelDecoration(
          accent:
              affordable ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFACC15),
                    size: 24,
                  ),
                ),
                const Spacer(),
                _TagPill(text: item.tag, color: const Color(0xFF38BDF8)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item.label} كوين',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              '${_compactNumber(item.gemCost)} جوهرة  •  $rate كوين لكل جوهرة',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            _ActionButton(
              icon: enabled ? Icons.add_rounded : Icons.lock_rounded,
              label: enabled ? 'تحويل الآن' : 'جواهر غير كافية',
              color:
                  enabled ? const Color(0xFF0369A1) : const Color(0xFF374151),
              onTap: enabled ? onTap : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.48 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({required Color accent}) {
  return BoxDecoration(
    color: const Color(0xFF081328).withValues(alpha: 0.84),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: accent.withValues(alpha: 0.27)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _compactNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 1000000) {
    final number = abs / 1000000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    final number = abs / 1000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}K';
  }
  return value.toString();
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) return 'الآن';
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes';
  }
  return '$minutes:$seconds';
}

class _VipPassCard extends StatelessWidget {
  const _VipPassCard({
    required this.isVip,
    this.busy = false,
    this.onTap,
  });

  final bool isVip;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1702),
            Color(0xFF0F0E17),
            Color(0xFF1A1404),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.70),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.4),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 40,
              right: 40,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFFDF73).withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAB308).withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFDF73),
                              Color(0xFFD97706),
                              Color(0xFF78350F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFFE082),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFF1E1402),
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'العضوية الملكية VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isVip
                                          ? [const Color(0xFF10B981), const Color(0xFF047857)]
                                          : [const Color(0xFFF59E0B), const Color(0xFFB45309)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isVip ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    isVip ? 'مفعلة بالكامل ✓' : 'عرض حصري 🔥',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'امتيازات لا نهائية للاعبين النخبة لتجربة لعب أسطورية بدون قيود',
                              style: TextStyle(
                                color: Color(0xFFFFDF73),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _VipPerkBadge(
                        icon: Icons.lock_open_rounded,
                        label: '45 فئة مفتوحة مجاناً',
                        color: Color(0xFF38BDF8),
                      ),
                      _VipPerkBadge(
                        icon: Icons.block_rounded,
                        label: 'بدون إعلانات بينية',
                        color: Color(0xFFF43F5E),
                      ),
                      _VipPerkBadge(
                        icon: Icons.diamond_rounded,
                        label: '+500 جوهرة شهرياً',
                        color: Color(0xFF34D399),
                      ),
                      _VipPerkBadge(
                        icon: Icons.monetization_on_rounded,
                        label: '+5,000 كوين فوري',
                        color: Color(0xFFFACC15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isVip)
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'اشتراك VIP نشط ويمنحك جميع المزايا',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFE082),
                            Color(0xFFF59E0B),
                            Color(0xFFD97706),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0xFF78350F),
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                            offset: const Offset(0, 6),
                            blurRadius: 14,
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFFFF7ED),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: busy ? null : onTap,
                          borderRadius: BorderRadius.circular(14),
                          splashColor: Colors.white24,
                          child: Center(
                            child: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF451A03),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 22,
                                        color: Color(0xFF451A03),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'تفعيل العضوية الملكية 4.99\$ 👑',
                                        style: TextStyle(
                                          color: Color(0xFF451A03),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipPerkBadge extends StatelessWidget {
  const _VipPerkBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.busy,
    required this.onTap,
  });

  final _BundleItem bundle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 330;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                bundle.colors[0],
                bundle.colors[1],
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bundle.tagColor.withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: bundle.tagColor.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.5),
            child: Stack(
              children: [
                // Top Gloss Reflection Line
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          bundle.tagColor.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Internal Radial Glow
                Positioned(
                  top: isWide ? 10 : 25,
                  right: isWide ? 10 : null,
                  left: isWide ? null : 15,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: bundle.tagColor.withValues(alpha: 0.22),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: isWide
                      ? _buildWideLayout(context)
                      : _buildVerticalShowcaseLayout(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalShowcaseLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Badges Row (Discount Ribbon on start, Multiplier on end)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bundle.tagColor.withValues(alpha: 0.95),
                    bundle.tagColor.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: bundle.tagColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                bundle.tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (bundle.multiplier.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.75),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  bundle.multiplier,
                  style: const TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // 2. Title and Emblem Row
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    bundle.tagColor.withValues(alpha: 0.85),
                    bundle.tagColor.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: bundle.tagColor.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bundle.tagColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  bundle.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bundle.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      bundle.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 3. High-Contrast Reward Showcase Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD66B), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${bundle.coins}',
                    style: const TextStyle(
                      color: Color(0xFFFFD66B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                '+',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFF7DD3FC), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${bundle.gems}',
                    style: const TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        // 4. Strikethrough & High-Impact 3D Buy Button
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'بدلاً من',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    bundle.originalPrice,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Color(0xFFEF4444),
                      decorationThickness: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _TactileBundleButton(
                price: bundle.price,
                colors: bundle.ctaColors,
                shadowColor: bundle.ctaShadowColor,
                textColor: bundle.ctaTextColor,
                busy: busy,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                bundle.tagColor.withValues(alpha: 0.85),
                bundle.tagColor.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: bundle.tagColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: bundle.tagColor.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              bundle.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    bundle.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bundle.tagColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bundle.tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (bundle.multiplier.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFFFACC15).withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        bundle.multiplier,
                        style: const TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (bundle.subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  bundle.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD66B), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${bundle.coins}',
                          style: const TextStyle(
                            color: Color(0xFFFFD66B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.diamond_rounded, color: Color(0xFF7DD3FC), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${bundle.gems}',
                          style: const TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              bundle.originalPrice,
              style: const TextStyle(
                color: Color(0xFFF87171),
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFFEF4444),
                decorationThickness: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            _TactileBundleButton(
              price: bundle.price,
              colors: bundle.ctaColors,
              shadowColor: bundle.ctaShadowColor,
              textColor: bundle.ctaTextColor,
              busy: busy,
              onTap: onTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _GemStoreCard extends StatelessWidget {
  const _GemStoreCard({
    required this.item,
    required this.busy,
    required this.onTap,
  });

  final _GemStoreItem item;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 330;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.colors[0],
                item.colors[1],
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.tagColor.withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: item.tagColor.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: isWide ? _buildWideLayout(context) : _buildVerticalLayout(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                item.tagColor.withValues(alpha: 0.85),
                item.tagColor.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: item.tagColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: item.tagColor.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              item.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.tagColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    '${item.gems} جوهرة',
                    style: const TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: _TactileBundleButton(
            price: item.price,
            colors: const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)],
            shadowColor: const Color(0xFF0C4A6E),
            textColor: Colors.white,
            busy: busy,
            onTap: onTap,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: item.tagColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: item.tagColor.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Text(
                item.tag,
                style: TextStyle(
                  color: item.tagColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(item.icon, color: const Color(0xFF7DD3FC), size: 18),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond_rounded, color: Color(0xFF7DD3FC), size: 14),
              const SizedBox(width: 4),
              Text(
                '${item.gems} جوهرة',
                style: const TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _TactileBundleButton(
          price: item.price,
          colors: const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)],
          shadowColor: const Color(0xFF0C4A6E),
          textColor: Colors.white,
          busy: busy,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _TactileBundleButton extends StatelessWidget {
  const _TactileBundleButton({
    required this.price,
    required this.busy,
    required this.onTap,
    this.colors = const [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF15803D)],
    this.shadowColor = const Color(0xFF14532D),
    this.textColor = Colors.white,
  });

  final String price;
  final bool busy;
  final VoidCallback onTap;
  final List<Color> colors;
  final Color shadowColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 88),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
          BoxShadow(
            color: colors[0].withValues(alpha: 0.45),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.white24,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: textColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        color: textColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'شراء $price',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStoreCard extends StatelessWidget {
  const _CategoryStoreCard({
    required this.category,
    required this.isUnlocked,
    required this.hoursLeft,
    required this.isPermanent,
    required this.busy,
    required this.onRent,
    required this.onUnlock,
  });

  final GameCategory category;
  final bool isUnlocked;
  final int hoursLeft;
  final bool isPermanent;
  final bool busy;
  final VoidCallback onRent;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final statusColor = isPermanent
        ? const Color(0xFF10B981)
        : hoursLeft > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF38BDF8);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F1D36),
            Color(0xFF081224),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPermanent
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : hoursLeft > 0
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                  : const Color(0xFF38BDF8).withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPermanent
                    ? const Color(0xFF10B981)
                    : hoursLeft > 0
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF0284C7))
                .withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Illustration Artwork Showcase Container
          Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF14243B),
                  Color(0xFF0B1424),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.28),
                width: 0.9,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle colored glow behind the artwork token
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Centered artwork illustration - full aspect ratio, perfectly proportioned
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  child: Image.asset(
                    category.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.category_rounded,
                        color: Color(0xFF94A3B8),
                        size: 28,
                      );
                    },
                  ),
                ),
                // Floating Category Tag (Top-Start)
                if (category.tag.isNotEmpty)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFFFACC15).withValues(alpha: 0.75),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        category.tag,
                        style: const TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                // Floating Lock/Unlock Status Icon (Top-End)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.8),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      isPermanent
                          ? Icons.workspace_premium_rounded
                          : (hoursLeft > 0 ? Icons.timer_rounded : Icons.lock_rounded),
                      size: 11,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Category Title
          Text(
            category.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Actions / Status Banner
          if (isPermanent)
            Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'مفتوحة للأبد ✓',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else if (hoursLeft > 0)
            Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_rounded, color: Color(0xFFFACC15), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'متبقي $hoursLeft ساعة',
                    style: const TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // 3D Rent 24h with Ad Button
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF38BDF8),
                          Color(0xFF0284C7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF075985),
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFBAE6FD),
                        width: 0.8,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: busy ? null : onRent,
                        borderRadius: BorderRadius.circular(8),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                              SizedBox(width: 3),
                              Text(
                                '24س مجاناً',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // 3D Permanent Unlock with Gems Button
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFDF73),
                          Color(0xFFF59E0B),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF92400E),
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFFEF08A),
                        width: 0.8,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: busy ? null : onUnlock,
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.diamond_rounded, color: Color(0xFF451A03), size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${category.gemCost}',
                                style: const TextStyle(
                                  color: Color(0xFF451A03),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
