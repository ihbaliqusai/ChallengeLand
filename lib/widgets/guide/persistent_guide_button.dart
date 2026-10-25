import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../adaptive_asset_image.dart';
import 'guide_assistant_dialog.dart';

/// Floating / Docked Guide Button shown on HomeScreen as long as the user has not logged in.
class PersistentGuideButton extends StatefulWidget {
  const PersistentGuideButton({
    super.key,
    required this.onRestartTour,
  });

  final VoidCallback onRestartTour;

  @override
  State<PersistentGuideButton> createState() => _PersistentGuideButtonState();
}

class _PersistentGuideButtonState extends State<PersistentGuideButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    GuideAssistantDialog.show(
      context,
      onRestartTour: widget.onRestartTour,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glowAlpha = 0.25 + _pulseCtrl.value * 0.45;
        final floatOffset = math.sin(_pulseCtrl.value * math.pi) * 3.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: GestureDetector(
            onTap: _onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.8),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFACC15).withValues(alpha: glowAlpha),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Host Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFACC15),
                        width: 1.5,
                      ),
                      color: const Color(0xFF1E293B),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: adaptiveAssetImage(
                      'assets/presenter/head.png',
                      alignment: const Alignment(0, -0.7),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مرشد الساحة',
                        style: TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFACC15),
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'شرح الأزرار والأرصدة',
                        style: TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.1,
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
