import 'package:flutter/material.dart';

import '../../models/match_history.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';
import 'status_badge.dart';

class MatchHistoryTile extends StatelessWidget {
  const MatchHistoryTile({super.key, required this.match});

  final MatchHistory match;

  @override
  Widget build(BuildContext context) {
    final won = match.result == 'win';
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            won ? Icons.emoji_events_rounded : Icons.sports_esports_rounded,
            color: won ? AppColors.challengeGold : AppColors.challengeCyan,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ضد ${match.opponentName}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  'صحيح ${match.correctAnswers} • خطأ ${match.wrongAnswers}',
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(
                label: won
                    ? 'فوز'
                    : match.result == 'loss'
                    ? 'خسارة'
                    : 'تعادل',
                color: won ? AppColors.challengeGreen : AppColors.challengeGold,
              ),
              const SizedBox(height: 6),
              Text('${match.score} نقطة'),
            ],
          ),
        ],
      ),
    );
  }
}
