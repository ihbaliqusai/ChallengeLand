import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/challenge_scaffold.dart';

class GameBoardScreen extends StatelessWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChallengeScaffold(
      title: 'لوحة الجولة',
      subtitle: 'مكان جاهز لتوسعة أنماط اللوحة والبطولات لاحقًا.',
      children: [
        const AppCard(child: Text('في MVP يبدأ اللعب مباشرة من شاشة الأسئلة.')),
        const SizedBox(height: 18),
        AppButton(
          label: 'ابدأ الأسئلة',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.question),
        ),
      ],
    );
  }
}
