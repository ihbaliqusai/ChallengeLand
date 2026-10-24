import 'package:flutter/material.dart';

import '../../models/room_player.dart';
import 'app_card.dart';
import 'score_badge.dart';
import 'status_badge.dart';
import 'user_avatar.dart';

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player, this.onRemove});

  final RoomPlayer player;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          UserAvatar(name: player.username, photoUrl: player.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.username,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (player.isHost)
                      const StatusBadge(label: 'المضيف', icon: Icons.star),
                    StatusBadge(
                      label: player.isReady ? 'جاهز' : 'ينتظر',
                      icon: player.isReady
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          ScoreBadge(score: player.score, label: ''),
          if (onRemove != null)
            IconButton(
              tooltip: 'إزالة اللاعب',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}
