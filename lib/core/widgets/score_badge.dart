import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,
    this.label = 'النقاط',
    this.color = AppColors.challengeGold,
  });

  final int score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$label $score',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
