import 'package:flutter/material.dart';

import '../../../models/campaign_daily_progress.dart';
import '../../../models/campaign_stage.dart';
import '../../../services/campaign_engagement_service.dart';

const _ink = Color(0xFF10283E);
const _gold = Color(0xFFFFD46A);

class CampaignJourneyBar extends StatelessWidget {
  const CampaignJourneyBar({
    super.key,
    required this.daily,
    required this.onDailyTap,
    required this.continueStage,
    required this.onContinue,
    this.compact = false,
    this.continueGuideKey,
    this.dailyGuideKey,
  });

  final CampaignDailyProgress daily;
  final VoidCallback onDailyTap;
  final CampaignStage? continueStage;
  final VoidCallback? onContinue;
  final bool compact;
  final Key? continueGuideKey, dailyGuideKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: continueGuideKey,
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              minimumSize: Size(0, compact ? 44 : 52),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 10, vertical: compact ? 6 : 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              continueStage == null
                  ? 'رحلتك مكتملة'
                  : 'العب المرحلة ${continueStage!.order}',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: compact ? 12 : null),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            key: dailyGuideKey,
            onPressed: onDailyTap,
            style: FilledButton.styleFrom(
              backgroundColor: compact
                  ? const Color(0xFFF4F9E8).withValues(alpha: 0.92)
                  : _ink,
              foregroundColor: compact ? _ink : Colors.white,
              minimumSize: Size(0, compact ? 44 : 52),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 10, vertical: compact ? 6 : 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                    color: compact
                        ? const Color(0x66FFFFFF)
                        : const Color(0xFF416078)),
              ),
            ),
            icon: Icon(
                daily.allGoalsCompleted
                    ? Icons.verified_rounded
                    : Icons.explore_rounded,
                color: compact ? const Color(0xFF2B7250) : _gold,
                size: compact ? 18 : 22),
            label: Text('رحلة اليوم ${daily.goalsCompleted}/3',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : null)),
          ),
        ),
      ],
    );
  }
}

class CampaignJourneySheet extends StatelessWidget {
  const CampaignJourneySheet({
    super.key,
    required this.daily,
    required this.worldName,
    required this.worldStars,
    required this.worldMaxStars,
    required this.recommendedStage,
    required this.onRecommendedTap,
    this.now,
  });

  final CampaignDailyProgress daily;
  final String worldName;
  final int worldStars;
  final int worldMaxStars;
  final CampaignStage? recommendedStage;
  final VoidCallback? onRecommendedTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final date = now ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);
    final active = daily.activityDays.toSet();
    final gold = worldMaxStars > 0 && worldStars >= worldMaxStars;
    final silver =
        worldMaxStars > 0 && worldStars >= (worldMaxStars * 2 / 3).ceil();
    final bronze =
        worldMaxStars > 0 && worldStars >= (worldMaxStars / 3).ceil();
    final medal = gold
        ? 'إتقان ذهبي'
        : silver
            ? 'إتقان فضي'
            : bronze
                ? 'إتقان برونزي'
                : 'ابدأ جمع النجوم';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.explore_rounded, color: _gold, size: 34),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('رحلة اليوم',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'إغلاق',
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70)),
              ]),
              Text(
                  daily.allGoalsCompleted
                      ? 'أحسنت! أكملت أهداف اليوم. غدًا تنتظرك رحلة جديدة.'
                      : 'جولات قصيرة، تقدّم جديد. حقّق أهدافك بأي مرحلة مفتوحة.',
                  style: const TextStyle(color: Colors.white70, height: 1.7)),
              const SizedBox(height: 18),
              _DailyGoal(
                  icon: Icons.videogame_asset_rounded,
                  title: 'العب جولتين',
                  value: daily.attempts,
                  target: 2),
              _DailyGoal(
                  icon: Icons.flag_rounded,
                  title: 'أنهِ مرحلة بنجاح',
                  value: daily.wins,
                  target: 1),
              _DailyGoal(
                  icon: Icons.star_rounded,
                  title: 'اجمع 3 نجوم في محاولاتك',
                  value: daily.stars,
                  target: 3),
              const SizedBox(height: 14),
              const Text('نشاطك خلال آخر 7 أيام',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                for (var index = 6; index >= 0; index--)
                  Expanded(
                      child: _ActivityDay(
                    date: DateTime(today.year, today.month, today.day - index),
                    played: active.contains(CampaignEngagementService.dayKey(
                        DateTime(today.year, today.month, today.day - index))),
                    today: index == 0,
                  )),
              ]),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF193C52),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3B647A))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: gold
                                ? _gold
                                : silver
                                    ? const Color(0xFFCEE7F1)
                                    : const Color(0xFFE1AD7D),
                            size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('$worldName • $medal',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900))),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: worldMaxStars > 0
                                  ? (worldStars / worldMaxStars).clamp(0.0, 1.0)
                                  : 0,
                              minHeight: 8,
                              color: _gold,
                              backgroundColor: Colors.white12)),
                      const SizedBox(height: 8),
                      Text(
                          '$worldStars/$worldMaxStars نجمة • أعد المراحل لتحسين إتقانك',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              if (recommendedStage != null) ...[
                const SizedBox(height: 18),
                const Text('اقتراح اليوم',
                    style:
                        TextStyle(color: _gold, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(recommendedStage!.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    recommendedStage!.isBossStage
                        ? 'اختبر مهارتك أمام الزعيم وارفع أفضل نتيجة.'
                        : '${recommendedStage!.boardSoloPicks} اختيارات • هدفك ${recommendedStage!.boardTargetScore} نقطة',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: onRecommendedTap,
                    style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                        padding: const EdgeInsets.all(14)),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('ابدأ تحدي اليوم')),
              ],
              const SizedBox(height: 12),
              const Text('الأهداف تتجدد يوميًا. يُحفظ نشاطك على هذا الجهاز.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyGoal extends StatelessWidget {
  const _DailyGoal(
      {required this.icon,
      required this.title,
      required this.value,
      required this.target});
  final IconData icon;
  final String title;
  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    final complete = value >= target;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: complete ? const Color(0xFF164D41) : const Color(0xFF193449),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: complete ? const Color(0xFF3A9F7F) : Colors.white12)),
      child: Row(children: [
        Icon(complete ? Icons.check_circle_rounded : icon,
            color: complete ? const Color(0xFF85E5B4) : _gold),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Text('${value.clamp(0, target)}/$target',
            style: TextStyle(
                color: complete ? const Color(0xFF85E5B4) : Colors.white70,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ActivityDay extends StatelessWidget {
  const _ActivityDay(
      {required this.date, required this.played, required this.today});
  final DateTime date;
  final bool played;
  final bool today;

  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
            label: '${date.day}/${date.month}: ${played ? 'لعبت' : 'لم تلعب'}',
            child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: played ? const Color(0xFF3A9F7F) : Colors.white10,
                    border: today ? Border.all(color: _gold, width: 2) : null),
                child: Icon(played ? Icons.check_rounded : Icons.remove_rounded,
                    size: 17, color: played ? Colors.white : Colors.white30))),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(today ? 'اليوم' : '${date.day}/${date.month}',
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
      ]);
}
