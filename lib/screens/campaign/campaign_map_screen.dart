import '../../widgets/game_notice.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/campaign_navigation.dart';
import '../../models/campaign_stage.dart';
import '../../models/campaign_daily_progress.dart';
import '../../models/stage_progress.dart';
import '../../models/campaign_world.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/campaign_service.dart';
import '../../services/campaign_engagement_service.dart';
import '../../services/native_bridge_service.dart';
import 'stage_play_screen.dart';
import '../../models/store_catalog.dart';
import '../home/store_screen.dart';
import 'widgets/stage_node.dart';
import 'widgets/campaign_journey_panel.dart';
import '../../widgets/adaptive_asset_image.dart';

class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({super.key});

  static const routeName = '/campaign';

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final CampaignService _campaignService = CampaignService();
  late final AnimationController _pulseController;
  late final NativeBridgeService _nativeBridgeService;
  late Future<_CampaignMapData> _future;
  String? _loadedPlayerId;
  bool _openingStage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nativeBridgeService = context.read<NativeBridgeService>();
    _loadedPlayerId = context.read<AppState>().currentUser?.uid;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playCampaignMapMusic());
      _consumePendingCampaignResult();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      campaignRouteObserver.subscribe(this, route);
    }
    final playerId = context.watch<AppState>().currentUser?.uid;
    if (playerId != _loadedPlayerId) {
      _loadedPlayerId = playerId;
      _future = _load();
    }
  }

  @override
  void dispose() {
    campaignRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopCampaignMapMusic());
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _pulseController.stop();
    unawaited(_stopCampaignMapMusic());
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    _pulseController.repeat(reverse: true);
    unawaited(_reload());
    unawaited(_playCampaignMapMusic());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_playCampaignMapMusic());
      _consumePendingCampaignResult();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopCampaignMapMusic());
    }
  }

  Future<void> _playCampaignMapMusic() async {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    try {
      await _nativeBridgeService.playCampaignMapMusic();
    } catch (_) {}
  }

  Future<void> _stopCampaignMapMusic() async {
    try {
      await _nativeBridgeService.stopCampaignMapMusic();
    } catch (_) {}
  }

  Future<void> _consumePendingCampaignResult() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
      context: context,
    );
    if (mounted) {
      await _reload();
    }
  }

  Future<_CampaignMapData> _load() async {
    final uid = context.read<AppState>().currentUser?.uid.trim();
    final dailyFuture = CampaignEngagementService()
        .load(
          playerId: uid == null || uid.isEmpty ? 'guest' : uid,
          campaignId: 'main_campaign',
        )
        .catchError((Object _) => CampaignDailyProgress(
            dayKey: CampaignEngagementService.dayKey(DateTime.now())));
    final stages = await _campaignService.loadStages();
    final savedProgress = uid == null || uid.isEmpty
        ? const <String, StageProgress>{}
        : await _campaignService.loadUserProgress(uid: uid);
    final progress = _campaignService.resolveProgressForStages(
      stages: stages,
      savedProgress: savedProgress,
    );
    final daily = await dailyFuture;
    return _CampaignMapData(stages: stages, progress: progress, daily: daily);
  }

  Future<void> _reload() async {
    if (mounted) context.read<AppState>().loadEconomy();
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: FutureBuilder<_CampaignMapData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _MapScaffoldBackground(child: _LoadingState());
            }
            if (snapshot.hasError) {
              return _MapScaffoldBackground(
                child: _ErrorState(onRetry: _reload),
              );
            }
            final data = snapshot.data;
            if (data == null || data.stages.isEmpty) {
              return _MapScaffoldBackground(
                child: _EmptyState(onRetry: _reload),
              );
            }
            return _CampaignMapContent(
              data: data,
              campaignService: _campaignService,
              pulseAnimation: _pulseController,
              onRefresh: _reload,
              onLockedTap: _showLockedMessage,
              onStageTap: _playStage,
            );
          },
        ),
      ),
    );
  }

  void _showLockedMessage(CampaignStage stage) {
    GameNoticeMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'أكمل المرحلة السابقة أولًا لفتح هذه المرحلة.',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  Future<void> _playStage(
    CampaignStage stage,
    StageProgress progress,
  ) async {
    if (_openingStage) return;
    _openingStage = true;
    try {
      await _stopCampaignMapMusic();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StagePlayScreen(stage: stage, progress: progress),
        ),
      );
    } finally {
      _openingStage = false;
    }
  }
}

class _CampaignMapContent extends StatefulWidget {
  const _CampaignMapContent({
    required this.data,
    required this.campaignService,
    required this.pulseAnimation,
    required this.onRefresh,
    required this.onLockedTap,
    required this.onStageTap,
  });

  final _CampaignMapData data;
  final CampaignService campaignService;
  final Animation<double> pulseAnimation;
  final Future<void> Function() onRefresh;
  final void Function(CampaignStage stage) onLockedTap;
  final void Function(CampaignStage stage, StageProgress progress) onStageTap;

  @override
  State<_CampaignMapContent> createState() => _CampaignMapContentState();
}

class _CampaignMapContentState extends State<_CampaignMapContent> {
  late final PageController _pageController;
  late int _selectedWorldIndex;

  @override
  void initState() {
    super.initState();
    _selectedWorldIndex = _initialWorldIndex();
    _pageController = PageController(initialPage: _selectedWorldIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheWorld(_selectedWorldIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStars = widget.campaignService.totalStars(widget.data.progress);
    final completedStages = widget.data.progress
        .where(widget.campaignService.isStageCompleted)
        .length;
    final worlds = _worldStageBundles();
    final selectedWorld =
        campaignWorlds[_selectedWorldIndex.clamp(0, campaignWorlds.length - 1)];
    final continueStage = _continueStage();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final wide = MediaQuery.sizeOf(context).width >= 700 && textScale < 1.4;
    final footerHeight =
        (wide ? 74.0 : 124.0) + math.max(0, textScale - 1) * 60;
    final journeyBar = CampaignJourneyBar(
      compact: true,
      daily: widget.data.daily,
      onDailyTap: () => _showJourney(worlds[_selectedWorldIndex]),
      continueStage: continueStage,
      onContinue:
          continueStage == null ? null : () => _openStage(continueStage),
    );
    final worldControls = _WorldPagerControls(
      world: selectedWorld,
      selectedIndex: _selectedWorldIndex,
      completedStages: worlds[_selectedWorldIndex].completedStages,
      totalStages: worlds[_selectedWorldIndex].stages.length,
      stars: worlds[_selectedWorldIndex]
          .progress
          .fold<int>(0, (sum, p) => sum + p.stars),
      onPrevious: _selectedWorldIndex == 0
          ? null
          : () => _goToWorld(_selectedWorldIndex - 1),
      onNext: _selectedWorldIndex == campaignWorlds.length - 1
          ? null
          : () => _goToWorld(_selectedWorldIndex + 1),
      onDotTap: _goToWorld,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: worlds.length,
            onPageChanged: (index) {
              setState(() {
                _selectedWorldIndex = index;
              });
              _precacheWorld(index);
            },
            itemBuilder: (context, index) {
              return _WorldMapPage(
                bundle: worlds[index],
                campaignService: widget.campaignService,
                pulseAnimation: widget.pulseAnimation,
                onLockedTap: widget.onLockedTap,
                onStageTap: widget.onStageTap,
                onRefresh: widget.onRefresh,
                bottomOverlaySpace: bottomInset + footerHeight,
              );
            },
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MapTopOverlay(
            totalStars: totalStars,
            completedStages: completedStages,
            totalStages: widget.data.stages.length,
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10,
          child: SafeArea(
            top: false,
            child: wide
                ? Row(children: [
                    Expanded(flex: 5, child: journeyBar),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: worldControls),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    journeyBar,
                    const SizedBox(height: 6),
                    worldControls,
                  ]),
          ),
        ),
      ],
    );
  }

  CampaignStage? _continueStage() {
    for (var index = 0; index < widget.data.stages.length; index++) {
      if (widget.data.progress[index].status == StageProgressStatus.unlocked) {
        return widget.data.stages[index];
      }
    }
    return CampaignEngagementService().recommendedStage(
      stages: widget.data.stages,
      progress: widget.data.progress,
    );
  }

  void _openStage(CampaignStage stage) {
    final index = widget.data.stages.indexWhere((item) => item.id == stage.id);
    if (index < 0) return;
    widget.onStageTap(stage, widget.data.progress[index]);
  }

  Future<void> _showJourney(_WorldStageBundle bundle) async {
    final recommended = CampaignEngagementService().recommendedStage(
      stages: widget.data.stages,
      progress: widget.data.progress,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10283E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      builder: (sheetContext) => CampaignJourneySheet(
        daily: widget.data.daily,
        worldName: bundle.world.name,
        worldStars: bundle.progress.fold<int>(0, (sum, p) => sum + p.stars),
        worldMaxStars: bundle.stages.length * 3,
        recommendedStage: recommended,
        onRecommendedTap: recommended == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                _openStage(recommended);
              },
      ),
    );
  }

  int _initialWorldIndex() {
    final allUnlocked = widget.data.progress.isNotEmpty &&
        widget.data.progress.every(
          (progress) => progress.status != StageProgressStatus.locked,
        );
    final hasCompleted = widget.data.progress.any(
      widget.campaignService.isStageCompleted,
    );
    if (allUnlocked && !hasCompleted) return 0;

    final nextPlayableIndex = widget.data.progress.indexWhere(
      (progress) =>
          progress.status == StageProgressStatus.unlocked &&
          !widget.campaignService.isStageCompleted(progress),
    );
    final stageIndex = nextPlayableIndex >= 0
        ? nextPlayableIndex
        : math.max(
            0,
            widget.data.progress
                    .where(widget.campaignService.isStageCompleted)
                    .length -
                1,
          );
    if (stageIndex >= widget.data.stages.length) return 0;
    return campaignWorldIndexForStageOrder(
        widget.data.stages[stageIndex].order);
  }

  List<_WorldStageBundle> _worldStageBundles() {
    final progressByStageId = {
      for (final progress in widget.data.progress) progress.stageId: progress,
    };
    return [
      for (final world in campaignWorlds)
        _WorldStageBundle(
          world: world,
          stages: widget.data.stages
              .where((stage) => world.containsStageOrder(stage.order))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order)),
          progressByStageId: progressByStageId,
          campaignService: widget.campaignService,
        ),
    ];
  }

  void _goToWorld(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _precacheWorld(int index) {
    if (!mounted) return;
    for (final candidate in <int>[index, index - 1, index + 1]) {
      if (candidate < 0 || candidate >= campaignWorlds.length) continue;
      precacheImage(
        AssetImage(campaignWorlds[candidate].backgroundAsset),
        context,
      );
    }
  }
}

class _WorldMapPage extends StatefulWidget {
  const _WorldMapPage({
    required this.bundle,
    required this.campaignService,
    required this.pulseAnimation,
    required this.onLockedTap,
    required this.onStageTap,
    required this.onRefresh,
    required this.bottomOverlaySpace,
  });

  final _WorldStageBundle bundle;
  final CampaignService campaignService;
  final Animation<double> pulseAnimation;
  final void Function(CampaignStage stage) onLockedTap;
  final void Function(CampaignStage stage, StageProgress progress) onStageTap;
  final Future<void> Function() onRefresh;
  final double bottomOverlaySpace;

  static const Size _backgroundSourceSize = Size(1672, 941);

  @override
  State<_WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<_WorldMapPage> {
  final ScrollController _scrollController = ScrollController();
  double? _lastInitialScrollExtent;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final mapHeight = _mapContentHeight(Size(width, height));
          final contentHeight = mapHeight + widget.bottomOverlaySpace;
          final currentIndex = widget.bundle.stages
              .indexWhere((stage) => stage.id == widget.bundle.currentStageId);
          final focusY = currentIndex >= 0
              ? widget.bundle.world.nodePositions[currentIndex].dy * mapHeight
              : contentHeight;
          final usableHeight =
              math.max(0.0, height - widget.bottomOverlaySpace);
          final initialScrollExtent = (focusY - usableHeight * 0.55)
              .clamp(0.0, math.max(0.0, contentHeight - height));
          _jumpToBottomAfterLayout(initialScrollExtent.toDouble());
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: SizedBox(
              width: width,
              height: contentHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: mapHeight,
                    child: adaptiveAssetImage(
                      widget.bundle.world.backgroundAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  // Continue the bottom edge behind the floating controls
                  // without stretching the map away from its stage positions.
                  Positioned(
                    top: mapHeight,
                    left: 0,
                    right: 0,
                    height: widget.bottomOverlaySpace,
                    child: ClipRect(
                      child: Transform.flip(
                        flipY: true,
                        child: OverflowBox(
                          alignment: Alignment.bottomCenter,
                          minHeight: mapHeight,
                          maxHeight: mapHeight,
                          child: adaptiveAssetImage(
                            widget.bundle.world.backgroundAsset,
                            width: width,
                            height: mapHeight,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0;
                      index < widget.bundle.stages.length;
                      index += 1)
                    _buildStageNode(
                      size: Size(width, mapHeight),
                      index: index,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _jumpToBottomAfterLayout(double initialScrollExtent) {
    if (_lastInitialScrollExtent == initialScrollExtent) return;
    _lastInitialScrollExtent = initialScrollExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(initialScrollExtent);
    });
  }

  Widget _buildStageNode({
    required Size size,
    required int index,
  }) {
    final stage = widget.bundle.stages[index];
    final progress = widget.bundle.progress[index];
    final position = _mapPosition(
      widget.bundle.world.nodePositions[index],
      size,
    );

    return Positioned(
      left: position.dx - StageNode.hitWidth / 2,
      top: position.dy - StageNode.centerOffsetFor(stage),
      child: StageNode(
        stage: stage,
        progress: progress,
        locked: progress.status == StageProgressStatus.locked,
        completed: widget.campaignService.isStageCompleted(progress),
        current: widget.bundle.currentStageId == stage.id &&
            progress.status != StageProgressStatus.locked,
        animation: widget.pulseAnimation,
        onTap: () {
          if (progress.status == StageProgressStatus.locked) {
            widget.onLockedTap(stage);
          } else {
            widget.onStageTap(stage, progress);
          }
        },
      ),
    );
  }

  double _mapContentHeight(Size viewportSize) {
    final naturalHeight = viewportSize.width *
        _WorldMapPage._backgroundSourceSize.height /
        _WorldMapPage._backgroundSourceSize.width;
    return math.max(viewportSize.height, naturalHeight);
  }

  Offset _mapPosition(Offset imagePosition, Size mapSize) {
    return Offset(
      imagePosition.dx * mapSize.width,
      imagePosition.dy * mapSize.height,
    );
  }
}

class _WorldStageBundle {
  _WorldStageBundle({
    required this.world,
    required this.stages,
    required Map<String, StageProgress> progressByStageId,
    required CampaignService campaignService,
  })  : progress = [
          for (final stage in stages)
            progressByStageId[stage.id] ??
                StageProgress.empty().copyWith(
                  campaignId: stage.campaignId,
                  stageId: stage.id,
                ),
        ],
        completedStages = stages
            .map((stage) => progressByStageId[stage.id])
            .whereType<StageProgress>()
            .where(campaignService.isStageCompleted)
            .length,
        currentStageId = _currentStageId(
          stages,
          progressByStageId,
          campaignService,
        );

  final CampaignWorld world;
  final List<CampaignStage> stages;
  final List<StageProgress> progress;
  final int completedStages;
  final String? currentStageId;

  static String? _currentStageId(
    List<CampaignStage> stages,
    Map<String, StageProgress> progressByStageId,
    CampaignService campaignService,
  ) {
    for (final stage in stages) {
      final progress = progressByStageId[stage.id];
      if (progress == null) continue;
      if (progress.status == StageProgressStatus.unlocked &&
          !campaignService.isStageCompleted(progress)) {
        return stage.id;
      }
    }
    return null;
  }
}

class _WorldPagerControls extends StatelessWidget {
  const _WorldPagerControls({
    required this.world,
    required this.selectedIndex,
    required this.completedStages,
    required this.totalStages,
    required this.stars,
    required this.onPrevious,
    required this.onNext,
    required this.onDotTap,
  });

  final CampaignWorld world;
  final int selectedIndex;
  final int completedStages;
  final int totalStages;
  final int stars;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F9E8).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              _WorldArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: onPrevious,
              ),
              Expanded(
                child: Text(
                  '${world.name}  •  $completedStages/$totalStages  •  $stars/${totalStages * 3} ★',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF173B2B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _WorldArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: onNext,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < campaignWorlds.length; index += 1)
              GestureDetector(
                onTap: () => onDotTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == selectedIndex ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == selectedIndex
                        ? const Color(0xFFFFD84D)
                        : Colors.white.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WorldArrowButton extends StatelessWidget {
  const _WorldArrowButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(
        icon,
        color:
            onTap == null ? const Color(0x66173B2B) : const Color(0xFF173B2B),
        size: 26,
      ),
    );
  }
}

class _MapScaffoldBackground extends StatelessWidget {
  const _MapScaffoldBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8CF04A), Color(0xFF25B62A), Color(0xFF087A27)],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

class _MapTopOverlay extends StatelessWidget {
  const _MapTopOverlay({
    required this.totalStars,
    required this.completedStages,
    required this.totalStages,
  });

  final int totalStars;
  final int completedStages;
  final int totalStages;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Row(
          children: [
            _OverlayIconButton(
              icon: Icons.arrow_forward_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('تحدي المراحل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ]))),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: math.max(
                      1.0,
                      MediaQuery.sizeOf(context).width -
                          MediaQuery.paddingOf(context).horizontal -
                          110)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _OverlayChip(
                    icon: Icons.flag_rounded,
                    label: '$completedStages/$totalStages',
                    color: const Color(0xFF55F07A),
                  ),
                  const SizedBox(width: 7),
                  _OverlayChip(
                    icon: Icons.star_rounded,
                    label: '$totalStars',
                    color: const Color(0xFFFFD84D),
                  ),
                  const SizedBox(width: 7),
                  Consumer<AppState>(builder: (context, app, _) {
                    final balance = app.economyLoaded
                        ? '${app.economyWallet.totalHearts}'
                        : '…';
                    void openShop() => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const StoreScreen(
                                initialKind: StoreProductKind.resource)));
                    return Semantics(
                      key: const ValueKey('campaign-hearts-balance'),
                      label:
                          'رصيد القلوب: ${app.economyLoaded ? balance : 'جارٍ التحميل'}',
                      hint: 'فتح أرصدة اللعب',
                      button: true,
                      onTap: openShop,
                      excludeSemantics: true,
                      child: Tooltip(
                        message: '$balance قلوب',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: openShop,
                            borderRadius: BorderRadius.circular(999),
                            child: _OverlayChip(
                              icon: Icons.favorite_rounded,
                              label: balance,
                              color: Colors.pinkAccent,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0C3B25).withValues(alpha: 0.50),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
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
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0C3B25).withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignMapData {
  const _CampaignMapData({
    required this.stages,
    required this.progress,
    required this.daily,
  });

  final List<CampaignStage> stages;
  final List<StageProgress> progress;
  final CampaignDailyProgress daily;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFFACC15)),
          SizedBox(height: 12),
          Text(
            'جاري تحميل تحدي المراحل...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Color(0x88000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFF87171),
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            'تعذر تحميل الخريطة الآن.',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: Color(0xFF7DD3FC), size: 42),
          const SizedBox(height: 10),
          const Text(
            'لا توجد مراحل متاحة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'تعذر تحميل المراحل. حاول مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
