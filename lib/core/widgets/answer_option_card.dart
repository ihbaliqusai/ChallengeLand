import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AnswerOptionCard extends StatelessWidget {
  const AnswerOptionCard({
    super.key,
    required this.text,
    required this.onTap,
    this.isSelected = false,
    this.isCorrect,
    this.enabled = true,
  });

  final String text;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool? isCorrect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color fillColor;
    final IconData icon;
    if (isCorrect == true) {
      borderColor = AppColors.challengeGreen;
      fillColor = AppColors.challengeGreen.withValues(alpha: 0.18);
      icon = Icons.check_circle_rounded;
    } else if (isCorrect == false && isSelected) {
      borderColor = AppColors.challengeRed;
      fillColor = AppColors.challengeRed.withValues(alpha: 0.18);
      icon = Icons.cancel_rounded;
    } else if (isSelected) {
      borderColor = AppColors.challengeGold;
      fillColor = AppColors.challengeGold.withValues(alpha: 0.12);
      icon = Icons.radio_button_checked_rounded;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.08);
      fillColor = AppColors.challengeCard;
      icon = Icons.circle_outlined;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: AnimatedScale(
          scale: isSelected ? 1.015 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: isSelected || isCorrect != null ? 2 : 1.5,
              ),
              boxShadow: [
                if (isSelected || isCorrect != null)
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(icon, color: borderColor, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w800,
                    ),
                  ),
                ),
                if (isCorrect == true)
                  const Text(
                    'صحيح',
                    style: TextStyle(
                      color: AppColors.challengeGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else if (isCorrect == false && isSelected)
                  const Text(
                    'خطأ',
                    style: TextStyle(
                      color: AppColors.challengeRed,
                      fontWeight: FontWeight.w900,
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
