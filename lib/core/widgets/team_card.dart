import 'package:flutter/material.dart';

import '../../models/team.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

class TeamCard extends StatelessWidget {
  const TeamCard({super.key, required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.challengeGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${team.score}'),
            ],
          ),
          const SizedBox(height: 10),
          Text('عدد اللاعبين: ${team.playerCount}'),
        ],
      ),
    );
  }
}
