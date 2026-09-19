import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../services/in_app_purchase_service.dart';
import '../screens/home/store_screen.dart';

/// نافذة الإعلان الترويجي الحصري بدون سكرول ومقاومة بالكامل لأي overflow في الوضع الأفقي والعمودي
class SpecialOfferDialog extends StatefulWidget {
  const SpecialOfferDialog({super.key});

  static const String _prefsKeyLastShown = 'special_offer_last_shown_time';

  /// إظهار نافذة العرض الترويجي
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SpecialOfferDialog',
      barrierColor: Colors.black.withValues(alpha: 0.84),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim1, anim2) => const SpecialOfferDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.80, end: 1.0).animate(curve),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  /// التحقق من وقت الظهور التلقائي (بحد أقصى مرة كل 12 ساعة)
  static Future<bool> shouldShowAuto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_prefsKeyLastShown) ?? 0;
      if (lastTime == 0) return true;
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
      final diff = DateTime.now().difference(lastDate);
      return diff.inHours >= 12;
    } catch (_) {
      return false;
    }
  }

  /// تسجيل أنه تم عرض النافذة
  static Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyLastShown, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  State<SpecialOfferDialog> createState() => _SpecialOfferDialogState();
}

class _SpecialOfferDialogState extends State<SpecialOfferDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool _busy = false;
  void Function(String)? _onProductDelivered;

  @override
  void initState() {
    super.initState();
    SpecialOfferDialog.markShown();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final iap = context.read<InAppPurchaseService>();
      _onProductDelivered = (productId) {
        if (!mounted) return;
        context.read<AppState>().loadCategoryState();
        context.read<AppState>().loadCurrency();
        _showSnack('تهانينا! تم تفعيل العضوية الملكية VIP بنجاح! 🎉👑');
        Navigator.of(context).pop();
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
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _buyVipOffer() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();

    final appState = context.read<AppState>();
    final iap = context.read<InAppPurchaseService>();

    if (appState.isVip) {
      _showSnack('أنت مشترك بالفعل في العضوية الملكية VIP! 👑');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _busy = true);
    try {
      final vipId = iap.products.containsKey('vip_monthly')
          ? 'vip_monthly'
          : (iap.products.containsKey('vip_pass') ? 'vip_pass' : 'vip_monthly');

      final launched = await iap.buyProduct(vipId);
      if (!mounted) return;

      if (!launched) {
        _showSnack(iap.getExplanation(vipId), isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('حدث خطأ غير متوقع أثناء بدء عملية الشراء.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openStore() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape =
        media.orientation == Orientation.landscape || media.size.height < 520;

    // العرض محسوب بدقة
    final dialogWidth = isLandscape
        ? (media.size.width * 0.62).clamp(330.0, 440.0)
        : (media.size.width * 0.92).clamp(310.0, 390.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isLandscape ? 4 : 8,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: media.size.height * 0.96,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: dialogWidth,
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (context, child) {
                      final animVal = _animCtrl.value;
                      final floatOffset =
                          math.sin(animVal * 2 * math.pi) * (isLandscape ? 2.2 : 3.2);
                      final rayAngle = animVal * 2 * math.pi;
                      final shimmerVal = (animVal * 1.6).clamp(0.0, 1.0);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. وشاح كلاش رويال المقوس (Arch Ribbon) مع زر الإغلاق 3D
                          _buildRibbonHeader(context, isLandscape, shimmerVal),

                          SizedBox(height: isLandscape ? 2 : 3),

                          // 2. البطاقة الذهبية المشعة مع أشعة الضوء المتحركة
                          _buildMainCard(
                            context,
                            isLandscape,
                            floatOffset,
                            rayAngle,
                            shimmerVal,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// الوشاح العلوي الملكي بتصميم كلاش رويال مع زر X البارز
  Widget _buildRibbonHeader(
    BuildContext context,
    bool isLandscape,
    double shimmerVal,
  ) {
    final bannerHeight = isLandscape ? 36.0 : 42.0;
    final closeBtnSize = isLandscape ? 32.0 : 36.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // شريط العنوان المقوس الذهبي والعنابي
        Container(
          height: bannerHeight,
          margin: EdgeInsets.symmetric(horizontal: isLandscape ? 14 : 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4A1002),
                Color(0xFF7F1D1D),
                Color(0xFFB91C1C),
                Color(0xFF7F1D1D),
                Color(0xFF4A1002),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // تأثير وميض الضوء العابر (Shimmer)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FractionallySizedBox(
                    alignment: Alignment(shimmerVal * 2.6 - 1.3, 0),
                    widthFactor: 0.25,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // نص العنوان مع الأيقونات
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFFFFDF73),
                    size: isLandscape ? 17 : 20,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'أفضل صفقة في أرض التحدي!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isLandscape ? 13.5 : 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 1.5),
                        ),
                        Shadow(
                          color: Color(0xFF78350F),
                          blurRadius: 1,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFFFFDF73),
                    size: isLandscape ? 17 : 20,
                  ),
                ],
              ),
            ],
          ),
        ),

        // زر الإغلاق الأحمر 3D البارز
        Positioned(
          left: isLandscape ? 6 : 10,
          top: isLandscape ? 2 : 3,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: closeBtnSize,
              height: closeBtnSize,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFDC2626),
                    Color(0xFF991B1B),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFCA5A5),
                  width: 1.3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF7F1D1D),
                    offset: Offset(0, 2.5),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black45,
                    offset: Offset(0, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: isLandscape ? 18 : 20,
                weight: 800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// البطاقة الذهبية الرئيسية بكافة عناصرها المدمجة
  Widget _buildMainCard(
    BuildContext context,
    bool isLandscape,
    double floatOffset,
    double rayAngle,
    double shimmerVal,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFD97706),
            Color(0xFFB45309),
            Color(0xFF78350F),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFE58F),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.8),
        child: Stack(
          children: [
            // خلفية أشعة الضوء الدوّارة (Rotating Sunburst Rays) خلف التاج
            Positioned(
              top: isLandscape ? -45 : -30,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: rayAngle,
                  child: CustomPaint(
                    size: Size(isLandscape ? 220 : 260, isLandscape ? 220 : 260),
                    painter: _SunburstPainter(),
                  ),
                ),
              ),
            ),

            // المحتوى الداخلي المنسق بدقة بدون سكرول
            Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                isLandscape ? 6 : 8,
                10,
                isLandscape ? 6 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // درع التاج الملكي الطافي بحركة جميلة (Hovering Crown)
                  Transform.translate(
                    offset: Offset(0, floatOffset),
                    child: _buildCrownBadge(isLandscape),
                  ),

                  SizedBox(height: isLandscape ? 6 : 8),

                  // شبكة المكافآت الأسطورية (6 بطاقات مدمجة كما في كلاش رويال)
                  _buildRewardsGrid(isLandscape),

                  SizedBox(height: isLandscape ? 5 : 7),

                  // شريط التلميح الصغير
                  _buildInfoPill(isLandscape),

                  SizedBox(height: isLandscape ? 6 : 8),

                  // الزر الأخضر البارز 3D مع وميض ضوء متحرك (Shimmer)
                  _buildBigGreenButton(isLandscape, shimmerVal),

                  SizedBox(height: isLandscape ? 4 : 5),

                  // رابط المتجر السريع
                  _buildStoreBrowseLink(isLandscape),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// درع التاج الملكي (شعار Pass Royale)
  Widget _buildCrownBadge(bool isLandscape) {
    final badgeWidth = isLandscape ? 56.0 : 64.0;
    final badgeHeight = isLandscape ? 44.0 : 50.0;
    final crownSize = isLandscape ? 30.0 : 36.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // الدرع الذهبي البارز
        Container(
          width: badgeWidth,
          height: badgeHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFDF73),
                Color(0xFFF59E0B),
                Color(0xFFB45309),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: const Color(0xFFFFFBEB),
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF78350F),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black45,
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.workspace_premium_rounded,
              size: crownSize,
              color: const Color(0xFF451A03),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'العضوية الملكية VIP',
          style: TextStyle(
            color: const Color(0xFF451A03),
            fontSize: isLandscape ? 15.5 : 17.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            shadows: const [
              Shadow(
                color: Color(0xFFFFE082),
                offset: Offset(0, 1),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: isLandscape ? 1.5 : 2.0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF451A03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'عرض الترحيب الأسطوري • وفر 80% الآن 🔥',
            style: TextStyle(
              color: const Color(0xFFFFDF73),
              fontSize: isLandscape ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  /// شبكة بطاقات المكافآت
  Widget _buildRewardsGrid(bool isLandscape) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 6 : 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الصف الأول
          Row(
            children: [
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  badgeBg: const Color(0xFF78350F),
                  title: 'عضوية VIP',
                  value: 'دائمة شهرياً',
                  glowColor: const Color(0xFFF59E0B),
                  isLandscape: isLandscape,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.lock_open_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  badgeBg: const Color(0xFF0369A1),
                  title: '45 فئة مفتوحة',
                  value: 'جميع الأسئلة',
                  glowColor: const Color(0xFF0284C7),
                  isLandscape: isLandscape,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.block_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  badgeBg: const Color(0xFF9F1239),
                  title: 'بدون إعلانات',
                  value: 'لعب بدون توقف',
                  glowColor: const Color(0xFFE11D48),
                  isLandscape: isLandscape,
                ),
              ),
            ],
          ),
          SizedBox(height: isLandscape ? 4 : 5),
          // الصف الثاني
          Row(
            children: [
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.diamond_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  badgeBg: const Color(0xFF0C4A6E),
                  title: '500 جوهرة',
                  value: '+500 شهرياً',
                  glowColor: const Color(0xFF38BDF8),
                  isHighlight: true,
                  isLandscape: isLandscape,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.monetization_on_rounded,
                  iconColor: const Color(0xFFFACC15),
                  badgeBg: const Color(0xFF713F12),
                  title: '5,000 كوين',
                  value: 'شحن فوري',
                  glowColor: const Color(0xFFFACC15),
                  isLandscape: isLandscape,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildRewardCard(
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFF34D399),
                  badgeBg: const Color(0xFF064E3B),
                  title: 'مضاعف 2X',
                  value: 'نقاط الصدارة',
                  glowColor: const Color(0xFF10B981),
                  isLandscape: isLandscape,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة مكافأة مدمجة ولامعة
  Widget _buildRewardCard({
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required String title,
    required String value,
    required Color glowColor,
    required bool isLandscape,
    bool isHighlight = false,
  }) {
    final iconBoxSize = isLandscape ? 26.0 : 30.0;
    final iconSize = isLandscape ? 15.5 : 18.0;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isLandscape ? 4.5 : 6.0,
        horizontal: 2.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFFFFDF73)
              : Colors.white.withValues(alpha: 0.16),
          width: isHighlight ? 1.2 : 0.7,
        ),
        boxShadow: [
          if (isHighlight)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 5,
              spreadRadius: 0.5,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // أيقونة 3D بإطار بارز
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.65),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLandscape ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight
                  ? const Color(0xFF7DD3FC)
                  : Colors.white.withValues(alpha: 0.65),
              fontSize: isLandscape ? 7.5 : 8.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// شريط تلميح أنيق وصغير
  Widget _buildInfoPill(bool isLandscape) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isLandscape ? 2.5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFFBAE6FD),
            size: isLandscape ? 11 : 12,
          ),
          const SizedBox(width: 4),
          Text(
            'تفعيل فوري مع إمكانية الإلغاء في أي وقت عبر Google Play',
            style: TextStyle(
              color: const Color(0xFFBAE6FD),
              fontSize: isLandscape ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// الزر الأخضر الضخم 3D مع وميض ضوئي متحرك Shimmer
  Widget _buildBigGreenButton(bool isLandscape, double shimmerVal) {
    final btnHeight = isLandscape ? 42.0 : 48.0;

    return Container(
      width: double.infinity,
      height: btnHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4ADE80),
            Color(0xFF22C55E),
            Color(0xFF16A34A),
            Color(0xFF15803D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: const Color(0xFFDCFCE7),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF14532D),
            offset: Offset(0, 3.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x6622C55E),
            offset: Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // لمعان الضوء المتحرك على الزر (Shimmer Sweep)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment(shimmerVal * 2.6 - 1.3, 0),
                widthFactor: 0.28,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.40),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // المحتوى التفاعلي للزر
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _busy ? null : _buyVipOffer,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white30,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              color: const Color(0xFF052E16),
                              size: isLandscape ? 19 : 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '4.99\$ • تفعيل العرض الآن 👑',
                              style: TextStyle(
                                color: const Color(0xFF052E16),
                                fontSize: isLandscape ? 14.5 : 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xFF86EFAC),
                                    offset: Offset(0, 1),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// رابط تصفح المتجر السريع
  Widget _buildStoreBrowseLink(bool isLandscape) {
    return GestureDetector(
      onTap: _openStore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_rounded,
              color: const Color(0xFFFFDF73),
              size: isLandscape ? 13 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              'استعراض باقي الباقات والجواهر في المتجر 🛒',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: isLandscape ? 10.0 : 11.0,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFFFFDF73),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام أشعة الضوء الدوّارة (Rotating Sunburst Rays) خلف التاج الملكي
class _SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const count = 14;
    const sweep = (2 * math.pi) / (count * 2);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFDF73).withValues(alpha: 0.40),
          const Color(0xFFF59E0B).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final angle = i * 2 * sweep;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
