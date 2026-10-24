import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../core/widgets/game_mode_card.dart';

class GameModeSelectionScreen extends StatelessWidget {
  const GameModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChallengeScaffold(
      title: 'اختر نوع التحدي',
      subtitle: 'كل الأنماط مجانية في إصدار MVP.',
      children: [
        GameModeCard(
          title: AppStrings.quickChallenge,
          subtitle: 'منافس سريع ضد لاعب أو بوت في وضع التطوير.',
          icon: Icons.flash_on_rounded,
          color: AppColors.challengeCyan,
          onTap: () => Navigator.pushNamed(context, AppRoutes.quickMatch),
        ),
        const SizedBox(height: 12),
        GameModeCard(
          title: AppStrings.createRoom,
          subtitle: 'أنشئ غرفة خاصة وشارك الكود مع أصدقائك.',
          icon: Icons.add_home_work_rounded,
          color: AppColors.challengeGold,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createRoom),
        ),
        const SizedBox(height: 12),
        GameModeCard(
          title: AppStrings.joinByCode,
          subtitle: 'ادخل كود غرفة من 6 خانات وانضم للتحدي.',
          icon: Icons.key_rounded,
          color: AppColors.challengePurple,
          onTap: () => Navigator.pushNamed(context, AppRoutes.joinRoom),
        ),
        const SizedBox(height: 12),
        GameModeCard(
          title: AppStrings.teamBattle,
          subtitle: 'فريق ضد فريق مع نقاط جماعية.',
          icon: Icons.groups_rounded,
          color: AppColors.challengeGreen,
          onTap: () => Navigator.pushNamed(context, AppRoutes.teamSetup),
        ),
        const SizedBox(height: 12),
        GameModeCard(
          title: AppStrings.categoriesPoints,
          subtitle: 'اختر فئة واجمع أكبر عدد من النقاط.',
          icon: Icons.category_rounded,
          color: AppColors.challengeOrange,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.categorySelection),
        ),
        const SizedBox(height: 12),
        GameModeCard(
          title: AppStrings.dailyChallenge,
          subtitle: 'مجموعة يومية موحدة ولوحة صدارة يومية.',
          icon: Icons.calendar_month_rounded,
          color: AppColors.challengePink,
          onTap: () => Navigator.pushNamed(context, AppRoutes.dailyChallenge),
        ),
      ],
    );
  }
}
