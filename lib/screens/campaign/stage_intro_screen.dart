import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/campaign_stage.dart';
import '../../models/stage_progress.dart';
import '../../services/campaign_mode_engine.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/native_bridge_service.dart';
import 'stage_leaderboard_screen.dart';
import 'widgets/level_complete_background.dart';
import 'widgets/star_rating_view.dart';

class StageIntroScreen extends StatefulWidget {
  const StageIntroScreen({
    super.key,
    required this.stage,
    required this.progress,
  });

  final CampaignStage stage;
  final StageProgress progress;

  @override
  State<StageIntroScreen> createState() => _StageIntroScreenState();
}

class _StageIntroScreenState extends State<StageIntroScreen>
    with WidgetsBindingObserver {
  static const Duration _pendingResultRetryDelay = Duration(milliseconds: 350);
  static const Duration _missingResultTimeout = Duration(seconds: 8);

  final CampaignModeEngine _modeEngine = const CampaignModeEngine();
  bool _launching = false;
  bool _waitingForResult = false;
  bool _returnedFromNative = false;
  bool _pendingResultRetryScheduled = false;
  DateTime? _missingResultSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingCampaignResult();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_launching) {
        _returnedFromNative = true;
        if (!_waitingForResult && mounted) {
          setState(() => _waitingForResult = true);
        }
      }
      _consumePendingCampaignResult();
    }
  }

  Future<void> _consumePendingCampaignResult() async {
    if (!mounted) return;
    final handled =
        await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
      context: context,
    );
    if (!mounted) return;
    if (handled && _launching) {
      _resetPendingResultWait();
      setState(() {
        _launching = false;
        _waitingForResult = false;
      });
      return;
    }
    if (!handled && _launching) {
      if (_shouldStopWaitingForMissingResult()) {
        _stopWaitingForMissingResult();
        return;
      }
      _retryPendingResultSoon();
    }
  }

  void _retryPendingResultSoon() {
    if (_pendingResultRetryScheduled) return;
    _pendingResultRetryScheduled = true;
    Future<void>.delayed(_pendingResultRetryDelay, () {
      _pendingResultRetryScheduled = false;
      if (!mounted || !_launching) return;
      _consumePendingCampaignResult();
    });
  }

  bool _shouldStopWaitingForMissingResult() {
    if (!_returnedFromNative) return false;
    final now = DateTime.now();
    _missingResultSince ??= now;
    return now.difference(_missingResultSince!) >= _missingResultTimeout;
  }

  void _stopWaitingForMissingResult() {
    _resetPendingResultWait();
    if (!mounted) return;
    setState(() {
      _launching = false;
      _waitingForResult = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'لم تصل نتيجة المرحلة. حاول بدء المرحلة مرة أخرى.',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  void _resetPendingResultWait() {
    _returnedFromNative = false;
    _pendingResultRetryScheduled = false;
    _missingResultSince = null;
  }

  Future<void> _launchStage() async {
    if (_launching) return;
    _resetPendingResultWait();
    setState(() {
      _launching = true;
      _waitingForResult = false;
    });

    final nativeBridge = context.read<NativeBridgeService>();
    final messenger = ScaffoldMessenger.of(context);
    final stage = widget.stage;

    try {
      // Campaign stages run on the challenge board, which loads its own question
      // pool natively (LocalQuestions.loadBoardPool) — no per-stage id selection.
      const questionIds = <int>[];
      final effectiveAllowedLevels = stage.allowedLevels
          .where((level) => level.trim().isNotEmpty)
          .toList(growable: false);
      if (kDebugMode) {
        debugPrint(
          'Launch campaign board stage=${stage.id} order=${stage.order} '
          'kind=${stage.isBossStage ? 'boss' : 'solo'} '
          'target=${stage.boardTargetScore} bots=${stage.botCount} '
          'policy=${stage.categoryPolicy} cats=${stage.categories}',
        );
      }
      final launchConfig = _modeEngine.buildLaunchConfig(stage);
      await nativeBridge.launchCampaignStage(
        campaignId: launchConfig['campaignId'] as String? ?? stage.campaignId,
        stageId: launchConfig['stageId'] as String? ?? stage.id,
        stageType: launchConfig['stageType'] as String? ?? stage.type.value,
        campaignMode:
            launchConfig['campaignMode'] as String? ?? stage.campaignMode.value,
        winCondition:
            launchConfig['winCondition'] as String? ?? stage.winCondition.value,
        questionIds: questionIds,
        allowedLevels: effectiveAllowedLevels,
        questionCount:
            launchConfig['questionCount'] as int? ?? stage.questionCount,
        timeLimitSeconds:
            launchConfig['timeLimitSeconds'] as int? ?? stage.timeLimitSeconds,
        allow5050: launchConfig['allow5050'] as bool? ?? stage.allow5050,
        allowAudience:
            launchConfig['allowAudience'] as bool? ?? stage.allowAudience,
        allowCall: launchConfig['allowCall'] as bool? ?? stage.allowCall,
        bossBotName: launchConfig['bossBotName'] as String? ?? '',
        bossBotIntelligence: launchConfig['bossBotIntelligence'] as int? ?? 0,
        lives: launchConfig['lives'] as int? ?? 0,
        maxWrongAnswers: launchConfig['maxWrongAnswers'] as int? ?? 0,
        targetScore: launchConfig['targetScore'] as int? ?? 0,
        opponentName: launchConfig['opponentName'] as String? ?? '',
        opponentAccuracy: launchConfig['opponentAccuracy'] as int? ?? 0,
        opponentStartScore: launchConfig['opponentStartScore'] as int? ?? 0,
        seriesRounds: launchConfig['seriesRounds'] as int? ?? 0,
        seriesWinsRequired: launchConfig['seriesWinsRequired'] as int? ?? 0,
        teamAllyName: launchConfig['teamAllyName'] as String? ?? '',
        teamEnemyName: launchConfig['teamEnemyName'] as String? ?? '',
        campaignBoard: launchConfig['campaignBoard'] as bool? ?? true,
        boardKind: launchConfig['boardKind'] as String? ?? 'solo',
        boardTargetScore: launchConfig['boardTargetScore'] as int? ?? 0,
        boardSoloPicks: launchConfig['boardSoloPicks'] as int? ?? 6,
        boardSoloCols: launchConfig['boardSoloCols'] as int? ?? 4,
        boardBotCount: launchConfig['boardBotCount'] as int? ?? 0,
        boardBotIntelligence: launchConfig['boardBotIntelligence'] as int? ?? 0,
        categoryPolicy: launchConfig['categoryPolicy'] as String? ?? 'playerPick',
        worldCategories:
            (launchConfig['worldCategories'] as List<dynamic>? ?? const <dynamic>[])
                .map((dynamic e) => e.toString())
                .toList(growable: false),
      );
      if (mounted) setState(() => _waitingForResult = true);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحميل أسئلة مناسبة لهذه المرحلة.',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      if (mounted) {
        _resetPendingResultWait();
        setState(() {
          _launching = false;
          _waitingForResult = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final progress = widget.progress;
    final accent = _stageAccent(stage);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LevelCompleteBackground()),
            // A soft accent wash so boss and solo stages feel distinct.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                    onLeaderboard: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StageLeaderboardScreen(stage: stage),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Column(
                            children: [
                              _StageHeroCard(
                                stage: stage,
                                progress: progress,
                                accent: accent,
                              ),
                              const SizedBox(height: 12),
                              _ObjectiveCard(
                                stage: stage,
                                progress: progress,
                                accent: accent,
                              ),
                              const SizedBox(height: 12),
                              _StarThresholdsCard(stage: stage),
                              const SizedBox(height: 12),
                              _HowToPlayCard(stage: stage, accent: accent),
                              const SizedBox(height: 12),
                              _RewardsCard(stage: stage),
                              const SizedBox(height: 12),
                              _BestRecordCard(progress: progress),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _BottomBar(
                    accent: accent,
                    launching: _launching,
                    onStart: _launchStage,
                    onMap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            if (_launching)
              const Positioned.fill(
                child: _BlockingLoadingOverlay(
                  message: 'جاري تجهيز المرحلة...',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _stageAccent(CampaignStage stage) =>
    stage.isBossStage ? const Color(0xFFFF4D6D) : const Color(0xFF4D8DFF);

const Color _gold = Color(0xFFFFD95A);

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onLeaderboard});

  final VoidCallback onBack;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          _CircleHudButton(icon: Icons.arrow_forward_rounded, onPressed: onBack),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'تفاصيل المرحلة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onLeaderboard,
            icon: const Icon(Icons.leaderboard_rounded, size: 18),
            label: const Text('الترتيب'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBDEBFF),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _StageHeroCard extends StatelessWidget {
  const _StageHeroCard({
    required this.stage,
    required this.progress,
    required this.accent,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final boss = stage.isBossStage;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.30),
            const Color(0xFF0A1A3A).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _StageNumberBadge(order: stage.order, boss: boss),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stage.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypePill(
                      icon: boss
                          ? Icons.workspace_premium_rounded
                          : Icons.flag_rounded,
                      label: boss ? 'مواجهة زعماء' : 'مرحلة فردية',
                      color: accent,
                    ),
                    if (boss)
                      _TypePill(
                        icon: Icons.local_fire_department_rounded,
                        label: _bossDifficultyLabel(stage.order),
                        color: _gold,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                StarRatingView(stars: progress.stars, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageNumberBadge extends StatelessWidget {
  const _StageNumberBadge({required this.order, required this.boss});

  final int order;
  final bool boss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: boss
              ? const [Color(0xFFFFF5C4), Color(0xFFFFC43F), Color(0xFFFF7C1E)]
              : const [Color(0xFFFFFFFF), Color(0xFFCFE2FF), Color(0xFF7FB0FF)],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: (boss ? const Color(0xFFFFC43F) : const Color(0xFF7FB0FF))
                .withValues(alpha: 0.45),
            blurRadius: 20,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (boss)
            const Positioned(
              top: 8,
              child: Icon(Icons.emoji_events_rounded,
                  color: Color(0xFF8A2F00), size: 17),
            ),
          Text(
            '$order',
            style: TextStyle(
              color: boss ? const Color(0xFF5B2100) : const Color(0xFF103064),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: boss ? 1.5 : 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Objective card ────────────────────────────────────────────────────────────

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.stage,
    required this.progress,
    required this.accent,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final boss = stage.isBossStage;
    return _SectionCard(
      title: 'الهدف',
      icon: Icons.my_location_rounded,
      accent: accent,
      child: boss ? _bossObjective() : _soloObjective(),
    );
  }

  Widget _soloObjective() {
    final target = stage.boardTargetScore;
    final best = progress.bestScore.clamp(0, target);
    final ratio = target <= 0 ? 0.0 : (best / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.stars_rounded, color: accent, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$target',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text(
                          'نقطة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'اجمع هذه النقاط على اللوحة لإنهاء المرحلة',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProgressBar(ratio: ratio, accent: accent),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'أفضل نتيجة لك: ${progress.bestScore}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${stage.boardSoloPicks} اختيارات',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bossObjective() {
    final bots = stage.botCount > 0 ? stage.botCount : 1;
    final headline =
        bots == 1 ? 'تغلّب على الزعيم' : 'تغلّب على $bots من الزعماء';
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.16),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.military_tech_rounded, color: accent, size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'كن صاحب أعلى نقاط على اللوحة لتفتح الطريق التالي',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio, required this.accent});

  final double ratio;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 9, color: Colors.white.withValues(alpha: 0.10)),
          FractionallySizedBox(
            widthFactor: ratio == 0 ? 0.001 : ratio,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.7), accent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Star thresholds ───────────────────────────────────────────────────────────

class _StarThresholdsCard extends StatelessWidget {
  const _StarThresholdsCard({required this.stage});

  final CampaignStage stage;

  @override
  Widget build(BuildContext context) {
    final rules = stage.starRules;
    final boss = stage.isBossStage;
    return _SectionCard(
      title: 'شروط النجوم',
      icon: Icons.star_rounded,
      accent: _gold,
      child: Row(
        children: [
          Expanded(
            child: _StarTier(
              stars: 1,
              text: boss ? 'الفوز بالمواجهة' : 'الوصول للهدف',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StarTier(stars: 2, text: '${rules.twoStarsMinScore} نقطة'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StarTier(stars: 3, text: '${rules.threeStarsMinScore} نقطة'),
          ),
        ],
      ),
    );
  }
}

class _StarTier extends StatelessWidget {
  const _StarTier({required this.stars, required this.text});

  final int stars;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingView(stars: stars, size: 17),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── How to play ───────────────────────────────────────────────────────────────

class _HowToPlayCard extends StatelessWidget {
  const _HowToPlayCard({required this.stage, required this.accent});

  final CampaignStage stage;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final boss = stage.isBossStage;
    return _SectionCard(
      title: 'كيف تلعب',
      icon: Icons.menu_book_rounded,
      accent: const Color(0xFF7DD3FC),
      child: Column(
        children: [
          const _HowToRow(
            icon: Icons.grid_view_rounded,
            text: 'اختر خانة من اللوحة وأجب عن سؤالها.',
          ),
          const SizedBox(height: 8),
          const _HowToRow(
            icon: Icons.toll_rounded,
            text: 'قيمة كل خانة 200 أو 400 أو 600 نقطة.',
          ),
          const SizedBox(height: 8),
          const _HowToRow(
            icon: Icons.keyboard_rounded,
            text:
                'أجب كتابةً لتأخذ النقاط كاملة، أو اكشف الخيارات مقابل نصف النقاط.',
          ),
          if (boss) ...[
            const SizedBox(height: 8),
            _HowToRow(
              icon: Icons.emoji_events_rounded,
              text: 'تنافس مع الزعماء — صاحب أعلى نقاط في النهاية يفوز.',
              color: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF7DD3FC);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: c, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rewards ───────────────────────────────────────────────────────────────────

class _RewardsCard extends StatelessWidget {
  const _RewardsCard({required this.stage});

  final CampaignStage stage;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'مكافأة المرحلة',
      icon: Icons.card_giftcard_rounded,
      accent: _gold,
      child: Row(
        children: [
          Expanded(
            child: _RewardTile(
              icon: Icons.monetization_on_rounded,
              value: '${stage.rewardCoins}',
              label: 'عملة',
              color: _gold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RewardTile(
              icon: Icons.diamond_rounded,
              value: '${stage.rewardGems}',
              label: 'جوهرة',
              color: const Color(0xFF6FE7FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RewardTile(
              icon: Icons.bolt_rounded,
              value: '${stage.rewardXp}',
              label: 'خبرة',
              color: const Color(0xFF54F088),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Best record ───────────────────────────────────────────────────────────────

class _BestRecordCard extends StatelessWidget {
  const _BestRecordCard({required this.progress});

  final StageProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF061642).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RecordMetric(
              icon: Icons.star_rounded,
              label: 'أفضل نجوم',
              value: '${progress.stars}/3',
              color: _gold,
            ),
          ),
          _divider(),
          Expanded(
            child: _RecordMetric(
              icon: Icons.leaderboard_rounded,
              label: 'أفضل نتيجة',
              value: '${progress.bestScore}',
              color: const Color(0xFF7DD3FC),
            ),
          ),
          _divider(),
          Expanded(
            child: _RecordMetric(
              icon: Icons.replay_rounded,
              label: 'المحاولات',
              value: '${progress.attempts}',
              color: const Color(0xFF54F088),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.12),
      );
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.accent,
    required this.launching,
    required this.onStart,
    required this.onMap,
  });

  final Color accent;
  final bool launching;
  final VoidCallback onStart;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF03081C).withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: launching ? null : onStart,
                icon: launching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 30),
                label: Text(launching ? 'جارٍ البدء...' : 'ابدأ المرحلة'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB22E),
                  disabledBackgroundColor: const Color(0xFF826646),
                  foregroundColor: const Color(0xFF321600),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  elevation: 10,
                  shadowColor: const Color(0xFFFFB22E).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 58,
            child: OutlinedButton.icon(
              onPressed: launching ? null : onMap,
              icon: const Icon(Icons.map_rounded),
              label: const Text('الخريطة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared building blocks ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF061642).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BlockingLoadingOverlay extends StatelessWidget {
  const _BlockingLoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF020B2A).withValues(alpha: 0.86),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF061642).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _gold),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'سيتم عرض نتيجة المرحلة خلال لحظات.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleHudButton extends StatelessWidget {
  const _CircleHudButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF06143D).withValues(alpha: 0.56),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

String _bossDifficultyLabel(int order) {
  if (order >= 30) return 'أسطوري';
  if (order >= 20) return 'صعب';
  return 'متوسط';
}
