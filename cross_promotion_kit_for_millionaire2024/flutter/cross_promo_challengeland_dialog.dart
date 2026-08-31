import 'package:flutter/material.dart';

/// ويدجت ترويج للعبة "تحدي المليون" داخل مشروع "من سيربح المليون" إذا كان مبنياً بفلاتر.
/// الاستدعاء: CrossPromoChallengeLandDialog.show(context);
class CrossPromoChallengeLandDialog extends StatelessWidget {
  const CrossPromoChallengeLandDialog({super.key});

  static const String targetPackage = 'com.qi7bali.landchallengeonline';
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline';

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CrossPromoChallengeLandDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF070F26)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                blurRadius: 28,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🎮 لعبة أونلاين مميزة نقترحها لك',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/ui/million_challenge_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تحدي المليون - أونلاين',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'المسابقات الثقافية الحية، تحدي الأصدقاء وغرف الأونلاين',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Game Modes Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔥 أوضاع اللعب الممتعة:',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('• وضع البرق ⚡ - أجب بأسرع ما يمكن قبل نفاد الوقت',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(height: 4),
                      Text('• وضع البقاء 💪 - استمر دون أخطاء أطول فترة ممكنة',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(height: 4),
                      Text(
                          '• وضع المعركة ⚔️ - تنافس مباشرة مع لاعب آخر في الوقت الحقيقي',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(height: 4),
                      Text('• وضع فريق المعركة 🤝 - تعاون مع فريقك لتحقيق الفوز',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(height: 4),
                      Text('• وضع السلسلة 🔗 - تحديات متتالية تختبر صمودك',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(height: 4),
                      Text('• وضع الإقصاء 🏆 - خطأ واحد يُخرجك من اللعبة',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'تثبيت مجاناً من Google Play 🚀',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
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
