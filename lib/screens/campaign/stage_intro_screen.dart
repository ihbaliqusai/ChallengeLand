import '../../widgets/game_back_button.dart';
import '../../widgets/game_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/campaign_stage.dart';
import '../../models/stage_progress.dart';
import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/store_catalog.dart';
import '../home/store_screen.dart';
import '../home/resource_shop_screen.dart';
import '../../services/campaign_defaults.dart';
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
    this.continuingJourney = false,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final bool continuingJourney;

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
      context.read<AppState>().loadEconomy();
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
      knownStage: widget.stage,
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
    GameNoticeMessenger.of(context)
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
    final messenger = GameNoticeMessenger.of(context);
    final stage = widget.stage;

    try {
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
        campaignEntry: widget.continuingJourney
            ? 'next'
            : widget.progress.attempts > 0
                ? 'retry'
                : 'stage',
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
        boardTwoStarScore: launchConfig['boardTwoStarScore'] as int? ??
            stage.starRules.twoStarsMinScore,
        boardThreeStarScore: launchConfig['boardThreeStarScore'] as int? ??
            stage.starRules.threeStarsMinScore,
        boardSoloPicks: launchConfig['boardSoloPicks'] as int? ?? 6,
        boardSoloCols: launchConfig['boardSoloCols'] as int? ?? 4,
        boardBotCount: launchConfig['boardBotCount'] as int? ?? 0,
        boardBotIntelligence: launchConfig['boardBotIntelligence'] as int? ?? 0,
        boardRequiredCategoryCount:
            launchConfig['boardRequiredCategoryCount'] as int? ?? 0,
        bossStyle: launchConfig['bossStyle'] as String? ?? 'balanced',
        boardAllowRevealOptions:
            launchConfig['boardAllowRevealOptions'] as bool? ?? true,
        boardDesignVersion: launchConfig['boardDesignVersion'] as int? ?? 0,
        categoryPolicy:
            launchConfig['categoryPolicy'] as String? ?? 'playerPick',
        worldCategories: (launchConfig['worldCategories'] as List<dynamic>? ??
                const <dynamic>[])
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
    final isBoss = stage.isBossStage;
    final accent = isBoss ? const Color(0xFFFF3366) : const Color(0xFF38BDF8);
    final worldIndex = ((stage.order - 1) ~/ 10)
        .clamp(0, CampaignDefaults.worldNames.length - 1);
    final worldName = CampaignDefaults.worldNames[worldIndex];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LevelCompleteBackground()),
            // Ambient soft glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.2,
                    colors: [
                      accent.withValues(alpha: 0.18),
                      const Color(0xFF030A24).withValues(alpha: 0.85),
                      const Color(0xFF020718),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Consumer<AppState>(
                          builder: (context, app, _) => ResourceBalance(
                              icon: Icons.favorite_rounded,
                              label: 'قلوب',
                              value: app.economyWallet.totalHearts,
                              loaded: app.economyLoaded,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => const StoreScreen(
                                          initialKind:
                                              StoreProductKind.resource)))))),
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
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: Column(
                            children: [
                              _StageHeroCard(
                                stage: stage,
                                progress: progress,
                                accent: accent,
                                worldName: worldName,
                              ),
                              const SizedBox(height: 14),
                              _MissionAndStarsCard(
                                stage: stage,
                                progress: progress,
                                accent: accent,
                              ),
                              const SizedBox(height: 14),
                              _DualStatsRow(
                                stage: stage,
                                progress: progress,
                                accent: accent,
                              ),
                              const SizedBox(height: 14),
                              _QuickGuideBanner(
                                isBoss: isBoss,
                                accent: accent,
                              ),
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
              Positioned.fill(
                child: _BlockingLoadingOverlay(
                  message: _waitingForResult
                      ? 'جارٍ استلام نتيجة المرحلة...'
                      : 'جارٍ تجهيز المرحلة...',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top Navigation Bar ─────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onLeaderboard});

  final VoidCallback onBack;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370 ||
        MediaQuery.textScalerOf(context).scale(13.5) > 18;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          GameBackButton(onPressed: onBack),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تفاصيل المرحلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xAA000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onLeaderboard,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.22),
                      const Color(0xFFFFA000).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.20),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700),
                      size: 17,
                    ),
                    if (!compact) const SizedBox(width: 6),
                    if (!compact)
                      const Text(
                        'المتصدرون',
                        style: TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Stage Header Card ───────────────────────────────────────────────────

class _StageHeroCard extends StatelessWidget {
  const _StageHeroCard({
    required this.stage,
    required this.progress,
    required this.accent,
    required this.worldName,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;
  final String worldName;

  @override
  Widget build(BuildContext context) {
    final isBoss = stage.isBossStage;
    final earnedStars = progress.stars;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            const Color(0xFF08163E).withValues(alpha: 0.95),
            const Color(0xFF040C26).withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _StageCrestBadge(
            order: stage.order,
            isBoss: isBoss,
            size: MediaQuery.sizeOf(context).width < 370 ? 60 : 76,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBoss
                                ? Icons.local_fire_department_rounded
                                : Icons.explore_rounded,
                            color: isBoss
                                ? const Color(0xFFFF7A00)
                                : const Color(0xFF7DD3FC),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              worldName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isBoss)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF2A55).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFFFF2A55).withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'زعيم العالم',
                          style: TextStyle(
                            color: Color(0xFFFF85A1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stage.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0xDD000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 3D Star Rating Display
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    StarRatingView(stars: earnedStars, size: 24),
                    Text(
                      earnedStars == 3
                          ? 'مكتملة بالكامل 👑'
                          : earnedStars > 0
                              ? '$earnedStars من 3 نجوم'
                              : 'غير مكتملة بعد',
                      style: TextStyle(
                        color: earnedStars > 0
                            ? const Color(0xFFFFD54F)
                            : Colors.white60,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stage 3D Crest Badge ─────────────────────────────────────────────────────

class _StageCrestBadge extends StatelessWidget {
  const _StageCrestBadge(
      {required this.order, required this.isBoss, this.size = 76});

  final int order;
  final bool isBoss;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBoss
              ? const [Color(0xFFFF8008), Color(0xFFFFC837), Color(0xFFFF3366)]
              : const [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF1E3A8A)],
        ),
        border: Border.all(
          color: Colors.white,
          width: 2.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isBoss ? const Color(0xFFFF3366) : const Color(0xFF38BDF8))
                .withValues(alpha: 0.5),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBoss)
              const Icon(
                Icons.military_tech_rounded,
                color: Colors.white,
                size: 18,
              ),
            FittedBox(
              child: Text(
                '$order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isBoss ? 24 : 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Core Mission & Stars Dashboard Card ──────────────────────────────────────

class _MissionAndStarsCard extends StatelessWidget {
  const _MissionAndStarsCard({
    required this.stage,
    required this.progress,
    required this.accent,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isBoss = stage.isBossStage;
    final target = stage.boardTargetScore;
    final starRules = stage.starRules;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF06143A).withValues(alpha: 0.88),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
              ),
              const Text(
                'هدف المرحلة والنجوم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  isBoss
                      ? 'مواجهة ${stage.botCount > 0 ? stage.botCount : 1} زعماء'
                      : '${stage.boardSoloPicks} اختيارات على اللوحة',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Objective Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  const Color(0xFF041030).withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBoss ? Icons.shield_rounded : Icons.gps_fixed_rounded,
                  color: accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBoss
                            ? 'اهزم الزعيم واحتل المركز الأول'
                            : 'الهدف المطلوب: $target نقطة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage.boardRulesText.isNotEmpty
                            ? stage.boardRulesText
                            : isBoss
                                ? 'اجمع أعلى مجموع نقاط في نهاية الأدوار لفتح العالم التالي'
                                : 'اختر الأسئلة بذكاء من اللوحة لتحقيق هذا المجموع أو أكثر',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Star Milestone Tier Cards
          Row(
            children: [
              Expanded(
                child: _StarMilestoneNode(
                  starCount: 1,
                  label: isBoss ? 'الفوز' : '$target',
                  unit: isBoss ? 'بالمركز 1' : 'نقطة',
                  isAchieved: progress.stars >= 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StarMilestoneNode(
                  starCount: 2,
                  label: '${starRules.twoStarsMinScore}',
                  unit: 'نقطة',
                  isAchieved: progress.stars >= 2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StarMilestoneNode(
                  starCount: 3,
                  label: '${starRules.threeStarsMinScore}',
                  unit: 'نقطة',
                  isAchieved: progress.stars >= 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isBoss
                ? 'كل النجوم تتطلب الفوز بالمركز الأول؛ ثم تُحسب حسب نقاطك.'
                : 'كل النجوم تتطلب إكمال هدف المرحلة؛ ثم تُحسب حسب نقاطك.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (progress.attempts > 0 && progress.stars < 3) ...[
            const SizedBox(height: 10),
            _ReplayGoal(stage: stage, progress: progress, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _StarMilestoneNode extends StatelessWidget {
  const _StarMilestoneNode({
    required this.starCount,
    required this.label,
    required this.unit,
    required this.isAchieved,
  });

  final int starCount;
  final String label;
  final String unit;
  final bool isAchieved;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isAchieved
            ? gold.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAchieved
              ? gold.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.15),
          width: isAchieved ? 1.4 : 1,
        ),
        boxShadow: isAchieved
            ? [
                BoxShadow(
                  color: gold.withValues(alpha: 0.22),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              starCount,
              (index) => const Icon(
                Icons.star_rounded,
                color: gold,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isAchieved ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: isAchieved ? const Color(0xFFFFE082) : Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dual Stats Row (Rewards + Personal Best) ─────────────────────────────────

class _DualStatsRow extends StatelessWidget {
  const _DualStatsRow({
    required this.stage,
    required this.progress,
    required this.accent,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rewards = _detailCard(
      title: 'مكافآت الإتقان',
      icon: Icons.card_giftcard_rounded,
      color: const Color(0xFFFFD700),
      children: [
        if (stage.rewardCoins > 0)
          _RewardMiniBadge(
            icon: Icons.monetization_on_rounded,
            label: 'حتى ${stage.rewardCoins} ذهب',
            color: const Color(0xFFFFD700),
          ),
        if (stage.rewardGems > 0)
          _RewardMiniBadge(
            icon: Icons.diamond_rounded,
            label: 'حتى ${stage.rewardGems} جوهرة',
            color: const Color(0xFF38BDF8),
          ),
        if (stage.rewardXp > 0)
          _RewardMiniBadge(
            icon: Icons.bolt_rounded,
            label: 'حتى ${stage.rewardXp} خبرة',
            color: const Color(0xFF10B981),
          ),
        const Text(
          'تُمنح عند أول فوز وتحسين النجوم، حتى اكتمال 3 نجوم.',
          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
        ),
      ],
    );
    final record = _detailCard(
      title: 'سجلك بالمرحلة',
      icon: Icons.history_rounded,
      color: accent,
      children: [
        _RecordMiniRow(
          label: 'أفضل نتيجة',
          value: progress.attempts > 0 ? '${progress.bestScore}' : '—',
          color: accent,
        ),
        _RecordMiniRow(
          label: 'النجوم',
          value: '${progress.stars} / 3',
          color: const Color(0xFFFFD700),
        ),
        _RecordMiniRow(
          label: 'المحاولات',
          value: '${progress.attempts}',
          color: const Color(0xFF10B981),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        if (compact) {
          return Column(
            children: [rewards, const SizedBox(height: 12), record],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: rewards),
            const SizedBox(width: 12),
            Expanded(child: record),
          ],
        );
      },
    );
  }

  Widget _detailCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF06143A).withValues(alpha: 0.88),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            for (final child in children) ...[
              const SizedBox(height: 8),
              child,
            ],
          ],
        ),
      );
}

class _ReplayGoal extends StatelessWidget {
  const _ReplayGoal({
    required this.stage,
    required this.progress,
    required this.accent,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final nextStars = progress.stars + 1;
    final target = progress.stars == 0
        ? stage.boardTargetScore
        : progress.stars == 1
            ? stage.starRules.twoStarsMinScore
            : stage.starRules.threeStarsMinScore;
    final message = progress.stars == 0 && stage.isBossStage
        ? 'مهمتك التالية: تفوّق على جميع الزعماء واحصل على أول نجمة.'
        : 'مهمتك التالية: $target نقطة في محاولة ناجحة للوصول إلى $nextStars نجوم.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: accent,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _RewardMiniBadge extends StatelessWidget {
  const _RewardMiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordMiniRow extends StatelessWidget {
  const _RecordMiniRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
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

// ── Quick Guide Compact Banner ───────────────────────────────────────────────

class _QuickGuideBanner extends StatelessWidget {
  const _QuickGuideBanner({
    required this.isBoss,
    required this.accent,
  });

  final bool isBoss;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF040E2C).withValues(alpha: 0.75),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded,
              color: Color(0xFFFFD700), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${isBoss ? 'الكتابة: النقاط كاملة • كشف الخيارات: نصف النقاط، لك وللزعماء. راقب رصيد الخصوم واختر فئاتك الأقوى.' : 'الكتابة: النقاط كاملة • كشف الخيارات: نصف النقاط. اختر الأسئلة بحسب ثقتك بالإجابة وقيمتها.'} تستخدم المرحلة التصنيفات المفتوحة في حسابك.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Floating Bar with CTA ─────────────────────────────────────────────

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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF020718),
              const Color(0xFF020718).withValues(alpha: 0.8),
              Colors.transparent
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) > 22;
            final start = FilledButton.icon(
              onPressed: launching
                  ? null
                  : () {
                      AppSettings.playClick();
                      onStart();
                    },
              icon: launching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.play_arrow_rounded, size: 26),
              label: Text(launching ? 'جارٍ التجهيز...' : 'ابدأ المرحلة'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF331600),
                disabledBackgroundColor: const Color(0xFF536178),
                minimumSize: const Size(0, 54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            );
            final map = TextButton.icon(
              onPressed: launching
                  ? null
                  : () {
                      AppSettings.playClick();
                      onMap();
                    },
              icon: const Icon(Icons.map_rounded, size: 20),
              label: const Text('الخريطة'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFBDEBFF),
                minimumSize: const Size(48, 44),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            );
            if (compact) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: double.infinity, child: start),
                map
              ]);
            }
            return Row(children: [
              Expanded(child: start),
              const SizedBox(width: 12),
              map
            ]);
          },
        ),
      );
}
// ── Loading Overlay ───────────────────────────────────────────────────────────

class _BlockingLoadingOverlay extends StatelessWidget {
  const _BlockingLoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF020B2A).withValues(alpha: 0.88),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF061642).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFD700)),
              const SizedBox(height: 16),
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
                'سيتم فتح لوحة التحدي خلال لحظات.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
