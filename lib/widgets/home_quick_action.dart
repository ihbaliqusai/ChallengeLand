import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import 'adaptive_asset_image.dart';

/// A compact home shortcut with a quiet animation and a full touch target.
class HomeQuickAction extends StatelessWidget {
  const HomeQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.animation,
    required this.onPressed,
    this.showGreenDot = false,
    this.isAvailable = true,
    this.animationPhase = 0,
    this.asset,
    this.circular = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Animation<double> animation;
  final VoidCallback onPressed;
  final bool showGreenDot;
  final bool isAvailable;
  final double animationPhase;
  final String? asset;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: label,
        hint: isAvailable ? null : 'يتطلب اتصالاً بالإنترنت',
        onTap: onPressed,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: asset == null
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF122344), Color(0xFF081329)],
                          ),
                          shape:
                              circular ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius:
                              circular ? null : BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(
                                alpha: isAvailable ? 0.38 : 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        )
                      : const BoxDecoration(),
                  child: IconButton(
                    onPressed: () {
                      AppSettings.playClick();
                      onPressed();
                    },
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(52),
                      shape: circular
                          ? const CircleBorder()
                          : RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                      foregroundColor: color,
                    ),
                    icon: AnimatedBuilder(
                      animation: animation,
                      child: asset != null
                          ? Opacity(
                              opacity: isAvailable ? 1 : .65,
                              child: adaptiveAssetImage(asset!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true))
                          : Icon(
                              icon,
                              color: isAvailable
                                  ? color
                                  : color.withValues(alpha: 0.52),
                              size: 28,
                            ),
                      builder: (context, child) {
                        final motion = reduceMotion
                            ? 0.0
                            : math.sin(
                                animation.value * math.pi + animationPhase);
                        return Transform.translate(
                          offset: Offset(0, motion * -1.8),
                          child: Transform.rotate(
                            angle: motion * 0.04,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (showGreenDot)
                  Positioned(
                    top: asset != null ? 8 : 3,
                    right: asset != null ? 9 : 3,
                    child: IgnorePointer(
                      child: Container(
                        key: const ValueKey('home-friends-green-dot'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF081329),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399)
                                  .withValues(alpha: 0.45),
                              blurRadius: 7,
                            ),
                          ],
                        ),
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
