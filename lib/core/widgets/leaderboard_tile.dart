import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';
import 'user_avatar.dart';

class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final topThree = entry.rank <= 3;
    return AppCard(
      padding: const EdgeInsets.all(12),
      gradient: topThree
          ? LinearGradient(
              colors: [
                AppColors.challengeGold.withValues(alpha: 0.28),
                AppColors.challengeCard,
              ],
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          UserAvatar(
            name: entry.username,
            photoUrl: entry.photoUrl,
            level: entry.level,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('فوز ${entry.wins} • تقييم ${entry.rating}'),
              ],
            ),
          ),
          Text(
            '${entry.score}',
            style: const TextStyle(
              color: AppColors.challengeGold,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
