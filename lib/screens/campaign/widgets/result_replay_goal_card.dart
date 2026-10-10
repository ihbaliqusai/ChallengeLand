import 'package:flutter/material.dart';

import '../../../models/campaign_stage.dart';
import '../../../services/campaign_service.dart';

/// Gives each attempt a comparison and a concrete reason to play again.
class ResultReplayGoalCard extends StatelessWidget {
  const ResultReplayGoalCard({
    super.key,
    required this.stage,
    required this.result,
    this.unsaved = false,
  });

  final CampaignStage stage;
  final StageSubmissionResult result;
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    final attempt = result.attempt;
    final previousScore = result.previousProgress?.bestScore;
    final bestStars = result.updatedProgress.stars.clamp(0, 3);
    final isRecord =
        !unsaved && result.improvedBestScore && result.previousProgress != null;
    final nextStars = (bestStars + 1).clamp(1, 3);
    final nextTarget = !attempt.completed || bestStars == 0
        ? stage.boardTargetScore
        : bestStars == 1
            ? stage.starRules.twoStarsMinScore
            : stage.starRules.threeStarsMinScore;
    final needsWin = !attempt.completed && stage.isBossStage;
    final remaining = (nextTarget - attempt.score).clamp(0, nextTarget);
    final ruleGoal = attempt.completed
        ? null
        : switch (attempt.failureReason) {
            'timeExpired' =>
              'هدفك القادم: حقّق نقاط المرحلة وأنهِ اللوحة قبل انتهاء الوقت.',
            'eliminated' =>
              'هدفك القادم: حقّق نقاط المرحلة دون تجاوز عدد الأخطاء المسموح.',
            'required_categories_not_completed' =>
              'هدفك القادم: أجب صحيحًا في ${stage.boardRequiredCategoryCount} فئات مختلفة من فئات العالم، وحقّق نقاط المرحلة.',
            _ => null,
          };
    final goal = ruleGoal ??
        (needsWin
            ? 'هدفك القادم: المركز الأول أمام جميع الزعماء.'
            : !attempt.completed
                ? remaining > 0
                    ? 'بقيت $remaining نقطة للوصول إلى هدف المرحلة.'
                    : 'حقّق الفوز في المحاولة القادمة لاحتساب النجوم.'
                : bestStars < 3
                    ? 'هدفك القادم: $nextTarget نقطة للوصول إلى $nextStars نجوم.'
                    : 'أتقنت المرحلة! حسّن ترتيبك أو اكتشف التحدي التالي.');
    final color = isRecord ? const Color(0xFFFFD66B) : const Color(0xFF7DD3FC);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF061642).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isRecord
                      ? Icons.emoji_events_rounded
                      : Icons.trending_up_rounded,
                  color: color,
                  size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRecord ? 'رقم شخصي جديد!' : 'تقدّمك في هذه المرحلة',
                  style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RecordPill(
                  label: 'نجوم المحاولة',
                  value: '${attempt.stars.clamp(0, 3)} / 3'),
              if (!unsaved)
                _RecordPill(label: 'أفضل نجوم', value: '$bestStars / 3'),
              if (previousScore != null)
                _RecordPill(label: 'أفضل رقم سابق', value: '$previousScore'),
              if (isRecord && previousScore != null)
                _RecordPill(
                    label: 'تحسّن النقاط',
                    value: '+${attempt.score - previousScore}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(goal,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.4)),
          if (!needsWin &&
              ruleGoal == null &&
              nextTarget > 0 &&
              (!attempt.completed || bestStars < 3)) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (attempt.score / nextTarget).clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: Colors.white12,
                semanticsLabel: 'التقدم نحو الهدف القادم',
              ),
            ),
          ],
          if (!attempt.completed || bestStars < 3) ...[
            const SizedBox(height: 9),
            Text(
              stage.isBossStage
                  ? 'اختر فئاتك الأقوى، وراقب نقاط الزعماء قبل المخاطرة.'
                  : 'وازن بين قيمة السؤال وثقتك بالإجابة. الكتابة تمنحك النقاط كاملة.',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
          if (stage.boardRulesText.isNotEmpty &&
              (!attempt.completed || bestStars < 3)) ...[
            const SizedBox(height: 9),
            Text(stage.boardRulesText,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _RecordPill extends StatelessWidget {
  const _RecordPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white70)),
            TextSpan(
                text: value, style: const TextStyle(color: Color(0xFFFFD66B))),
          ]),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
}
