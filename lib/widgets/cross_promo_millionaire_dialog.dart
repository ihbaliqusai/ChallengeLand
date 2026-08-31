import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cross_promo_service.dart';

class CrossPromoMillionaireDialog extends StatefulWidget {
  const CrossPromoMillionaireDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const CrossPromoMillionaireDialog(),
    );
  }

  @override
  State<CrossPromoMillionaireDialog> createState() =>
      _CrossPromoMillionaireDialogState();
}

class _CrossPromoMillionaireDialogState
    extends State<CrossPromoMillionaireDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _loadingStatus = true;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _checkInstall();
  }

  Future<void> _checkInstall() async {
    final promoService = context.read<CrossPromoService>();
    final installed = await promoService.checkInstallation();
    if (mounted) {
      setState(() {
        _isInstalled = installed;
        _loadingStatus = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final promoService = context.read<CrossPromoService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isLandscape ? 540 : media.size.width * 0.92,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF0A1026),
                  Color(0xFF060919),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 35,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Decorative top gold glow
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: Close Button & Tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.military_tech_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'لعبة مميزة مقترحة لك',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded),
                              color: Colors.white70,
                              onPressed: () {
                                promoService.markDismissed();
                                Navigator.of(context).pop();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                shape: const CircleBorder(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Game Info Banner
                        Row(
                          children: [
                            // App Icon Frame
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFDE68A),
                                    Color(0xFFD97706),
                                    Color(0xFF78350F),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13.5),
                                child: Image.asset(
                                  'assets/ui/million_challenge_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: const Center(
                                      child: Icon(
                                        Icons.emoji_events_rounded,
                                        size: 40,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // Title and short bio
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    CrossPromoService.millionaireTitle,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CrossPromoService.millionaireSubtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Stats Chips
                                  Row(
                                    children: [
                                      _buildStatPill(
                                        icon: Icons.star_rounded,
                                        iconColor: const Color(0xFFFBBF24),
                                        text: '4.8 ★',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatPill(
                                        icon: Icons.download_rounded,
                                        iconColor: const Color(0xFF38BDF8),
                                        text: '+100',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatPill(
                                        icon: Icons.verified_rounded,
                                        iconColor: const Color(0xFF34D399),
                                        text: 'مجانية',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Features Showcase Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFeatureRow(
                                icon: Icons.psychology_rounded,
                                color: const Color(0xFFFBBF24),
                                text: 'أكثر من 50,000 سؤال ثقافي ومعرفي متجدد',
                              ),
                              const SizedBox(height: 6),
                              _buildFeatureRow(
                                icon: Icons.graphic_eq_rounded,
                                color: const Color(0xFF38BDF8),
                                text:
                                    'مؤثرات صوتية وموسيقية تحاكي البرنامج التلفزيوني',
                              ),
                              const SizedBox(height: 6),
                              _buildFeatureRow(
                                icon: Icons.support_agent_rounded,
                                color: const Color(0xFFA78BFA),
                                text: 'جميع وسائل المساعدة (50:50، رأي الجمهور، اتصال)',
                              ),
                              const SizedBox(height: 6),
                              _buildFeatureRow(
                                icon: Icons.wifi_off_rounded,
                                color: const Color(0xFF34D399),
                                text: 'العب دون الحاجة للاتصال بالإنترنت في أي وقت',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // CTA Button with Animated Glowing Effect
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, _) {
                            final glowValue = 0.3 + _pulseCtrl.value * 0.45;
                            final isInst = _isInstalled;

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isInst
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFF59E0B))
                                        .withValues(alpha: glowValue),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  await promoService.openMillionaireApp();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInst
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isInst
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFDE68A),
                                      width: 1.5,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isInst
                                          ? Icons.sports_esports_rounded
                                          : Icons.file_download_outlined,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _loadingStatus
                                          ? 'جاري التحقق...'
                                          : (isInst
                                              ? 'فتح اللعبة واللعب الآن 🎮'
                                              : 'تثبيت مجاناً من Google Play 🚀'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
