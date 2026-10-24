import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/score_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/score_card.dart';
import '../../state/auth_provider.dart';
import '../../state/game_provider.dart';

class GameResultScreen extends StatelessWidget {
  const GameResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final won = game.playerScore >= game.opponentScore;
    final user = context.watch<AuthProvider>().user;
    final xp = ScoreUtils.calculateXpEarned(
      score: game.playerScore,
      correctAnswers: game.correctAnswers,
      won: won,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.challengeDark,
              AppColors.challengePurple,
              AppColors.challengeNavy,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _ConfettiLayer()),
              SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CelebrationHeader(won: won, username: user?.username),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: ScoreCard(
                            title: AppStrings.yourScore,
                            score: game.playerScore,
                            highlight: won,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ScoreCard(
                            title: AppStrings.opponent,
                            score: game.opponentScore,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        children: [
                          _row(
                            AppStrings.correctAnswers,
                            '${game.correctAnswers}',
                          ),
                          _row(AppStrings.wrongAnswers, '${game.wrongAnswers}'),
                          _row(AppStrings.earnedXp, '+$xp XP'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                color: AppColors.challengeGold,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  AppStrings.levelProgress,
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Text('+$xp'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 12,
                              value: ScoreUtils.calculateLevelProgress(
                                xp: (user?.xp ?? 0) + xp,
                                level: user?.level ?? 1,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              color: AppColors.challengeGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: AppStrings.playAgain,
                      icon: Icons.refresh_rounded,
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.searchingMatch,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: AppStrings.backHome,
                      icon: Icons.home_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (_) => false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: AppStrings.shareResult,
                      icon: Icons.share_rounded,
                      variant: AppButtonVariant.gold,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(AppStrings.shareResultSoon),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CelebrationHeader extends StatelessWidget {
  const _CelebrationHeader({required this.won, required this.username});

  final bool won;
  final String? username;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      gradient: LinearGradient(
        colors: won
            ? const [AppColors.challengeGold, AppColors.challengeOrange]
            : const [AppColors.challengePurple, AppColors.challengeBlue],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              won ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
              color: won ? AppColors.challengeDark : AppColors.challengeGold,
              size: 66,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            won ? AppStrings.wonChallenge : AppStrings.strongRound,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: won ? AppColors.challengeDark : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            username == null
                ? AppStrings.roundResult
                : '${AppStrings.wellDone} $username',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: won ? AppColors.challengeDark : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.challengeGold,
      AppColors.challengeCyan,
      AppColors.challengePink,
      AppColors.challengeGreen,
      AppColors.challengeOrange,
    ];
    return IgnorePointer(
      child: Stack(
        children: List.generate(18, (index) {
          final color = colors[index % colors.length];
          final left = (index * 47 % 340).toDouble();
          final top = 22 + (index * 41 % 520).toDouble();
          return Positioned(
            left: left,
            top: top,
            child: Transform.rotate(
              angle: index * 0.35,
              child: Container(
                width: index.isEven ? 8 : 12,
                height: index.isEven ? 18 : 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
