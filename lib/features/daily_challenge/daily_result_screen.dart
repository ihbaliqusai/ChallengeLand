import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/challenge_scaffold.dart';

class DailyResultScreen extends StatelessWidget {
  const DailyResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChallengeScaffold(
      title: 'نتيجة اليوم',
      subtitle:
          'تم حفظ أفضل نتيجة يومية في وضع Firebase، وفي mock تعرض محليًا.',
      children: [
        AppButton(
          label: 'عرض لوحة اليوم',
          icon: Icons.leaderboard_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.leaderboard),
        ),
      ],
    );
  }
}
