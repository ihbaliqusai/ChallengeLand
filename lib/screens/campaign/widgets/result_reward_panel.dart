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
  });

  final StageSubmissionResult result;
  final bool currencyRewardApplied;
  final VoidCallback? onDoubleReward;
  final bool isDoubled;
  final bool isDoubling;

  @override
  Widget build(BuildContext context) {
    final hasReward = result.rewardGranted ||
        result.rewardCoinsGranted > 0 ||
        result.rewardGemsGranted > 0 ||
        result.rewardXpGranted > 0;
    final hasCurrencyReward =
        result.rewardCoinsGranted > 0 || result.rewardGemsGranted > 0;

    final effectiveCoins = isDoubled
        ? result.rewardCoinsGranted * 2
        : result.rewardCoinsGranted;
    final effectiveGems = isDoubled
        ? result.rewardGemsGranted * 2
        : result.rewardGemsGranted;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDoubled ? const Color(0xFF142459) : const Color(0xFF0D1B44),
            const Color(0xFF060B24),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDoubled
              ? const Color(0xFFFACC15).withValues(alpha: 0.65)
              : const Color(0xFF38BDF8).withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDoubled
                ? const Color(0xFFFACC15).withValues(alpha: 0.20)
                : const Color(0xFF0369A1).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDoubled
                        ? [const Color(0xFFFDE047), const Color(0xFFF59E0B)]
                        : [const Color(0xFF38BDF8), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDoubled
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF38BDF8))
                          .withValues(alpha: 0.40),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isDoubled
                      ? Icons.auto_awesome_rounded
                      : Icons.card_giftcard_rounded,
                  color: isDoubled
                      ? const Color(0xFF111827)
                      : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مكافأة المرحلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDoubled
                      ? const Color(0xFF10B981).withValues(alpha: 0.20)
                      : hasReward
                          ? const Color(0xFFFACC15).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDoubled
                        ? const Color(0xFF34D399).withValues(alpha: 0.50)
                        : hasReward
                            ? const Color(0xFFFACC15).withValues(alpha: 0.40)
                            : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  isDoubled
                      ? 'مضاعفة 2x ✓'
                      : currencyRewardApplied
                          ? 'تمت الإضافة'
                          : hasReward
                              ? 'محفوظة'
                              : 'مكتملة',
                  style: TextStyle(
                    color: isDoubled
                        ? const Color(0xFF34D399)
                        : hasReward
                            ? const Color(0xFFFDE047)
                            : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (hasReward) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (result.rewardCoinsGranted > 0)
                  _RewardChip(
                    icon: Icons.monetization_on_rounded,
                    value: '$effectiveCoins',
                    label: 'عملة',
                    color: const Color(0xFFFFD66B),
                    isDoubled: isDoubled,
                  ),
                if (result.rewardGemsGranted > 0)
                  _RewardChip(
                    icon: Icons.diamond_rounded,
                    value: '$effectiveGems',
                    label: 'جوهرة',
                    color: const Color(0xFF6FE7FF),
                    isDoubled: isDoubled,
                  ),
                if (result.rewardXpGranted > 0)
                  _RewardChip(
                    icon: Icons.bolt_rounded,
                    value: '${result.rewardXpGranted}',
                    label: 'خبرة',
                    color: const Color(0xFF54F088),
                    isDoubled: false,
                  ),
              ],
            ),
          ],
          if (hasCurrencyReward && !isDoubled && onDoubleReward != null) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDoubling ? null : onDoubleReward,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFBEB),
                        Color(0xFFFDE047),
                        Color(0xFFF59E0B),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      top: BorderSide(color: Colors.white, width: 1.5),
                      left: BorderSide(color: Color(0xFFFDE047), width: 1),
                      right: BorderSide(color: Color(0xFFFDE047), width: 1),
                      bottom: BorderSide(color: Color(0xFFB45309), width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isDoubling)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF111827),
                              ),
                            )
                          else
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Color(0xFF111827),
                              size: 24,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isDoubling
                                ? 'جارٍ تشغيل الإعلان...'
                                : 'ضاعف مكافأتك 2x 🎬',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+100% مجاناً',
                              style: TextStyle(
                                color: Color(0xFFFACC15),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'شاهد إعلاناً واحداً واحصل على ضعف العملات والجواهر فوراً ⚡',
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (isDoubled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.60),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF34D399), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'تمت مضاعفة المكافأة 2x بنجاح! تم استلام الضعف 🎉',
                    style: TextStyle(
                      color: Color(0xFFECFDF5),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.isDoubled = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDoubled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDoubled
              ? const Color(0xFFFACC15)
              : color.withValues(alpha: 0.45),
          width: isDoubled ? 1.6 : 1.0,
        ),
        boxShadow: isDoubled
            ? [
                BoxShadow(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              color: isDoubled ? const Color(0xFFFFFBEB) : Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isDoubled) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '2x',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
