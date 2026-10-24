import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum AppButtonVariant { primary, gold, danger, ghost }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final colors = switch (widget.variant) {
      AppButtonVariant.gold => const [
        AppColors.challengeYellow,
        AppColors.challengeOrange,
      ],
      AppButtonVariant.danger => const [
        AppColors.challengeRed,
        AppColors.challengePink,
      ],
      AppButtonVariant.ghost => [
        AppColors.challengeCard.withValues(alpha: 0.75),
        AppColors.challengeCard,
      ],
      AppButtonVariant.primary => const [
        AppColors.challengeCyan,
        AppColors.challengeBlue,
      ],
    };

    final child = AnimatedScale(
      scale: _pressed && !disabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: disabled ? null : widget.onPressed,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Ink(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: disabled ? 0.08 : 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (!widget.fullWidth) return child;
    return SizedBox(width: double.infinity, child: child);
  }
}
