import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import 'special_offer_dialog.dart';

/// زر/شارة العرض الحصري في صفحة البداية للوصول للعرض في أي وقت
class SpecialOfferBadge extends StatefulWidget {
  const SpecialOfferBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<SpecialOfferBadge> createState() => _SpecialOfferBadgeState();
}

class _SpecialOfferBadgeState extends State<SpecialOfferBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVip = context.select<AppState, bool>((s) => s.isVip);
    if (isVip) return const SizedBox.shrink();

    final isCompact = widget.compact;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowAlpha = 0.30 + _glowController.value * 0.45;
        final scale = 1.0 + _glowController.value * 0.04;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              SpecialOfferDialog.show(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 12,
                vertical: isCompact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF451A03),
                    Color(0xFF78350F),
                    Color(0xFF451A03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFDF73).withValues(alpha: 0.85),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: glowAlpha),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Crown Icon with Glow
                  Container(
                    width: isCompact ? 26 : 30,
                    height: isCompact ? 26 : 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFDF73),
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFFBEB),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF451A03),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text labels
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'نادي الأبطال',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'استكشف مزايا العضوية',
                        style: TextStyle(
                          color: const Color(0xFFFFDF73).withValues(alpha: 0.9),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
