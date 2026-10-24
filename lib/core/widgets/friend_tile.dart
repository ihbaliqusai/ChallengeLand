import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'user_avatar.dart';

class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.user,
    this.onChallenge,
    this.actionLabel = 'تحدي',
  });

  final UserProfile user;
  final VoidCallback? onChallenge;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          UserAvatar(
            name: user.username,
            photoUrl: user.photoUrl,
            level: user.level,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('تقييم ${user.rating} • فوز ${user.wins}'),
              ],
            ),
          ),
          AppButton(
            label: actionLabel,
            onPressed: onChallenge,
            fullWidth: false,
            icon: Icons.sports_esports_rounded,
          ),
        ],
      ),
    );
  }
}
