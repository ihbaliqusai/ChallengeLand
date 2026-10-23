import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/campaign_stage.dart';
import '../models/stage_attempt.dart';
import '../models/stage_progress.dart';
import '../screens/campaign/stage_result_screen.dart';
import 'campaign_service.dart';
import 'campaign_engagement_service.dart';
import 'native_bridge_service.dart';

class CampaignResultHandler {
  CampaignResultHandler._();

  static bool _processing = false;
  static Future<void>? _rewardRecovery;
  static String? _recoveryUid;
  static DateTime? _lastRecovery;

  static Future<bool> consumeAndHandlePendingCampaignResult({
    required BuildContext context,
    CampaignStage? knownStage,
    CampaignService? service,
  }) async {
    if (!_isCurrentRoute(context)) return false;
    if (_processing) return false;
    _processing = true;
    try {
      final nativeBridge = context.read<NativeBridgeService>();
      final campaignService = service ?? CampaignService();
      final appState = context.read<AppState>();
      final payload = await nativeBridge.consumePendingCampaignStageResult();
      if (payload == null) {
        _recoverRewardsInBackground(appState, campaignService);
        return false;
      }
      final owner = payload['accountUid']?.toString().trim() ?? '';
      final activeUid = appState.currentUser?.uid ?? 'guest_local';
      bool accountIsActive() =>
          (appState.currentUser?.uid ?? 'guest_local') == activeUid;
      if (owner.isNotEmpty && owner != activeUid) {
        // Native stores pending results by account. Reject mismatched older
        // payloads as well, before creating progress or reward claims.
        return false;
      }
      if (payload['mode'] != null && payload['mode'].toString() != 'campaign') {
        return false;
      }
      if (!_hasCompleteCampaignResult(payload)) {
        if (context.mounted) {
          _showSnack(context, 'نتيجة المرحلة غير مكتملة. حاول مرة أخرى.');
        }
        return true;
      }
      // Keep pre-attemptId native results stable while their local result screen
      // retries a save after a connection failure.
      if ((payload['attemptId'] ?? '').toString().trim().isEmpty) {
        payload['attemptId'] =
            'campaign_local_${DateTime.now().microsecondsSinceEpoch}';
      }

      final campaignId =
          (payload['campaignId'] ?? 'main_campaign').toString().trim();
      final stageId = (payload['stageId'] ?? '').toString().trim();
      if (campaignId.isEmpty || stageId.isEmpty) {
        if (context.mounted) {
          _showSnack(context, 'تعذر العثور على بيانات المرحلة.');
        }
        return true;
      }

      final stage = knownStage?.campaignId == campaignId &&
              (knownStage?.id == stageId ||
                  knownStage?.id ==
                      stageId.replaceFirstMapped(
                          RegExp(r'^stage_(\d{2})$'), (m) => 'stage_0${m[1]}'))
          ? knownStage
          : _findStage(await campaignService.loadStages(campaignId: campaignId),
              stageId);
      if (!accountIsActive()) return false;
      if (stage == null) {
        if (context.mounted) {
          _showSnack(context, 'تعذر العثور على بيانات المرحلة.');
        }
        return true;
      }

      final user = appState.currentUser;
      final uid = user?.uid.trim() ?? '';
      if (user == null || uid.isEmpty) {
        if (!context.mounted) return true;
        _showSnack(context, _loggedOutSaveMessage);
        final preview = _buildLocalPreview(
          campaignService: campaignService,
          stage: stage,
          payload: payload,
        );
        unawaited(_recordCampaignAchievementProgress(
          nativeBridge: nativeBridge,
          result: preview,
          accountUid: activeUid,
        ));
        if (!context.mounted) return true;
        unawaited(Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => StageResultScreen(
              stage: stage,
              submissionResult: preview,
              rawNativeResult: payload,
            ),
          ),
        ));
        return true;
      }

      // The native attempt already contains everything needed for the result.
      // Render it immediately; cloud progress, wallet and achievements can finish
      // while the player reads the result and watches the star animation.
      final preview = _buildLocalPreview(
        campaignService: campaignService,
        stage: stage,
        payload: payload,
        saving: true,
      );
      unawaited(_recordCampaignAchievementProgress(
        nativeBridge: nativeBridge,
        result: preview,
        accountUid: activeUid,
      ));
      if (!context.mounted) return true;
      final pendingSubmission = campaignService.submitStageResult(
        uid: uid,
        stage: stage,
        nativeResult: payload,
        displayName:
            (user.displayName ?? user.email?.split('@').first ?? '').trim(),
        photoUrl: user.photoURL,
      );
      // Attach immediately in case saving fails before the new route is built.
      // The result screen still receives the same failure and offers a retry.
      unawaited(pendingSubmission.then<void>((_) {},
          onError: (Object error, StackTrace stack) {}));
      unawaited(Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StageResultScreen(
            stage: stage,
            submissionResult: preview,
            rawNativeResult: payload,
            pendingSubmission: pendingSubmission,
            submissionUid: uid,
            campaignService: campaignService,
          ),
        ),
      ));
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'CAMPAIGN_RESULT_HANDLER_FAILED type=${error.runtimeType} '
          'message=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (context.mounted) {
        _showSnack(
          context,
          'تعذر حفظ نتيجة المرحلة. تحقق من الاتصال وحاول مرة أخرى.',
        );
      }
      return true;
    } finally {
      _processing = false;
    }
  }

  static bool _isCurrentRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  static void _recoverRewardsInBackground(
      AppState appState, CampaignService campaignService) {
    final uid = appState.currentUser?.uid;
    if (uid == null || _rewardRecovery != null) return;
    final now = DateTime.now();
    if (_recoveryUid == uid &&
        _lastRecovery != null &&
        now.difference(_lastRecovery!) < const Duration(seconds: 30)) {
      return;
    }
    _recoveryUid = uid;
    _lastRecovery = now;
    _rewardRecovery = _retryPendingRewardClaims(
      appState: appState,
      campaignService: campaignService,
    ).catchError((Object error, StackTrace stack) {
      if (kDebugMode) debugPrint('CAMPAIGN_REWARD_RECOVERY_FAILED $error');
    }).whenComplete(() => _rewardRecovery = null);
  }

  static Future<bool> applySubmissionReward({
    required AppState appState,
    required CampaignService campaignService,
    required StageSubmissionResult result,
  }) async {
    final uid = result.attempt.uid.trim();
    final claimId = result.rewardClaimId;
    if (uid.isEmpty || appState.currentUser?.uid.trim() != uid) {
      return false;
    }
    // Progress has been saved before this call. Let the economy service award
    // milestones now, including replays with no new coin/gem reward claim.
    // A temporary wallet failure must never hide a successfully saved result.
    try {
      await appState.loadEconomy().timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (claimId == null || appState.currentUser?.uid.trim() != uid) {
      return false;
    }
    return _applyRewardClaim(
      appState: appState,
      campaignService: campaignService,
      uid: uid,
      claimId: claimId,
      fallbackCoins: result.rewardCoinsGranted,
      fallbackGems: result.rewardGemsGranted,
      fallbackXp: result.rewardXpGranted,
    );
  }

  static const String _loggedOutSaveMessage =
      'أداء بطولي! غنائمك ونجومك جاهزة للإيداع 🏆';

  static String saveFailureMessage(Object error) => _saveFailureMessage(error);

  static String _saveFailureMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'تعذر الحفظ بسبب صلاحيات قاعدة البيانات. تأكد من نشر قواعد Firestore.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'تعذر الاتصال. سيتم عرض نتيجتك الحالية فقط.';
      }
    }
    if (error is ArgumentError) {
      return 'بيانات نتيجة المرحلة غير صالحة للحفظ. أعد فتح المرحلة وحاول مجددًا.';
    }
    return 'تعذر حفظ النتيجة الآن. سيتم عرض نتيجتك الحالية فقط.';
  }

  static CampaignStage? _findStage(List<CampaignStage> stages, String stageId) {
    for (final stage in stages) {
      if (stage.id == stageId) return stage;
    }
    final legacyMatch = RegExp(r'^stage_(\d{2})$').firstMatch(stageId);
    if (legacyMatch != null) {
      final canonicalId = 'stage_0${legacyMatch.group(1)}';
      for (final stage in stages) {
        if (stage.id == canonicalId) return stage;
      }
    }
    return null;
  }

  static Future<void> _recordCampaignAchievementProgress({
    required NativeBridgeService nativeBridge,
    required StageSubmissionResult result,
    required String accountUid,
  }) async {
    try {
      final attempt = result.attempt;
      await CampaignEngagementService().recordAttempt(
        playerId: accountUid == 'guest_local' ? 'guest' : accountUid,
        campaignId: attempt.campaignId,
        attempt: attempt,
      );
    } catch (_) {
      // A local journal failure must not interrupt achievements or the result.
    }
    try {
      final attempt = result.attempt;
      await nativeBridge.recordCampaignAchievementProgress(
        accountUid: accountUid,
        campaignId: attempt.campaignId,
        stageId: attempt.stageId,
        campaignMode: attempt.campaignMode,
        completed: attempt.completed,
        stars: result.newStars,
        bossDefeated: attempt.bossDefeated,
        usedLifelines:
            attempt.used5050 + attempt.usedAudience + attempt.usedCall,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'CAMPAIGN_ACHIEVEMENT_RECORD_FAILED type=${error.runtimeType} '
          'message=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static bool _hasCompleteCampaignResult(Map<String, dynamic> payload) {
    final stageId = (payload['stageId'] ?? '').toString().trim();
    return stageId.isNotEmpty &&
        payload.containsKey('completed') &&
        payload.containsKey('correctAnswers') &&
        payload.containsKey('wrongAnswers') &&
        payload.containsKey('timeMs');
  }

  static Future<void> _retryPendingRewardClaims({
    required AppState appState,
    required CampaignService campaignService,
  }) async {
    final uid = appState.currentUser?.uid.trim();
    if (uid == null) return;
    final claims = await campaignService.loadPendingRewardClaims(uid: uid);
    for (final claim in claims) {
      await _applyRewardClaim(
        appState: appState,
        campaignService: campaignService,
        uid: uid,
        claimId: claim.claimId,
        claim: claim,
      );
    }
  }

  static Future<bool> _applyRewardClaim({
    required AppState appState,
    required CampaignService campaignService,
    required String uid,
    required String claimId,
    CampaignRewardClaim? claim,
    int fallbackCoins = 0,
    int fallbackGems = 0,
    int fallbackXp = 0,
  }) async {
    final loadedClaim = claim ??
        await campaignService.loadRewardClaim(uid: uid, claimId: claimId);
    final effectiveClaim = loadedClaim;
    if (appState.currentUser?.uid.trim() != uid ||
        (effectiveClaim != null && effectiveClaim.uid != uid)) {
      return false;
    }
    if (effectiveClaim == null || effectiveClaim.isClaimed) {
      return effectiveClaim?.isClaimed ?? false;
    }

    var currencyClaimed = effectiveClaim.currencyClaimed;
    var xpClaimed = effectiveClaim.xpClaimed;
    final coins =
        effectiveClaim.coins > 0 ? effectiveClaim.coins : fallbackCoins;
    final gems = effectiveClaim.gems > 0 ? effectiveClaim.gems : fallbackGems;
    final xp = effectiveClaim.xp > 0 ? effectiveClaim.xp : fallbackXp;

    try {
      if (currencyClaimed && xpClaimed) {
        await campaignService.markRewardXpClaimed(uid: uid, claimId: claimId);
        return true;
      }
      if (!currencyClaimed) {
        if (appState.currentUser?.uid.trim() != uid) return false;
        final granted = await appState.grantCampaignCurrency(
          coinsReward: coins,
          gemsReward: gems,
          claimId: claimId,
        );
        if (!granted) {
          await _markRewardFailedQuietly(
            campaignService: campaignService,
            uid: uid,
            claimId: claimId,
          );
          return false;
        }
        await campaignService.markRewardCurrencyClaimed(
          uid: uid,
          claimId: claimId,
        );
        currencyClaimed = true;
      }

      if (!xpClaimed) {
        if (appState.currentUser?.uid.trim() != uid) return false;
        final granted =
            await appState.grantCampaignXp(xpReward: xp, claimId: claimId);
        if (!granted) {
          await _markRewardFailedQuietly(
            campaignService: campaignService,
            uid: uid,
            claimId: claimId,
          );
          return false;
        }
        await campaignService.markRewardXpClaimed(
          uid: uid,
          claimId: claimId,
        );
        xpClaimed = true;
      }
      return currencyClaimed && xpClaimed;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'CAMPAIGN_REWARD_GRANT_FAILED type=${error.runtimeType} '
          'message=$error uid=$uid claimId=$claimId',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      await _markRewardFailedQuietly(
        campaignService: campaignService,
        uid: uid,
        claimId: claimId,
      );
      return false;
    }
  }

  static Future<void> _markRewardFailedQuietly({
    required CampaignService campaignService,
    required String uid,
    required String claimId,
  }) async {
    try {
      await campaignService.markRewardFailed(uid: uid, claimId: claimId);
    } catch (markError, markStackTrace) {
      if (kDebugMode) {
        debugPrint(
          'CAMPAIGN_REWARD_MARK_FAILED type=${markError.runtimeType} '
          'message=$markError uid=$uid claimId=$claimId',
        );
        debugPrintStack(stackTrace: markStackTrace);
      }
    }
  }

  static StageSubmissionResult _buildLocalPreview({
    required CampaignService campaignService,
    required CampaignStage stage,
    required Map<String, dynamic> payload,
    bool saving = false,
  }) {
    final campaignMode = campaignService.campaignModeForResult(
        stage: stage, nativeResult: payload);
    final isBossStage = campaignMode == CampaignMode.bossBattle ||
        stage.isBossStage ||
        stage.type == CampaignStageType.boss ||
        (payload['stageType']?.toString() == 'boss');
    final bossDefeated = _readBool(payload['bossDefeated']) ||
        _readBool(payload['bossBattleWon']);
    final completed = campaignService.normalizeStageCompleted(
      stage: stage,
      nativeResult: payload,
      correctAnswers: _readInt(payload['correctAnswers']),
      wrongAnswers: _readInt(payload['wrongAnswers']),
    );
    final money = _readInt(payload['money']);
    final correctAnswers = _readInt(payload['correctAnswers']);
    final wrongAnswers = _readInt(payload['wrongAnswers']);
    final timeMs = _readInt(payload['timeMs']);
    final used5050 = _readInt(payload['used5050']);
    final usedAudience = _readInt(payload['usedAudience']);
    final usedCall = _readInt(payload['usedCall']);
    final usedLifelines = used5050 + usedAudience + usedCall;
    final score = campaignService.scoreFromResult(payload);
    final lives = _readInt(payload['lives']);
    final livesRemaining = _readInt(payload['livesRemaining']);
    final maxWrongAnswers = _readInt(payload['maxWrongAnswers']);
    final targetScore = _readInt(payload['targetScore']);
    final opponentScore = _readInt(payload['opponentScore']);
    final bossScore = _readInt(payload['bossScore']);
    final playerSeriesWins = _readInt(payload['playerSeriesWins']);
    final opponentSeriesWins = _readInt(payload['opponentSeriesWins']);
    final seriesWinsRequired = _readInt(payload['seriesWinsRequired']);
    final teamScore = _readInt(payload['teamScore']);
    final enemyTeamScore = _readInt(payload['enemyTeamScore']);
    final stars = campaignService.calculateStars(
      stage: stage,
      campaignMode: campaignMode,
      completed: completed,
      score: score,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      timeMs: timeMs,
      usedLifelines: usedLifelines,
      failureReason: payload['failureReason']?.toString() ?? '',
      answeredQuestions: correctAnswers + wrongAnswers,
      lives: lives,
      livesRemaining: livesRemaining,
      maxWrongAnswers: maxWrongAnswers,
      targetScore: targetScore,
      playerScore: score,
      opponentScore: opponentScore,
      bossScore: bossScore,
      bossDefeated: bossDefeated,
      playerSeriesWins: playerSeriesWins,
      opponentSeriesWins: opponentSeriesWins,
      seriesWinsRequired: seriesWinsRequired,
      teamScore: teamScore,
      enemyTeamScore: enemyTeamScore,
    );
    final now = DateTime.now();
    final attempt = StageAttempt(
      attemptId: _cleanString(payload['attemptId']?.toString()) ??
          'local_preview_${now.microsecondsSinceEpoch}',
      uid: '',
      campaignId: stage.campaignId,
      stageId: stage.id,
      stageType: stage.type.value,
      campaignMode: campaignMode.value,
      winCondition:
          payload['winCondition']?.toString() ?? stage.winCondition.value,
      failureReason: payload['failureReason']?.toString() ?? '',
      score: score,
      money: money,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      timeMs: timeMs,
      used5050: used5050,
      usedAudience: usedAudience,
      usedCall: usedCall,
      completed: completed,
      stars: stars,
      lives: lives,
      livesRemaining: livesRemaining,
      maxWrongAnswers: maxWrongAnswers,
      targetScore: targetScore,
      opponentName: _cleanString(payload['opponentName']?.toString()),
      opponentScore: opponentScore,
      opponentCorrectAnswers: _readInt(payload['opponentCorrectAnswers']),
      opponentWrongAnswers: _readInt(payload['opponentWrongAnswers']),
      bossDefeated: isBossStage && bossDefeated,
      bossName: _cleanString(payload['bossName']?.toString()),
      bossCorrectAnswers: _readInt(payload['bossCorrectAnswers']),
      bossWrongAnswers: _readInt(payload['bossWrongAnswers']),
      bossScore: bossScore,
      playerScore: score,
      seriesRounds: _readInt(payload['seriesRounds']),
      seriesWinsRequired: seriesWinsRequired,
      playerSeriesWins: playerSeriesWins,
      opponentSeriesWins: opponentSeriesWins,
      teamAllyName: _cleanString(payload['teamAllyName']?.toString()),
      teamEnemyName: _cleanString(payload['teamEnemyName']?.toString()),
      allyScore: _readInt(payload['allyScore']),
      teamScore: teamScore,
      enemyTeamScore: enemyTeamScore,
      createdAt: campaignService.completionTimeFromResult(payload),
    );
    final progress = StageProgress(
      campaignId: stage.campaignId,
      stageId: stage.id,
      status: completed
          ? StageProgressStatus.completed
          : StageProgressStatus.unlocked,
      stars: stars,
      bestScore: score,
      bestMoney: money,
      bestCorrectAnswers: correctAnswers,
      bestTimeMs: timeMs,
      attempts: 1,
      firstCompletedAt: completed ? now : null,
      lastPlayedAt: now,
    );
    return StageSubmissionResult(
      attempt: attempt,
      updatedProgress: progress,
      previousStars: 0,
      newStars: stars,
      isFirstCompletion: completed,
      improvedBestScore: false,
      improvedStars: false,
      leaderboardUpdated: false,
      rewardGranted: false,
      rewardCoinsGranted: 0,
      rewardGemsGranted: 0,
      rewardXpGranted: 0,
      motivationalMessage: saving
          ? (completed
              ? 'أحسنت! اكتملت المرحلة.'
              : 'حاول مرة أخرى وحسّن نتيجتك.')
          : completed
              ? 'أحسنت! سجّل الدخول لحفظ هذا التقدم.'
              : 'كنت قريبًا جدًا، حاول مرة أخرى.',
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static String? _cleanString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }
}
