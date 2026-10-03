import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/campaign_service.dart';

class ResultRewardPanel extends StatefulWidget {
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
  State<ResultRewardPanel> createState() => _ResultRewardPanelState();
}

class _ResultRewardPanelState extends State<ResultRewardPanel>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late final AnimationController _celebrateController;

  late final Animation<double> _pulseAnimation;
  late final Animation<double> _celebrateScale;
  double _buttonPressScale = 1.0;

  @override
  void initState() {
    super.initState();
    // Shimmer beam sweeps smoothly across the golden button every 2.4s
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Subtle breathing pulse for badges and icons
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Celebratory bounce when reward is doubled
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _celebrateScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_celebrateController);

    if (widget.isDoubled) {
      _celebrateController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant ResultRewardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDoubled && widget.isDoubled) {
      _celebrateController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isDoubled = widget.isDoubled;
    final isDoubling = widget.isDoubling;
    final onDoubleReward = widget.onDoubleReward;

    final hasReward = result.rewardGranted ||
        result.rewardCoinsGranted > 0 ||
        result.rewardGemsGranted > 0 ||
        result.rewardXpGranted > 0;
    final hasCurrencyReward =
        result.rewardCoinsGranted > 0 || result.rewardGemsGranted > 0;

    final effectiveCoins =
        isDoubled ? result.rewardCoinsGranted * 2 : result.rewardCoinsGranted;
    final effectiveGems =
        isDoubled ? result.rewardGemsGranted * 2 : result.rewardGemsGranted;

    return AnimatedBuilder(
      animation: _celebrateScale,
      builder: (context, child) {
        return Transform.scale(
          scale: isDoubled ? _celebrateScale.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDoubled
                  ? const Color(0xFF132A60)
                  : const Color(0xFF0D1B44),
              const Color(0xFF060B24),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDoubled
                ? const Color(0xFFFBBF24).withValues(alpha: 0.85)
                : const Color(0xFF38BDF8).withValues(alpha: 0.32),
            width: isDoubled ? 1.8 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: isDoubled
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.30)
                  : const Color(0xFF0369A1).withValues(alpha: 0.25),
              blurRadius: isDoubled ? 26 : 20,
              offset: const Offset(0, 6),
            ),
            if (isDoubled)
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header Row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDoubled
                          ? [const Color(0xFFFDE047), const Color(0xFFD97706)]
                          : [const Color(0xFF38BDF8), const Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDoubled
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF38BDF8))
                            .withValues(alpha: 0.45),
                        blurRadius: 10,
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'مكافأة المرحلة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDoubled
                        ? const Color(0xFF10B981).withValues(alpha: 0.22)
                        : widget.currencyRewardApplied
                            ? const Color(0xFF0284C7).withValues(alpha: 0.20)
                            : hasReward
                                ? const Color(0xFFFACC15).withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDoubled
                          ? const Color(0xFF34D399).withValues(alpha: 0.65)
                          : widget.currencyRewardApplied
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.50)
                              : hasReward
                                  ? const Color(0xFFFACC15).withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    isDoubled
                        ? 'مضاعفة 2x ✓'
                        : widget.currencyRewardApplied
                            ? 'تمت الإضافة'
                            : hasReward
                                ? 'محفوظة'
                                : 'مكتملة',
                    style: TextStyle(
                      color: isDoubled
                          ? const Color(0xFF34D399)
                          : widget.currencyRewardApplied
                              ? const Color(0xFF7DD3FC)
                              : hasReward
                                  ? const Color(0xFFFDE047)
                                  : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            // ── Reward Chips ────────────────────────────────────────
            if (hasReward) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 9,
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

            // ── Interactive Double Reward Button (World-Class 3D Golden Button) ───
            if (hasCurrencyReward && !isDoubled && onDoubleReward != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTapDown: isDoubling
                    ? null
                    : (_) => setState(() => _buttonPressScale = 0.97),
                onTapUp: isDoubling
                    ? null
                    : (_) {
                        setState(() => _buttonPressScale = 1.0);
                        HapticFeedback.lightImpact();
                        onDoubleReward();
                      },
                onTapCancel: () => setState(() => _buttonPressScale = 1.0),
                child: AnimatedScale(
                  scale: _buttonPressScale,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOutQuad,
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFFBEB),
                          Color(0xFFFEE685),
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        stops: [0.0, 0.25, 0.70, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFFBEB),
                        width: 1.4,
                      ),
                      boxShadow: [
                        const BoxShadow(
                          color: Color(0xFF92400E),
                          offset: Offset(0, 4.5),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.50),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Shimmering light sweep overlay
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _ShimmerSweepPainter(
                                  progress: _shimmerController.value,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),

                        // Button Content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isDoubling)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF111827),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF111827),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Color(0xFFFACC15),
                                        size: 20,
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isDoubling
                                        ? 'جارٍ تشغيل الإعلان...'
                                        : 'ضاعف مكافأتك 2x 🎬',
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x33FFFFFF),
                                          offset: Offset(0, 1),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Animated pulsing "+100% Free" badge
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111827),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.35),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        '+100% مجاناً 🔥',
                                        style: TextStyle(
                                          color: Color(0xFFFACC15),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isDoubling
                                    ? 'انتظر لحظات لتحميل المكافأة المضاعفة...'
                                    : 'شاهد فيديو قصير واحصل على ضعف العملات والجواهر فوراً! ⚡',
                                style: const TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ── Doubled Celebration Banner ──────────────────────────
            if (isDoubled) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF047857),
                      Color(0xFF065F46),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.80),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34D399),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'تمت مضاعفة المكافأة 2x بنجاح! تم استلام الضعف 🎉',
                        style: TextStyle(
                          color: Color(0xFFECFDF5),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.symmetric(
        horizontal: isDoubled ? 14 : 12,
        vertical: isDoubled ? 9 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDoubled
                ? const Color(0xFFFBBF24).withValues(alpha: 0.28)
                : color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDoubled ? const Color(0xFFFBBF24) : color.withValues(alpha: 0.45),
          width: isDoubled ? 2.0 : 1.0,
        ),
        boxShadow: isDoubled
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDoubled
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : color.withValues(alpha: 0.25),
            ),
            child: Icon(icon, color: isDoubled ? const Color(0xFFFFE082) : color, size: 17),
          ),
          const SizedBox(width: 7),
          Text(
            '$value $label',
            style: TextStyle(
              color: isDoubled ? const Color(0xFFFFFBEB) : Colors.white,
              fontSize: isDoubled ? 15.5 : 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isDoubled) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                '2x',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 10.5,
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

/// Custom painter for a sweeping diagonal sheen light across the 3D button
class _ShimmerSweepPainter extends CustomPainter {
  _ShimmerSweepPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05 || progress >= 0.95) return;

    final width = size.width;
    final height = size.height;
    // Map progress (0.05..0.95) to travel from -100 to width + 100
    final t = (progress - 0.05) / 0.90;
    final currentX = (width + 200) * t - 100;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.40),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(currentX - 50, 0, 100, height));

    canvas.save();
    // Rotate canvas slightly for a dynamic diagonal light beam
    canvas.skew(-0.35, 0);
    canvas.drawRect(Rect.fromLTWH(currentX - 50, 0, 100, height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
