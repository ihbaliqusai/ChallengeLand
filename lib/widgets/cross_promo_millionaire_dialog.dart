import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../services/cross_promo_service.dart';

class CrossPromoMillionaireDialog extends StatefulWidget {
  const CrossPromoMillionaireDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const CrossPromoMillionaireDialog(),
    );
  }

  @override
  State<CrossPromoMillionaireDialog> createState() =>
      _CrossPromoMillionaireDialogState();
}

class _CrossPromoMillionaireDialogState
    extends State<CrossPromoMillionaireDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;
  final ScrollController _scrollController = ScrollController();
  bool _loadingStatus = true;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _checkInstall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInstall();
    }
  }

  Future<void> _checkInstall() async {
    final promoService = context.read<CrossPromoService>();
    final uid = context.read<AppState>().currentUser?.uid;
    final installed = await promoService.checkInstallation();
    await promoService.checkRewardClaimed(uid: uid);
    if (mounted) {
      setState(() {
        _isInstalled = installed;
        _loadingStatus = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final promoService = context.read<CrossPromoService>();

    final double dialogWidth = isLandscape
        ? (media.size.width * 0.75).clamp(420.0, 560.0)
        : (media.size.width * 0.92).clamp(320.0, 440.0);

    final double maxDialogHeight = media.size.height * 0.88;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF0B1120),
                  Color(0xFF060914),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                  blurRadius: 36,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Ambient Radial Glow Accents
                Positioned(
                  top: -35,
                  right: -35,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -35,
                  left: -35,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    ),
                  ),
                ),

                // Main Layout: Fixed Header + Scrollable Content + Fixed Footer CTA
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pinned Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Luxury Tag Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
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
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'لعبة مميزة مقترحة لك',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Close Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white70,
                            tooltip: 'إغلاق',
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
                    ),

                    // Divider line
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.07),
                    ),

                    // Scrollable Body
                    Flexible(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: false,
                        radius: const Radius.circular(8),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Game Info Banner ─────────────────────────
                              _buildGameInfoBanner(),

                              const SizedBox(height: 14),

                              // ── 80 Gems Reward Banner ─────────────────────
                              _buildRewardCard(promoService),

                              const SizedBox(height: 14),

                              // ── Overview & Categories Card ───────────────
                              _buildOverviewCard(),

                              const SizedBox(height: 16),

                              // ── Game Modes Header ────────────────────────
                              _buildGameModesHeader(),

                              const SizedBox(height: 10),

                              // ── 6 Game Mode Cards ─────────────────────────
                              _buildGameModeCard(
                                emoji: '⚡',
                                title: 'وضع البرق',
                                description:
                                    'أجب بأسرع ما يمكن قبل نفاد الوقت',
                                badgeText: 'سرعة فائقة',
                                primaryColor: const Color(0xFFF59E0B),
                                secondaryColor: const Color(0xFFEAB308),
                              ),
                              const SizedBox(height: 8),

                              _buildGameModeCard(
                                emoji: '💪',
                                title: 'وضع البقاء',
                                description:
                                    'استمر دون أخطاء أطول فترة ممكنة',
                                badgeText: 'تحدي الصمود',
                                primaryColor: const Color(0xFF10B981),
                                secondaryColor: const Color(0xFF059669),
                              ),
                              const SizedBox(height: 8),

                              _buildGameModeCard(
                                emoji: '⚔️',
                                title: 'وضع المعركة',
                                description:
                                    'تنافس مباشرة مع لاعب آخر في الوقت الحقيقي',
                                badgeText: 'مواجهة 1 ضد 1',
                                primaryColor: const Color(0xFFEF4444),
                                secondaryColor: const Color(0xFFDC2626),
                              ),
                              const SizedBox(height: 8),

                              _buildGameModeCard(
                                emoji: '🤝',
                                title: 'وضع فريق المعركة',
                                description:
                                    'تعاون مع فريقك لتحقيق الفوز',
                                badgeText: 'لعب جماعي',
                                primaryColor: const Color(0xFF0EA5E9),
                                secondaryColor: const Color(0xFF0284C7),
                              ),
                              const SizedBox(height: 8),

                              _buildGameModeCard(
                                emoji: '🔗',
                                title: 'وضع السلسلة',
                                description:
                                    'تحديات متتالية تختبر صمودك',
                                badgeText: 'سلسلة إجابات',
                                primaryColor: const Color(0xFF8B5CF6),
                                secondaryColor: const Color(0xFF7C3AED),
                              ),
                              const SizedBox(height: 8),

                              _buildGameModeCard(
                                emoji: '🏆',
                                title: 'وضع الإقصاء',
                                description:
                                    'خطأ واحد يُخرجك من اللعبة',
                                badgeText: 'البقاء للأقوى',
                                primaryColor: const Color(0xFFF59E0B),
                                secondaryColor: const Color(0xFFD97706),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Divider line
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.07),
                    ),

                    // Fixed Footer CTA Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _buildCtaButton(promoService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Game Info Banner (Logo, Title, Subtitle, Stats) ─────────────────────────
  Widget _buildGameInfoBanner() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App Icon Frame
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.5),
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

        // Title and Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تحدي المليون',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'لعبة أسئلة ومعلومات عامة',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              // Stats Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildStatPill(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    text: '4.8 ★',
                  ),
                  _buildStatPill(
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    text: '+100 ألف',
                  ),
                  _buildStatPill(
                    icon: Icons.verified_rounded,
                    iconColor: const Color(0xFF34D399),
                    text: 'مجانية 100%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Overview & Categories Card ─────────────────────────────────────────────
  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comprehensive Description
          Text(
            'اختبر معلوماتك وتنافس مع لاعبين من حول العالم في لعبة الأسئلة والمعلومات العامة الأشمل والأكثر إثارة! تغطي أسئلتنا مجالات متعددة:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),

          // Categories Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCategoryChip(
                emoji: '📚',
                name: 'الثقافة العامة',
                color: const Color(0xFFF59E0B),
              ),
              _buildCategoryChip(
                emoji: '🔬',
                name: 'العلوم',
                color: const Color(0xFF06B6D4),
              ),
              _buildCategoryChip(
                emoji: '📜',
                name: 'التاريخ',
                color: const Color(0xFFEC4899),
              ),
              _buildCategoryChip(
                emoji: '🌍',
                name: 'الجغرافيا',
                color: const Color(0xFF10B981),
              ),
              _buildCategoryChip(
                emoji: '⚽',
                name: 'الرياضة',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Game Modes Section Header ──────────────────────────────────────────────
  Widget _buildGameModesHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'أوضاع اللعب:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            ),
          ),
          child: const Text(
            '6 أوضاع تنافسية',
            style: TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ── High-End Game Mode Card ────────────────────────────────────────────────
  Widget _buildGameModeCard({
    required String emoji,
    required String title,
    required String description,
    required String badgeText,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mode Emoji Frame
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.35),
                  secondaryColor.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 19),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Mini Chip ─────────────────────────────────────────────────────
  Widget _buildCategoryChip({
    required String emoji,
    required String name,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11.5)),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat Pill ──────────────────────────────────────────────────────────────
  Widget _buildStatPill({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── 80 Gems Reward Banner ──────────────────────────────────────────────────
  Widget _buildRewardCard(CrossPromoService promoService) {
    final bool claimed = promoService.isRewardClaimed;
    final bool installed = _isInstalled;

    final Color borderColor = claimed
        ? const Color(0xFF10B981).withValues(alpha: 0.6)
        : installed
            ? const Color(0xFFF59E0B)
            : const Color(0xFF38BDF8).withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: claimed
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.45),
                  const Color(0xFF0F172A).withValues(alpha: 0.85),
                ]
              : installed
                  ? [
                      const Color(0xFF78350F).withValues(alpha: 0.45),
                      const Color(0xFF1E1B4B).withValues(alpha: 0.75),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      const Color(0xFF0369A1).withValues(alpha: 0.25),
                      const Color(0xFF1E293B).withValues(alpha: 0.85),
                      const Color(0xFF0F172A),
                    ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (claimed
                    ? const Color(0xFF10B981)
                    : installed
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8))
                .withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Diamond Badge Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: claimed
                        ? [const Color(0xFF34D399), const Color(0xFF059669)]
                        : [const Color(0xFF38BDF8), const Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (claimed
                              ? const Color(0xFF10B981)
                              : const Color(0xFF38BDF8))
                          .withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    claimed
                        ? Icons.check_circle_rounded
                        : Icons.diamond_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          claimed
                              ? 'تم استلام الجائزة ✓'
                              : 'هدية خاصة: 80 جوهرة 💎',
                          style: TextStyle(
                            color: claimed
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (claimed
                                    ? const Color(0xFF10B981)
                                    : installed
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF38BDF8))
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (claimed
                                      ? const Color(0xFF10B981)
                                      : installed
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF38BDF8))
                                  .withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            claimed
                                ? 'مكتمل'
                                : installed
                                    ? 'جاهز للاستلام 🎁'
                                    : '+80 💎 مجاناً',
                            style: TextStyle(
                              color: claimed
                                  ? const Color(0xFF6EE7B7)
                                  : installed
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFF7DD3FC),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claimed
                          ? 'أضيفت 80 جوهرة إلى رصيدك. شكراً لتحميلك تحدي المليون!'
                          : installed
                              ? 'تهانينا! اللعبة مثبتة على هاتفك. استلم الآن 80 جوهرة تضاف إلى رصيدك فوراً!'
                              : 'قم بتحميل لعبة «تحدي المليون» وارجع لتستلم 80 جوهرة مجانية تضاف لحسابك فوراً.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Glowing Call To Action Button ──────────────────────────────────────────
  Widget _buildCtaButton(CrossPromoService promoService) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final glowValue = 0.30 + _pulseCtrl.value * 0.45;
        final isInst = _isInstalled;
        final isClaimed = promoService.isRewardClaimed;
        final isClaiming = promoService.isClaiming;

        final bool isClaimAction = isInst && !isClaimed;

        final Color primaryGlow = isClaimAction
            ? const Color(0xFFF59E0B)
            : isInst
                ? const Color(0xFF22C55E)
                : const Color(0xFF38BDF8);

        final Color btnBg = isClaimAction
            ? const Color(0xFFD97706)
            : isInst
                ? const Color(0xFF16A34A)
                : const Color(0xFF0284C7);

        final Color btnBorder = isClaimAction
            ? const Color(0xFFFDE68A)
            : isInst
                ? const Color(0xFF86EFAC)
                : const Color(0xFF7DD3FC);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryGlow.withValues(alpha: glowValue),
                blurRadius: 20,
                spreadRadius: 1.5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isClaiming || _loadingStatus
                ? null
                : () async {
                    if (isClaimAction) {
                      final res = await promoService.claimDownloadReward(context);
                      if (res == CrossPromoClaimResult.success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8)),
                                SizedBox(width: 10),
                                Text(
                                  'مبروك! تمت إضافة 80 جوهرة إلى رصيدك بنجاح 🎉',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF065F46),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } else {
                      await promoService.openMillionaireApp();
                      if (context.mounted && isInst) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: btnBorder,
                  width: 1.6,
                ),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isClaiming) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'جاري استلام الجواهر...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else ...[
                  Icon(
                    isClaimAction
                        ? Icons.card_giftcard_rounded
                        : isInst
                            ? Icons.sports_esports_rounded
                            : Icons.file_download_outlined,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _loadingStatus
                        ? 'جاري التحقق...'
                        : isClaimAction
                            ? 'استلام 80 جوهرة الآن! 💎✨'
                            : isInst
                                ? 'فتح اللعبة واللعب الآن 🎮'
                                : 'تحميل اللعبة واحصل على 80 💎',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
