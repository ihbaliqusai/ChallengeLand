import '../../widgets/game_notice.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/campaign_stage.dart';
import '../../models/stage_progress.dart';
import '../../services/campaign_mode_engine.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/native_bridge_service.dart';

/// Launches native play immediately and receives its result on return.
class StagePlayScreen extends StatefulWidget {
  const StagePlayScreen({
    super.key,
    required this.stage,
    required this.progress,
    this.continuingJourney = false,
  });

  final CampaignStage stage;
  final StageProgress progress;
  final bool continuingJourney;

  @override
  State<StagePlayScreen> createState() => _StagePlayScreenState();
}

class _StagePlayScreenState extends State<StagePlayScreen>
    with WidgetsBindingObserver {
  Timer? _resultRetry;
  Timer? _resultTimeout;
  bool _launching = false;
  bool _consumingResult = false;
  bool _waitingForResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AppState>().loadEconomy());
      unawaited(_launchStage());
    });
  }

  @override
  void dispose() {
    _resultRetry?.cancel();
    _resultTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launching) {
      _resultTimeout ??= Timer(const Duration(seconds: 8), () {
        if (mounted && _launching) {
          _returnToMap('لم تصل نتيجة المرحلة. حاول بدء المرحلة مرة أخرى.');
        }
      });
      setState(() => _waitingForResult = true);
      unawaited(_consumeResult());
    }
  }

  Future<void> _consumeResult() async {
    if (!mounted || !_launching || _consumingResult) return;
    _consumingResult = true;
    final handled =
        await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
      context: context,
      knownStage: widget.stage,
    );
    _consumingResult = false;
    if (!mounted) return;
    if (handled) {
      _launching = false;
      _resultRetry?.cancel();
      _resultTimeout?.cancel();
      // A valid result replaces this route. Validation failures instead leave
      // a message, so return to the map in that case.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }
    _resultRetry?.cancel();
    _resultRetry = Timer(const Duration(milliseconds: 350), _consumeResult);
  }

  void _returnToMap(String message) {
    _launching = false;
    _resultRetry?.cancel();
    _resultTimeout?.cancel();
    final messenger = GameNoticeMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message, textAlign: TextAlign.right)));
  }

  Future<void> _launchStage() async {
    if (_launching) return;
    setState(() => _launching = true);
    final stage = widget.stage;
    final config = const CampaignModeEngine().buildLaunchConfig(stage);
    try {
      await context.read<NativeBridgeService>().launchCampaignStage(
            campaignEntry: widget.continuingJourney
                ? 'next'
                : widget.progress.attempts > 0
                    ? 'retry'
                    : 'stage',
            campaignId: config['campaignId'] as String,
            stageId: config['stageId'] as String,
            stageType: config['stageType'] as String,
            campaignMode: config['campaignMode'] as String,
            winCondition: config['winCondition'] as String,
            questionIds: const <int>[],
            allowedLevels: stage.allowedLevels
                .where((level) => level.trim().isNotEmpty)
                .toList(growable: false),
            questionCount: config['questionCount'] as int,
            timeLimitSeconds: config['timeLimitSeconds'] as int,
            allow5050: config['allow5050'] as bool,
            allowAudience: config['allowAudience'] as bool,
            allowCall: config['allowCall'] as bool,
            maxWrongAnswers: config['maxWrongAnswers'] as int,
            campaignBoard: config['campaignBoard'] as bool,
            boardKind: config['boardKind'] as String,
            boardTargetScore: config['boardTargetScore'] as int,
            boardTwoStarScore: config['boardTwoStarScore'] as int,
            boardThreeStarScore: config['boardThreeStarScore'] as int,
            boardSoloPicks: config['boardSoloPicks'] as int,
            boardSoloCols: config['boardSoloCols'] as int,
            boardBotCount: config['boardBotCount'] as int,
            boardBotIntelligence: config['boardBotIntelligence'] as int,
            boardRequiredCategoryCount:
                config['boardRequiredCategoryCount'] as int,
            bossStyle: config['bossStyle'] as String,
            boardAllowRevealOptions: config['boardAllowRevealOptions'] as bool,
            boardDesignVersion: config['boardDesignVersion'] as int,
            categoryPolicy: config['categoryPolicy'] as String,
            worldCategories: (config['worldCategories'] as List).cast<String>(),
          );
    } catch (_) {
      if (mounted) _returnToMap('تعذر بدء المرحلة. حاول مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_launching,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFF020718),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFFD700)),
                  const SizedBox(height: 16),
                  Text(
                    _waitingForResult
                        ? 'جارٍ استلام نتيجة المرحلة...'
                        : 'جارٍ بدء المرحلة...',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
