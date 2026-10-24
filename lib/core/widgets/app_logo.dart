import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: AppStrings.appName,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 46 : 64,
            height: compact ? 46 : 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.challengeGold, AppColors.challengeOrange],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.challengeGold.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.challengeDark,
              size: compact ? 28 : 38,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppStrings.appName,
            style: (compact ? textTheme.titleLarge : textTheme.headlineSmall)
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
