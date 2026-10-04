import 'package:flutter/material.dart';

import '../../../services/campaign_service.dart';

class ResultRewardPanel extends StatelessWidget {
  const ResultRewardPanel({
    super.key,
    required this.result,
    required this.currencyRewardApplied,
    this.onDoubleReward,
    this.isDoubled = false,
    this.isDoubling = false,
    this.gameplayXp = 0,
    this.trophyDelta,
  });

  final StageSubmissionResult result;
  final bool currencyRewardApplied;
  final VoidCallback? onDoubleReward;
  final bool isDoubled;
  final bool isDoubling;
  final int gameplayXp;
  final int? trophyDelta;

  @override
  Widget build(BuildContext context) {
    final hasReward = result.rewardCoinsGranted > 0 ||
        result.rewardGemsGranted > 0 ||
        result.rewardXpGranted > 0;
    final hasCurrency =
        result.rewardCoinsGranted > 0 || result.rewardGemsGranted > 0;
    final coins = result.rewardCoinsGranted * (isDoubled ? 2 : 1);
    final gems = result.rewardGemsGranted * (isDoubled ? 2 : 1);
    final status = isDoubled
        ? 'تمت المضاعفة'
        : currencyRewardApplied
            ? 'تمت الإضافة'
            : hasReward
                ? 'محفوظة'
                : result.attempt.completed
                    ? 'استمر بالتحدي'
                    : 'المحاولة القادمة';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDoubled ? const Color(0xFF123A35) : const Color(0xFF0D1B44),
            const Color(0xFF060B24),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDoubled
              ? const Color(0xFF34D399)
              : const Color(0xFF38BDF8).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.card_giftcard_rounded,
                  color: Color(0xFFFFD66B), size: 22),
              const Text('مكافأة المرحلة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: isDoubled
                            ? const Color(0xFF34D399)
                            : const Color(0xFF7DD3FC),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasReward)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (coins > 0)
                  _RewardChip(
                      icon: Icons.monetization_on_rounded,
                      label: '$coins عملة',
                      color: const Color(0xFFFFD66B)),
                if (gems > 0)
                  _RewardChip(
                      icon: Icons.diamond_rounded,
                      label: '$gems جوهرة',
                      color: const Color(0xFF6FE7FF)),
                if (result.rewardXpGranted > 0)
                  _RewardChip(
                      icon: Icons.bolt_rounded,
                      label: '${result.rewardXpGranted} خبرة',
                      color: const Color(0xFF54F088)),
              ],
            )
          else
            Text(
              result.attempt.completed
                  ? result.updatedProgress.stars >= 3
                      ? 'اكتملت مكافآت النجوم. حسّن ترتيبك أو انتقل لتحدٍ جديد.'
                      : 'تحسين عدد النجوم يفتح لك بقية مكافآت هذه المرحلة.'
                  : 'اربح المرحلة لتحصل على النجوم ومكافأة الإنجاز.',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          if (gameplayXp > 0 || trophyDelta != null) ...[
            const SizedBox(height: 12),
            const Text('تقدم اللعب المحتسب',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (gameplayXp > 0)
                _RewardChip(
                    icon: Icons.bolt_rounded,
                    label: '+$gameplayXp XP من اللعب',
                    color: const Color(0xFF54F088)),
              if (trophyDelta != null)
                _RewardChip(
                    icon: Icons.emoji_events_rounded,
                    label: '${trophyDelta! >= 0 ? '+' : ''}$trophyDelta كأس',
                    color: trophyDelta! < 0
                        ? const Color(0xFFFB7185)
                        : const Color(0xFFFFD66B)),
            ]),
          ],
          if (hasCurrency &&
              !isDoubled &&
              onDoubleReward != null &&
              currencyRewardApplied) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isDoubling ? null : onDoubleReward,
                icon: isDoubling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_circle_outline_rounded, size: 22),
                label: Text(isDoubling
                    ? 'جارٍ تحميل الإعلان...'
                    : 'ضاعف العملات والجواهر ×2'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD66B),
                  foregroundColor: const Color(0xFF311300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('إعلان اختياري. نقاط الخبرة لا تتضاعف.',
                style: TextStyle(
                    color: Colors.white60, fontSize: 11, height: 1.4)),
          ],
          if (isDoubled) ...[
            const SizedBox(height: 10),
            const Text('تمت إضافة المكافأة الإضافية بنجاح.',
                style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text.rich(
          TextSpan(children: [
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(icon, color: color, size: 18)),
            TextSpan(text: ' $label'),
          ]),
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      );
}
