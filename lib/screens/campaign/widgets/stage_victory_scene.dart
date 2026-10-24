import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/campaign_stage.dart';
import '../../../models/game_character.dart';
import '../../../models/stage_attempt.dart';
import '../../../services/campaign_service.dart';
import '../../../services/native_bridge_service.dart';
import '../../../widgets/adaptive_asset_image.dart';
import 'animated_result_stars.dart';

/// The victory scene provides rich animations, festive confetti, pulsing glowing halos,
/// rolling score counters, and a lively interactive collection button.
class StageVictoryScene extends StatefulWidget {
  const StageVictoryScene({
    super.key,
    required this.stage,
    required this.result,
    required this.playerName,
    required this.onCollect,
    required this.onMap,
    required this.onRetry,
    required this.onDetails,
    this.photoUrl,
    this.gameplayXp = 0,
    this.saving = false,
    this.collected = false,
    this.isDoubled = false,
    this.onRetrySave,
    this.onNext,
    this.nextLabel = 'المرحلة التالية',
  });

  static const designSize = Size(960, 536);
  final CampaignStage stage;
  final StageSubmissionResult result;
  final String playerName;
  final String? photoUrl;
  final int gameplayXp;
  final bool saving, collected, isDoubled;
  final VoidCallback onCollect, onMap, onRetry, onDetails;
  final VoidCallback? onRetrySave, onNext;
  final String nextLabel;

  @override
  State<StageVictoryScene> createState() => _StageVictorySceneState();
}

class _StageVictorySceneState extends State<StageVictoryScene>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _loopController;
  late final Animation<double> _panelScale;
  late final Animation<double> _ribbonDrop;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _panelScale = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    _ribbonDrop = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.85, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = VictoryScoreSummary(
      stage: widget.stage,
      attempt: widget.result.attempt,
    );
    final coins = widget.result.rewardCoinsGranted * (widget.isDoubled ? 2 : 1);
    final gems = widget.result.rewardGemsGranted * (widget.isDoubled ? 2 : 1);
    final xp = widget.result.rewardXpGranted + widget.gameplayXp;

    final rewards = <Widget>[
      if (coins > 0)
        _RewardAmount(
          amount: '+$coins',
          color: const Color(0xFFFFD34C),
          asset: 'assets/home/coins.webp',
          semanticLabel: '$coins عملة',
        ),
      if (gems > 0)
        _RewardAmount(
          amount: '+$gems',
          color: const Color(0xFF76E9FF),
          asset: 'assets/home/gems.webp',
          semanticLabel: '$gems جوهرة',
        ),
      if (xp > 0)
        _RewardAmount(
          amount: '+$xp',
          color: const Color(0xFFEA8EFF),
          semanticLabel: '$xp نقطة خبرة',
        ),
    ];

    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        final loopValue = _loopController.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ──────────────────────────────────────────
            Image.asset(
              'assets/images/campaign/ui/victory_background.jpg',
              key: const ValueKey('victory-background'),
              fit: BoxFit.cover,
              cacheWidth: 1920,
              excludeFromSemantics: true,
            ),

            // ── Falling Confetti Particles Layer ─────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _VictoryConfettiPainter(progress: loopValue),
                ),
              ),
            ),

            // ── Main UI Viewport ──────────────────────────────────────────
            SafeArea(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: StageVictoryScene.designSize,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Stack(
                        children: [
                          // ── Ambient Stadium Radiance behind panel ────────
                          Positioned(
                            left: 140,
                            top: 40,
                            width: 680,
                            height: 440,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _VictoryBacklightPainter(
                                  progress: loopValue,
                                ),
                              ),
                            ),
                          ),

                          // ── Main Wooden Victory Board ───────────────────
                          Positioned.fill(
                            child: ScaleTransition(
                              scale: _panelScale,
                              child: Image.asset(
                                'assets/images/campaign/ui/victory_panel.png',
                                fit: BoxFit.fill,
                                cacheWidth: 1920,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),

                          // ── Victory Ribbon ("أنت الفائز!") ───────────────
                          Positioned(
                            left: 328,
                            top: 142,
                            width: 304,
                            height: 90,
                            child: ScaleTransition(
                              scale: _ribbonDrop,
                              child: _VictoryRibbon(loopValue: loopValue),
                            ),
                          ),

                          // ── Animated Result Stars ──────────────────────
                          Positioned(
                            left: 364,
                            top: 60,
                            width: 232,
                            height: 108,
                            child: FittedBox(
                              child: SizedBox(
                                width: 284,
                                height: 132,
                                child: AnimatedResultStars(
                                  stars: widget.result.attempt.stars,
                                ),
                              ),
                            ),
                          ),

                          // ── Pulsing Halo & Character Avatar ─────────────
                          Positioned(
                            left: 218,
                            top: 210,
                            width: 117,
                            height: 117,
                            child: _PulsingAvatarFrame(
                              photoUrl: widget.photoUrl,
                              loopValue: loopValue,
                            ),
                          ),

                          // ── Floating Crown Highlight ────────────────────
                          Positioned(
                            left: 254,
                            top: 168 + 3.5 * math.sin(loopValue * 2 * math.pi),
                            width: 45,
                            height: 38,
                            child: IgnorePointer(
                              child: ShaderMask(
                                shaderCallback: (rect) => const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF6B2),
                                    Color(0xFFFFD54F),
                                    Color(0xFFFF8F00),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(rect),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),

                          // ── First place medal (if competitive) ──────────
                          if (summary.isCompetition)
                            Positioned(
                              left: 192,
                              top:
                                  194 +
                                  2.0 * math.sin(loopValue * 2 * math.pi + 1),
                              width: 47,
                              height: 58,
                              child: const _FirstPlaceMedal(),
                            ),

                          // ── Player Name Gold Text ───────────────────────
                          Positioned(
                            left: 147,
                            top: 340,
                            width: 285,
                            height: 43,
                            child: _GoldText(
                              widget.playerName,
                              fontSize: 31,
                              loopValue: loopValue,
                            ),
                          ),

                          // ── Player Score Row ────────────────────────────
                          Positioned(
                            left: 507,
                            top: 229,
                            width: 303,
                            height: 57,
                            child: _ScoreRow(
                              name: summary.playerLabel ?? widget.playerName,
                              score: summary.playerScore,
                              gold: true,
                              avatar: ResultPlayerPortrait(
                                photoUrl: widget.photoUrl,
                              ),
                            ),
                          ),

                          // ── Target / Opponent Score Row ─────────────────
                          Positioned(
                            left: 509,
                            top: 299,
                            width: 301,
                            height: 42,
                            child: _ScoreRow(
                              name: summary.otherName,
                              score: summary.otherScore,
                              gold: false,
                              avatar: Icon(
                                summary.isCompetition
                                    ? Icons.person_rounded
                                    : Icons.flag_rounded,
                                color: const Color(0xFFE1DAF7),
                                size: 27,
                              ),
                            ),
                          ),

                          // ── Rewards Display ─────────────────────────────
                          Positioned(
                            left: 519,
                            top: 371,
                            width: 288,
                            height: 55,
                            child: widget.saving
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFFD34C),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : rewards.isEmpty
                                ? const Center(
                                    child: Text(
                                      'مكافآت النجوم محفوظة',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      textDirection: TextDirection.ltr,
                                      children: [
                                        for (
                                          var index = 0;
                                          index < rewards.length;
                                          index++
                                        ) ...[
                                          if (index > 0)
                                            const SizedBox(width: 18),
                                          rewards[index],
                                        ],
                                      ],
                                    ),
                                  ),
                          ),

                          // ── Subtitle / Save hint ────────────────────────
                          Positioned(
                            left: 508,
                            top: 428,
                            width: 307,
                            height: 17,
                            child: Text(
                              widget.saving
                                  ? 'جارٍ الحفظ...'
                                  : widget.onRetrySave != null
                                  ? 'احفظ النتيجة لإضافة المكافآت'
                                  : 'المرحلة ${widget.stage.order} · ${summary.unit}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFDFD5F3),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // ── Interactive "اجمع المكافآت" Button ──────────
                          Positioned(
                            left: 340,
                            top: 440,
                            width: 281,
                            height: 76,
                            child: _GlowingCollectButton(
                              saving: widget.saving,
                              collected: widget.collected,
                              onCollect: widget.onCollect,
                              loopValue: loopValue,
                            ),
                          ),

                          // ── The Map Button (الخريطة) ────────────────────
                          Positioned(
                            left: 12,
                            top: 447,
                            width: 78,
                            height: 77,
                            child: _AnimatedMapButton(
                              onPressed: widget.onMap,
                              loopValue: loopValue,
                            ),
                          ),

                          // ── Top Action: Stage Details ───────────────────
                          Positioned(
                            left: 16,
                            top: 14,
                            height: 36,
                            child: _SceneAction(
                              label: 'تفاصيل المرحلة',
                              icon: Icons.bar_chart_rounded,
                              onPressed: widget.onDetails,
                            ),
                          ),

                          // ── Top Action: Retry / Improve Stars ───────────
                          Positioned(
                            right: 16,
                            top: 14,
                            height: 36,
                            child: _SceneAction(
                              label: 'تحسين النجوم',
                              icon: Icons.refresh_rounded,
                              onPressed: widget.onRetry,
                            ),
                          ),

                          // ── Top Action: Retry Save (if needed) ──────────
                          if (widget.onRetrySave != null)
                            Positioned(
                              right: 145,
                              top: 14,
                              height: 36,
                              child: _SceneAction(
                                label: 'إعادة حفظ النتيجة',
                                icon: Icons.cloud_upload_rounded,
                                onPressed: widget.onRetrySave!,
                              ),
                            ),

                          // ── Bottom Action: Next Stage ───────────────────
                          if (widget.onNext != null)
                            Positioned(
                              right: 16,
                              bottom: 14,
                              height: 36,
                              child: _SceneAction(
                                label: widget.nextLabel,
                                icon: Icons.arrow_back_rounded,
                                onPressed: widget.onNext!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A solo board compares against its goal; competitive modes show real scores.
class VictoryScoreSummary {
  VictoryScoreSummary({
    required CampaignStage stage,
    required StageAttempt attempt,
  }) {
    final mode = campaignModeFromString(
      attempt.campaignMode.isEmpty
          ? stage.campaignMode.value
          : attempt.campaignMode,
      fallbackType: stage.type,
    );
    playerScore = attempt.score;
    otherScore = stage.boardTargetScore;
    otherName = 'هدف المرحلة';
    if (mode == CampaignMode.teamBattle) {
      isCompetition = true;
      playerLabel = 'فريقك';
      playerScore = attempt.teamScore;
      otherScore = attempt.enemyTeamScore;
      otherName = _name(attempt.teamEnemyName, 'الفريق المنافس');
    } else if (mode == CampaignMode.series) {
      isCompetition = true;
      playerScore = attempt.playerSeriesWins;
      otherScore = attempt.opponentSeriesWins;
      otherName = _name(attempt.opponentName, 'الخصم');
      unit = 'جولات الفوز';
    } else if (stage.isBossStage || mode == CampaignMode.bossBattle) {
      isCompetition = true;
      otherScore = attempt.bossScore;
      otherName = _name(attempt.bossName, stage.bossBotName ?? 'الزعيم');
    } else if (mode == CampaignMode.battle) {
      isCompetition = true;
      otherScore = attempt.opponentScore;
      otherName = _name(attempt.opponentName, 'الخصم');
    } else if (mode == CampaignMode.rival && attempt.targetScore > 0) {
      otherScore = attempt.targetScore;
    }
  }

  late int playerScore, otherScore;
  late String otherName;
  String? playerLabel;
  bool isCompetition = false;
  String unit = 'النقاط';

  static String _name(String? value, String fallback) =>
      value?.trim().isNotEmpty == true ? value!.trim() : fallback;
}

/// Character avatar inside a glowing halo
class ResultPlayerPortrait extends StatefulWidget {
  const ResultPlayerPortrait({super.key, this.photoUrl});
  final String? photoUrl;

  @override
  State<ResultPlayerPortrait> createState() => _ResultPlayerPortraitState();
}

class _ResultPlayerPortraitState extends State<ResultPlayerPortrait> {
  late final Future<Map<String, dynamic>> _character = NativeBridgeService()
      .getCharacterState();

  @override
  Widget build(BuildContext context) => ClipOval(
    child: ColoredBox(
      color: const Color(0xFFFCDA7A),
      child: widget.photoUrl?.startsWith('https://') == true
          ? Image.network(
              widget.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _characterPortrait(),
            )
          : _characterPortrait(),
    ),
  );

  Widget _characterPortrait() => FutureBuilder<Map<String, dynamic>>(
    future: _character,
    builder: (context, snapshot) {
      final index = (snapshot.data?['selected'] as num?)?.toInt() ?? -1;
      return adaptiveAssetImage(
        CharacterCatalog.byIndex(index < 0 ? 1 : index).asset,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person_rounded,
          color: Color(0xFF67448A),
          size: 52,
        ),
      );
    },
  );
}

/// Pulsing aura frame surrounding the player's avatar
class _PulsingAvatarFrame extends StatelessWidget {
  const _PulsingAvatarFrame({required this.photoUrl, required this.loopValue});

  final String? photoUrl;
  final double loopValue;

  @override
  Widget build(BuildContext context) {
    final auraPulse = math.sin(loopValue * 2 * math.pi);
    final glowBlur = 10.0 + 8.0 * (auraPulse * 0.5 + 0.5);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFFFD54F,
            ).withValues(alpha: 0.35 + 0.25 * auraPulse),
            blurRadius: glowBlur,
            spreadRadius: 2.0 + 3.0 * (auraPulse * 0.5 + 0.5),
          ),
          BoxShadow(
            color: const Color(
              0xFFFF8F00,
            ).withValues(alpha: 0.2 + 0.15 * auraPulse),
            blurRadius: glowBlur * 1.5,
            spreadRadius: 4.0,
          ),
        ],
      ),
      child: ResultPlayerPortrait(photoUrl: photoUrl),
    );
  }
}

/// Score row showing player/opponent info with smooth counter animation
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.score,
    required this.gold,
    required this.avatar,
  });

  final String name;
  final int score;
  final bool gold;
  final Widget avatar;

  @override
  Widget build(BuildContext context) => Row(
    textDirection: TextDirection.ltr,
    children: [
      Container(
        width: gold ? 47 : 40,
        height: gold ? 47 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF77738D),
          border: Border.all(
            color: gold ? const Color(0xFFFFDC71) : const Color(0xFFB9B6C9),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: avatar,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: gold
            ? _GoldText(name, fontSize: 25, alignment: Alignment.centerLeft)
            : Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC4C0D2),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 72,
        child: _AnimatedScoreCounter(targetScore: score, isGold: gold),
      ),
    ],
  );
}

/// Counting score that smoothly rolls up to the final number
class _AnimatedScoreCounter extends StatefulWidget {
  const _AnimatedScoreCounter({
    required this.targetScore,
    required this.isGold,
  });

  final int targetScore;
  final bool isGold;

  @override
  State<_AnimatedScoreCounter> createState() => _AnimatedScoreCounterState();
}

class _AnimatedScoreCounterState extends State<_AnimatedScoreCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedScoreCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetScore != widget.targetScore) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = (_animation.value * widget.targetScore).round();
        if (widget.isGold) {
          return _GoldText('$current', fontSize: 38);
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$current',
            style: const TextStyle(
              color: Color(0xFFB9B3CA),
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount({
    required this.amount,
    required this.color,
    required this.semanticLabel,
    this.asset,
  });

  final String amount, semanticLabel;
  final Color color;
  final String? asset;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        Text(
          amount,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            color: color,
            fontSize: 31,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (asset != null)
          ClipOval(
            child: SizedBox.square(
              dimension: 39,
              child: Stack(
                children: [
                  Positioned(
                    left: -48 / 128 * 39,
                    top: -48 / 128 * 39,
                    width: 769 / 128 * 39,
                    height: 224 / 128 * 39,
                    child: adaptiveAssetImage(
                      asset!,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.stars_rounded, color: color, size: 34),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(-0.15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF4B0FF), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD500F9).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEE8FFF), Color(0xFF952FE0)],
              ),
            ),
            child: const Text(
              'XP',
              style: TextStyle(
                color: Color(0xFF4F147B),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    ),
  );
}

class _GoldText extends StatelessWidget {
  const _GoldText(
    this.text, {
    required this.fontSize,
    this.alignment = Alignment.center,
    this.loopValue = 0.0,
  });

  final String text;
  final double fontSize;
  final Alignment alignment;
  final double loopValue;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF9CF), Color(0xFFFFD651), Color(0xFFE99A20)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Color(0xFF7C410C),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The glowing, animated "اجمع المكافآت" button with pulsing shine and rich 3D appearance
class _GlowingCollectButton extends StatelessWidget {
  const _GlowingCollectButton({
    required this.saving,
    required this.collected,
    required this.onCollect,
    required this.loopValue,
  });

  final bool saving;
  final bool collected;
  final VoidCallback onCollect;
  final double loopValue;

  @override
  Widget build(BuildContext context) {
    final isInteractive = !saving && !collected;
    final pulseScale = isInteractive
        ? 1.0 + 0.035 * math.sin(loopValue * 2 * math.pi)
        : 1.0;
    final glowPulse = 0.5 + 0.4 * math.sin(loopValue * 2 * math.pi);

    return Semantics(
      button: true,
      enabled: isInteractive,
      label: saving
          ? 'جارٍ حفظ النتيجة'
          : collected
          ? 'تم جمع المكافآت'
          : 'اجمع المكافآت',
      child: Transform.scale(
        scale: pulseScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              if (isInteractive)
                BoxShadow(
                  color: const Color(
                    0xFF00B0FF,
                  ).withValues(alpha: 0.35 * glowPulse),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              if (isInteractive)
                BoxShadow(
                  color: const Color(
                    0xFFFFD700,
                  ).withValues(alpha: 0.2 * glowPulse),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('victory-collect'),
              onTap: isInteractive ? onCollect : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Button Background Body ──────────────────────────────
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: collected
                            ? const Color(0xFF81C784)
                            : const Color(0xFFFFD76B),
                        width: 2.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: collected
                            ? const [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                            : const [
                                Color(0xFF1EC9FF),
                                Color(0xFF0F75F0),
                                Color(0xFF0A47B8),
                              ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // ── Glossy top highlight curve ──────────────────────────
                  Positioned(
                    top: 2,
                    left: 12,
                    right: 12,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Shimmer light sweep ──────────────────────────────────
                  if (isInteractive)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: CustomPaint(
                          painter: _ButtonShimmerPainter(progress: loopValue),
                        ),
                      ),
                    ),

                  // ── Content Label ───────────────────────────────────────
                  Center(
                    child: saving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'جارٍ حفظ النتيجة...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : collected
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFFFD54F),
                                size: 26,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تم جمع المكافآت ✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xFFFFEA8A),
                                Color(0xFFFFC107),
                              ],
                              stops: [0.0, 0.4, 1.0],
                            ).createShader(rect),
                            child: const Text(
                              'اجمع المكافآت',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontFamily: 'NotoSansArabic',
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF002970),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer light reflection line passing diagonally across the button
class _ButtonShimmerPainter extends CustomPainter {
  const _ButtonShimmerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Shimmer triggers every 3.2s loop, active during 0.25 -> 0.75
    final normalized = (progress * 1.5) % 1.5;
    if (normalized > 1.0) return;

    final xPos = -size.width * 0.4 + normalized * (size.width * 1.8);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(xPos, 0, size.width * 0.35, size.height));

    canvas.save();
    canvas.skew(-0.35, 0.0);
    canvas.drawRect(
      Rect.fromLTWH(xPos, -20, size.width * 0.35, size.height + 40),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ButtonShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Map button with subtle floating bob
class _AnimatedMapButton extends StatelessWidget {
  const _AnimatedMapButton({required this.onPressed, required this.loopValue});

  final VoidCallback onPressed;
  final double loopValue;

  @override
  Widget build(BuildContext context) {
    final bob = 2.0 * math.sin(loopValue * 2 * math.pi);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
      ),
      child: Transform.translate(
        offset: Offset(0, bob),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_rounded,
                color: Color(0xFFFFD989),
                size: 39,
                shadows: [Shadow(color: Color(0xFFFFB300), blurRadius: 8)],
              ),
              Text(
                'الخريطة',
                style: TextStyle(
                  height: 1.2,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                      offset: Offset(0, 1),
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
}

/// Modern glassmorphic top scene action button with refined hover/press feel
class _SceneAction extends StatelessWidget {
  const _SceneAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: const Color(0xFFFFD54F)),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xDE1F133F),
        foregroundColor: const Color(0xFFFFE8AB),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _FirstPlaceMedal extends StatelessWidget {
  const _FirstPlaceMedal();
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    children: [
      const Positioned(
        bottom: 0,
        child: Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFB664EB),
          size: 49,
        ),
      ),
      Container(
        width: 43,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFEE98), width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE88E), Color(0xFFF5AE24)],
          ),
        ),
        child: const Text(
          'المركز\nالأول',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8E430B),
            fontSize: 10,
            height: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _VictoryRibbon extends StatelessWidget {
  const _VictoryRibbon({this.loopValue = 0.0});
  final double loopValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VictoryRibbonPainter(loopValue: loopValue),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(34, 5, 34, 16),
        child: Center(
          child: Text(
            'أنت الفائز!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Color(0xFF5F157E),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VictoryRibbonPainter extends CustomPainter {
  const _VictoryRibbonPainter({this.loopValue = 0.0});
  final double loopValue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tails = Path()
      ..moveTo(0, 17)
      ..lineTo(40, 17)
      ..lineTo(40, 90)
      ..lineTo(0, 90)
      ..lineTo(19, 53)
      ..close()
      ..moveTo(size.width, 17)
      ..lineTo(size.width - 40, 17)
      ..lineTo(size.width - 40, 90)
      ..lineTo(size.width, 90)
      ..lineTo(size.width - 19, 53)
      ..close();

    canvas.drawShadow(tails, Colors.black87, 4, false);
    canvas.drawPath(
      tails,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4CACFF), Color(0xFF9C29E1), Color(0xFF5713AB)],
        ).createShader(rect),
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(35, 0, size.width - 70, 72),
      const Radius.circular(6),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black87, 5, false);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFAF20DA), Color(0xFF752ADD), Color(0xFF2AB7F5)],
        ).createShader(rect),
    );

    // Glowing border
    canvas.drawRRect(
      body.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE99CFF).withValues(alpha: 0.75),
    );

    // Shimmer glint across the ribbon
    final shimmerProgress = (loopValue * 1.3) % 1.3;
    if (shimmerProgress <= 1.0) {
      final shimmerX = 35.0 + shimmerProgress * (size.width - 70);
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(shimmerX - 30, 0, 60, 72));
      canvas.save();
      canvas.clipRRect(body);
      canvas.drawRect(Rect.fromLTWH(shimmerX - 30, 0, 60, 72), shimmerPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VictoryRibbonPainter oldDelegate) =>
      oldDelegate.loopValue != loopValue;
}

/// Rotating golden celebratory light rays behind the main victory card
class _VictoryBacklightPainter extends CustomPainter {
  const _VictoryBacklightPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final maxRadius = size.width * 0.5;

    // Pulsing radial glow
    final pulse = 0.6 + 0.4 * math.sin(progress * 2 * math.pi);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD54F).withValues(alpha: 0.22 * pulse),
          const Color(0xFFFFB300).withValues(alpha: 0.08 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, glowPaint);

    // Rotating soft light rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.06 * pulse)
      ..style = PaintingStyle.fill;

    final rayAngle = (2 * math.pi) / 14;
    final rotation = progress * 2 * math.pi * 0.15;

    for (int i = 0; i < 14; i += 2) {
      final startAngle = rotation + i * rayAngle;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: maxRadius * 0.95),
          startAngle,
          rayAngle * 0.75,
          false,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(_VictoryBacklightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Floating, fluttering colorful & gold confetti particles
class _VictoryConfettiPainter extends CustomPainter {
  _VictoryConfettiPainter({required this.progress});
  final double progress;

  // Precomputed deterministic particle properties for smooth 60fps performance
  static final List<_ConfettiData> _particles = List.generate(42, (i) {
    final random = math.Random(i * 197 + 13);
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFFB300), // Warm amber
      const Color(0xFF00E5FF), // Celebration cyan
      const Color(0xFFE040FB), // Vivid neon purple
      const Color(0xFFFF4081), // Party coral pink
      const Color(0xFF76FF03), // Lime green
      const Color(0xFFFFFFFF), // White spark
    ];
    return _ConfettiData(
      xFrac: random.nextDouble(),
      yOffset: random.nextDouble(),
      speed: 0.6 + random.nextDouble() * 0.8,
      wobbleSpeed: 1.0 + random.nextDouble() * 2.5,
      wobbleRadius: 8.0 + random.nextDouble() * 20.0,
      width: 5.0 + random.nextDouble() * 7.0,
      height: 7.0 + random.nextDouble() * 9.0,
      color: colors[random.nextInt(colors.length)],
      isCircle: random.nextDouble() > 0.7,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final currentY = ((progress * p.speed + p.yOffset) % 1.0) * size.height;
      final currentX =
          (p.xFrac * size.width +
              math.sin(progress * p.wobbleSpeed * 2 * math.pi + p.xFrac * 10) *
                  p.wobbleRadius) %
          size.width;

      final flipY = math.cos(progress * p.speed * 4 * math.pi + p.xFrac * 8);
      final rotation = progress * p.speed * 3 * math.pi + p.xFrac * 5;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(rotation);
      canvas.scale(1.0, flipY);

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.width * 0.5, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.width,
              height: p.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VictoryConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiData {
  const _ConfettiData({
    required this.xFrac,
    required this.yOffset,
    required this.speed,
    required this.wobbleSpeed,
    required this.wobbleRadius,
    required this.width,
    required this.height,
    required this.color,
    required this.isCircle,
  });

  final double xFrac, yOffset, speed, wobbleSpeed, wobbleRadius, width, height;
  final Color color;
  final bool isCircle;
}
