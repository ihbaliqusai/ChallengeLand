import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.title,
    required this.score,
    this.highlight = false,
  });

  final String title;
  final int score;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: highlight
          ? const LinearGradient(
              colors: [AppColors.challengeGold, AppColors.challengeOrange],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: highlight ? AppColors.challengeDark : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
