import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../services/cross_promo_service.dart';
import 'cross_promo_millionaire_dialog.dart';

class CrossPromoMillionaireBadge extends StatefulWidget {
  const CrossPromoMillionaireBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<CrossPromoMillionaireBadge> createState() =>
      _CrossPromoMillionaireBadgeState();
}

class _CrossPromoMillionaireBadgeState extends State<CrossPromoMillionaireBadge>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _checkStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    final promoService = context.read<CrossPromoService>();
    final uid = context.read<AppState>().currentUser?.uid;
    await promoService.checkInstallation();
    await promoService.checkRewardClaimed(uid: uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.compact;

    return Consumer<CrossPromoService>(
      builder: (context, promoService, child) {
        final isInstalled = promoService.isMillionaireInstalled;
        final isClaimed = promoService.isRewardClaimed;

        final Color primaryAccent = !isClaimed
            ? (isInstalled ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
            : const Color(0xFFF59E0B);

        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final glowAlpha = 0.25 + _glowController.value * 0.45;

            return GestureDetector(
              onTap: () => CrossPromoMillionaireDialog.show(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F172A),
                      !isClaimed && isInstalled
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.8),
                    width: !isClaimed ? 1.8 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryAccent.withValues(alpha: glowAlpha),
                      blurRadius: !isClaimed ? 14 : 10,
                      spreadRadius: !isClaimed ? 0.8 : 0.4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo with optional Reward Tag
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: isCompact ? 26 : 30,
                          height: isCompact ? 26 : 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryAccent,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryAccent.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/ui/million_challenge_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.emoji_events_rounded,
                                color: primaryAccent,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        if (!isClaimed)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF38BDF8),
                              ),
                              child: const Icon(
                                Icons.diamond_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: isCompact ? 6 : 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'تحدي المليون',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 11 : 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (!isClaimed) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '+80 💎',
                                  style: TextStyle(
                                    color: const Color(0xFF7DD3FC),
                                    fontSize: isCompact ? 8 : 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          !isClaimed
                              ? (isInstalled
                                  ? 'استلم 80 💎 الآن!'
                                  : 'حمّل واحصل على 80 💎')
                              : (isInstalled
                                  ? 'العب الآن 🎮'
                                  : 'جرّب الآن مجاناً 🚀'),
                          style: TextStyle(
                            color: !isClaimed && isInstalled
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                            fontSize: isCompact ? 9 : 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: primaryAccent,
                      size: isCompact ? 11 : 13,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

