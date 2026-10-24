import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/challenge_scaffold.dart';

class QuickMatchScreen extends StatelessWidget {
  const QuickMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChallengeScaffold(
      title: 'تحدي سريع',
      subtitle: 'سنبحث عن منافس مناسب. في وضع التطوير ستلعب ضد بوت محلي.',
      children: [
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.wifi_tethering_rounded, size: 42),
              SizedBox(height: 12),
              Text(
                'قواعد الجولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                '5 أسئلة • 15 ثانية لكل سؤال • +100 للإجابة الصحيحة • حتى +50 مكافأة سرعة',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AppButton(
          label: 'ابدأ البحث',
          icon: Icons.search_rounded,
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.searchingMatch),
        ),
      ],
    );
  }
}
