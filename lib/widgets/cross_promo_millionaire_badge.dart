import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final installed = await context.read<CrossPromoService>().checkInstallation();
    if (mounted) {
      setState(() => _isInstalled = installed);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.compact;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowAlpha = 0.25 + _glowController.value * 0.45;

        return GestureDetector(
          onTap: () => CrossPromoMillionaireDialog.show(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: glowAlpha),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 26 : 30,
                  height: isCompact ? 26 : 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFBBF24),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/ui/million_challenge_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFBBF24),
                        size: 16,
                      ),
                    ),
                  ),
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
                      ],
                    ),
                    Text(
                      _isInstalled ? 'العب الآن 🎮' : 'جرّب الآن مجاناً 🚀',
                      style: TextStyle(
                        color: const Color(0xFFFBBF24),
                        fontSize: isCompact ? 9 : 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFFFBBF24),
                  size: isCompact ? 11 : 13,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
