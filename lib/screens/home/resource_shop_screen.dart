import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_state.dart';
import '../../models/store_catalog.dart';
import '../../services/in_app_purchase_service.dart';
import '../../services/ad_service.dart';

class ResourceShopScreen extends StatefulWidget {
  const ResourceShopScreen({super.key});
  @override
  State<ResourceShopScreen> createState() => _ResourceShopScreenState();
}

class _ResourceShopScreenState extends State<ResourceShopScreen> {
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadEconomy();
      context.read<InAppPurchaseService>().loadProducts();
    });
  }

  Future<void> _buy(Map<String, dynamic> data) async {
    if (_busy || context.read<InAppPurchaseService>().isPurchasing) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AppState>().economyAction(data);
      if (mounted) setState(() => _message = 'تمت إضافة الرصيد.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
      if (mounted) {
        final app = context.read<AppState>();
        await app.loadCurrency();
        await app.loadEconomy();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _iap(StoreProduct product) async {
    final iap = context.read<InAppPurchaseService>();
    if (_busy || iap.isPurchasing) return;
    final details = iap.getProductDetails(product.id);
    if (details == null || !details.available) return;
    final started = await iap.buyProduct(product.id);
    if (!started && mounted) setState(() => _message = iap.error);
  }

  bool _isAdProduct(String id) =>
      id == 'keys_1' || id == 'hearts_1' || id == 'tickets_1';

  String _adResource(StoreProduct product) => product.id.split('_').first;

  Future<void> _claimAd(StoreProduct product) async {
    final resourceKey = switch (product.id) {
      'keys_1' => 'keys',
      'hearts_1' => 'hearts',
      'tickets_1' => 'tickets',
      _ => null,
    };
    if (resourceKey == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final app = context.read<AppState>();
      final uid = app.currentUser?.uid;
      await app.loadEconomy();
      if (!mounted || app.currentUser?.uid != uid) return;
      if (!app.economyLoaded || app.economyError != null) {
        setState(() => _message = 'تعذر تحميل رصيد الإعلانات. حاول مجدداً.');
        return;
      }
      if (app.economyWallet.remainingAdRewards(resourceKey) == 0) {
        setState(() => _message =
            'اكتملت إعلانات هذا المورد لليوم. تتجدد عند منتصف الليل UTC.');
        return;
      }
      AdService? adService;
      try {
        adService = context.read<AdService>();
      } catch (_) {}
      final watched = await adService?.showActionRewardedAd() ?? false;
      if (!mounted || app.currentUser?.uid != uid) return;
      if (!watched) {
        setState(
            () => _message = 'الإعلان غير متاح حالياً أو لم تكتمل مشاهدته.');
        return;
      }
      final granted =
          await context.read<AppState>().claimAdResource(resourceKey);
      if (mounted) {
        setState(() => _message = granted
            ? 'تمت إضافة ${product.title} بنجاح.'
            : 'تعذر إضافة المكافأة. حاول مجدداً.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final iap = context.watch<InAppPurchaseService>();
    final wallet = app.economyWallet;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF170B37),
          appBar: AppBar(
              title: const Text('أرصدة اللعب'),
              centerTitle: true,
              backgroundColor: const Color(0xFF26105C),
              foregroundColor: Colors.white),
          body: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  app.loadEconomy(),
                  app.loadCurrency(),
                  iap.loadProducts()
                ]);
              },
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    children: [
                      ResourceBalance(
                          icon: Icons.key_rounded,
                          label: 'مفاتيح',
                          value: wallet.totalKeys,
                          loaded: app.economyLoaded),
                      ResourceBalance(
                          icon: Icons.confirmation_number_rounded,
                          label: 'تذاكر',
                          value: wallet.tickets,
                          loaded: app.economyLoaded),
                      ResourceBalance(
                          icon: Icons.favorite_rounded,
                          label: 'قلوب',
                          value: wallet.totalHearts,
                          loaded: app.economyLoaded),
                      ResourceBalance(
                          icon: Icons.monetization_on_rounded,
                          label: 'نقود',
                          value: app.coins),
                      ResourceBalance(
                          icon: Icons.diamond_rounded,
                          label: 'جواهر',
                          value: app.gems),
                    ]),
                const SizedBox(height: 12),
                Text(
                    app.economyLoaded
                        ? 'المفاتيح اليومية: ${wallet.dailyKeys} • الإضافية: ${wallet.keys}\nالقلوب اليومية: ${wallet.dailyHearts} • الإضافية: ${wallet.hearts}\nيُستكمل الرصيد اليومي إلى 3 عند منتصف الليل UTC. الأرصدة الإضافية محفوظة.'
                        : 'لم يتم تحميل رصيد الحساب بعد. ستظهر الأرصدة وعروض النقود والجواهر عند الاتصال بخدمة الأرصدة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.6)),
                if (wallet.nextResetMillis > 0)
                  Text(
                      'التجديد القادم: ${DateTime.fromMillisecondsSinceEpoch(wallet.nextResetMillis).toLocal()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                if (_message != null || app.economyError != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_message ?? app.economyError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.amber))),
                if (!app.economyLoaded)
                  Center(
                    child: TextButton(
                        onPressed: _busy ? null : app.loadEconomy,
                        child: const Text('تحميل الأرصدة')),
                  ),
                const SizedBox(height: 16),
                const Text('اشحن بالنقود أو الجواهر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                for (final entry in wallet.offers.entries) ...[
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final offer = Map<String, dynamic>.from(entry.value as Map);
                    final grants = offer['grants'] is Map
                        ? Map<String, dynamic>.from(offer['grants'] as Map)
                        : <String, dynamic>{
                            '${offer['resource']}': offer['amount']
                          };
                    final title = resourceGrantText(grants);
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                      spacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final currency in [
                                          'coins',
                                          'gems'
                                        ])
                                          OutlinedButton(
                                              onPressed: _busy ||
                                                      iap.isPurchasing ||
                                                      !app.economyLoaded ||
                                                      app.economyError != null
                                                  ? null
                                                  : () => _buy({
                                                        'action': 'buy',
                                                        'offerId': entry.key,
                                                        'currency': currency
                                                      }),
                                              child: Text(
                                                  '${offer[currency]} ${currency == 'coins' ? 'قطعة' : 'جوهرة'}')),
                                      ]),
                                ])));
                  }),
                ],
                const SizedBox(height: 24),
                const Text('باقات المتجر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'الدفع المالي عبر Google Play. الشراء بالنقود والجواهر داخل اللعبة متاح في القسم السابق عند تحميل الأرصدة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.6)),
                if (!iap.isLoading &&
                    !StoreCatalog.products
                        .where((p) =>
                            p.kind == StoreProductKind.resource &&
                            !_isAdProduct(p.id))
                        .any((p) =>
                            iap.getProductDetails(p.id)?.available == true))
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'لم تصل أسعار منتجات الأرصدة من Google Play. تحقق من اتصال Google Play وحاول إعادة تحميل الأسعار.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.amber, height: 1.6))),
                Center(
                  child: TextButton.icon(
                      onPressed: iap.isLoading || iap.isPurchasing
                          ? null
                          : iap.loadProducts,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(iap.isLoading
                          ? 'جارٍ تحميل أسعار Google Play…'
                          : 'إعادة تحميل أسعار Google Play')),
                ),
                for (final product in StoreCatalog.products
                    .where((p) => p.kind == StoreProductKind.resource))
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(product.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(product.subtitle,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 10),
                                if (_isAdProduct(product.id))
                                  Center(
                                    child: FilledButton.icon(
                                      key:
                                          ValueKey('resource-ad-${product.id}'),
                                      onPressed: _busy ||
                                              !app.economyLoaded ||
                                              app.economyError != null ||
                                              wallet.remainingAdRewards(
                                                      _adResource(product)) ==
                                                  0
                                          ? null
                                          : () => _claimAd(product),
                                      icon: const Icon(
                                          Icons.play_circle_outline_rounded),
                                      label: Text(wallet.remainingAdRewards(
                                                  _adResource(product)) ==
                                              0
                                          ? 'اكتملت إعلانات اليوم'
                                          : 'مشاهدة إعلان مجاني'),
                                    ),
                                  )
                                else
                                  Center(
                                    child: FilledButton(
                                        onPressed: _busy ||
                                                iap.isPurchasing ||
                                                iap
                                                        .getProductDetails(
                                                            product.id)
                                                        ?.available !=
                                                    true
                                            ? null
                                            : () => _iap(product),
                                        child: Text(iap
                                                .getProductDetails(product.id)
                                                ?.price ??
                                            (iap.isLoading
                                                ? 'جارٍ تحميل السعر…'
                                                : 'سعر Google Play غير متاح'))),
                                  ),
                              ]))),
                if (iap.statusMessage.isNotEmpty)
                  Text(iap.statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.amber)),
                const SizedBox(height: 24),
                const EconomyLoyaltySummary(),
                const SizedBox(height: 16),
                Text(
                    'مكافآت الوفاء\nاليوم 7: مفتاح\nاليوم 14: قلب وتذكرة\nاليوم 21: مفتاح\nاليوم 30: مفتاحان وقلب وتذكرة\nسلسلتك الحالية: ${wallet.streak} يوم\nقسائم الامتلاك: ${wallet.categoryVouchers} • قسائم الاستئجار: ${wallet.rentalVouchers}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.8)),
                const SizedBox(height: 16),
                const Text(
                    'مكافآت تقدمك في المراحل\nكل 20 مرحلة: تذكرة تصنيف\nالمرحلتان 10 و25: مفتاح لكل منهما\nالمرحلتان 50 و75: مفتاح وقلب لكل منهما\nالمرحلة 100: مفتاحان وقسيمة استئجار أسبوعية\nتُمنح جوائز المراحل عند إكمالها أول مرة فقط. تحسين النجوم يمنح فرق مكافأة النقود والجواهر فقط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.8)),
                if (wallet.rewardLog.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('آخر المكافآت المستلمة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber, fontSize: 18)),
                  for (final reward in wallet.rewardLog.reversed)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            '${switch (reward['kind']) {
                              'welcome' => 'هدية البداية • مرة واحدة',
                              'campaign' => 'إنجاز المرحلة ${reward['stage']}',
                              'login' =>
                                'وفاء الدخول • اليوم ${reward['streak']}',
                              _ => 'مهمة اللعب الأسبوعية'
                            }}\n${resourceGrantText(Map<String, dynamic>.from(reward['grants'] as Map? ?? {}))}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, height: 1.6))),
                ],
                const SizedBox(height: 12),
                Text(
                    'إعلانات الموارد اليوم: ${wallet.adRewardLimits['keys'] ?? 0} للمفاتيح، ${wallet.adRewardLimits['hearts'] ?? 0} للقلوب، ${wallet.adRewardLimits['tickets'] ?? 0} للتذاكر وتجربة التصنيفات معاً. يتجدد الحد عند منتصف الليل UTC.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.6)),
                const Text(
                    'مفتاح لكل مباراة كاملة. تذكرة لكل تصنيف مقفل تختاره لمباراة واحدة. خسارة المرحلة تستهلك قلباً والفوز يحافظ عليه.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.6)),
              ])),
        ));
  }
}

String resourceGrantText(Map<String, dynamic> grants) => grants.entries
    .map((entry) => entry.value == 1
        ? switch (entry.key) {
            'keys' => 'مفتاح واحد',
            'hearts' => 'قلب واحد',
            'tickets' => 'تذكرة تصنيف واحدة',
            'categoryVouchers' => 'قسيمة امتلاك تصنيف',
            'rentalVouchers' => 'قسيمة استئجار أسبوعية',
            _ => '${entry.value} ${entry.key}'
          }
        : '${entry.value} ${switch (entry.key) {
            'keys' => 'مفاتيح',
            'hearts' => 'قلوب',
            'tickets' => 'تذاكر تصنيفات',
            'categoryVouchers' => 'قسيمة امتلاك تصنيف',
            'rentalVouchers' => 'قسيمة استئجار أسبوعية',
            _ => entry.key
          }}')
    .join(' + ');

class EconomyLoyaltySummary extends StatelessWidget {
  const EconomyLoyaltySummary({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wallet = app.economyWallet;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('مكافآت اللعب والوفاء',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    app.economyLoaded
                        ? 'دخول متواصل: ${wallet.streak} من 30 يوماً\nاللعب الأسبوعي: ${wallet.weekPlayDays.clamp(0, 3)} / 3 أيام • ${wallet.weekCorrect.clamp(0, 20)} / 20 إجابة صحيحة\n${wallet.weekRewardClaimed ? 'تم استلام مكافأة الأسبوع: مفتاح وتذكرة' : 'المكافأة: مفتاح وتذكرة عند إكمال الهدفين'}'
                        : 'اتصل لتحميل تقدم مكافآت اللعب.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text(
                    'تُضاف مكافآت الوفاء تلقائياً عند الدخول، وتُحفظ الأرصدة المكتسبة. أيام الدخول حسب UTC، وتُعرض تفاصيل الجوائز في أرصدة اللعب.',
                    textAlign: TextAlign.center),
              ],
            )));
  }
}

class ResourceBalance extends StatelessWidget {
  const ResourceBalance(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.loaded = true,
      this.compact = false,
      this.onTap});
  final IconData icon;
  final String label;
  final int value;
  final bool loaded;
  final bool compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label: ${loaded ? value : 'جارٍ التحميل'}',
      button: onTap != null,
      child: Tooltip(
          message: '${loaded ? value : '…'} $label',
          child: Container(
              decoration: BoxDecoration(
                  gradient: compact
                      ? const LinearGradient(colors: [
                          Color(0xFF61452E),
                          Color(0xFFB88749),
                          Color(0xFF61452E)
                        ])
                      : null,
                  color: compact ? null : const Color(0xFF382063),
                  border: compact
                      ? Border.all(color: const Color(0xFFE4BC76), width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(compact ? 8 : 18)),
              child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(compact ? 8 : 18),
                  child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 10,
                              vertical: compact ? 5 : 9),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icon,
                                color: icon == Icons.favorite_rounded
                                    ? Colors.pinkAccent
                                    : Colors.amber,
                                size: compact ? 18 : 20),
                            const SizedBox(width: 5),
                            Flexible(
                                child: Text(
                                    compact
                                        ? '${loaded ? value : '…'}'
                                        : '${loaded ? value : '…'} $label',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ])))))));
}
