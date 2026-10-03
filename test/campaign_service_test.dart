import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingFirestore firestore;
  late CampaignService service;
  late CampaignStage stage;

  setUp(() {
    firestore = _RecordingFirestore();
    service = CampaignService(firestore: firestore);
    stage = CampaignDefaults.stages().first;
  });

  group('Campaign result compatibility', () {
    test('native completion time survives a delayed save and replay', () async {
      final completedAt = DateTime(2026, 10, 2, 23, 59);
      final payload = <String, dynamic>{
        ..._boardResult(stage, completed: true, score: 1200),
        'attemptId': 'historical_attempt',
        'completedAtMs': completedAt.millisecondsSinceEpoch,
      };
      final first = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: payload,
      );
      final replay = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: payload,
      );
      expect(first.attempt.createdAt!.isAtSameMomentAs(completedAt), isTrue);
      expect(replay.attempt.createdAt!.isAtSameMomentAs(completedAt), isTrue);
      final stored = await firestore
          .doc('users/player/campaignAttempts/historical_attempt')
          .get();
      expect(stored.data()!['createdAt'], isA<Timestamp>());
      expect(
          (stored.data()!['completedAt'] as Timestamp)
              .toDate()
              .isAtSameMomentAs(completedAt),
          isTrue);
    });

    test('leaderboard failures can propagate instead of becoming empty data',
        () async {
      final failing = CampaignService(firestore: _UnavailableFirestore());
      expect(
          await failing.loadStageLeaderboard(
            campaignId: stage.campaignId,
            stageId: stage.id,
          ),
          isEmpty);
      await expectLater(
          failing.loadStageLeaderboard(
            campaignId: stage.campaignId,
            stageId: stage.id,
            propagateErrors: true,
          ),
          throwsA(isA<FirebaseException>()
              .having((error) => error.code, 'code', 'unavailable')));
    });
    test('a native zero score stays zero without a fabricated time bonus',
        () async {
      final result = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(stage, completed: false, score: 0),
      );

      expect(result.attempt.score, 0);
      expect(result.newStars, 0);
      expect(result.rewardGranted, isFalse);
      expect(result.updatedProgress.bestTimeMs, 0);
      expect(
          await service.loadStageLeaderboard(
            campaignId: stage.campaignId,
            stageId: stage.id,
          ),
          isEmpty);
    });

    test('board completion works with a remote legacy boss stage type',
        () async {
      final boss = stage.copyWith(
        type: CampaignStageType.boss,
        campaignMode: CampaignMode.bossBattle,
        boardKind: 'boss',
      );
      final payload = _boardResult(boss, completed: true, score: 1200);
      expect(service.campaignModeForResult(stage: boss, nativeResult: payload),
          CampaignMode.classic);
      expect(
          service.normalizeStageCompleted(
            stage: boss,
            nativeResult: payload,
            correctAnswers: 3,
            wrongAnswers: 0,
          ),
          isTrue);
      final result = await service.submitStageResult(
        uid: 'player',
        stage: boss,
        nativeResult: <String, dynamic>{...payload, 'bossDefeated': true},
      );
      expect(result.newStars, 3);
      expect(result.attempt.bossDefeated, isTrue);
      expect(result.rewardGranted, isTrue);
    });

    test('a missing result mode uses the configured remote stage mode', () {
      final survival = stage.copyWith(
        campaignMode: CampaignMode.survival,
        lives: 3,
      );
      expect(
          service.normalizeStageCompleted(
            stage: survival,
            nativeResult: <String, dynamic>{
              'completed': true,
              'livesRemaining': 0,
            },
            correctAnswers: 6,
            wrongAnswers: 3,
          ),
          isFalse);
    });

    test('rejects a result belonging to another stage before writing',
        () async {
      await expectLater(
        service.submitStageResult(
          uid: 'player',
          stage: stage,
          nativeResult: <String, dynamic>{
            ..._boardResult(stage, completed: true, score: 1200),
            'stageId': 'stage_002',
          },
        ),
        throwsArgumentError,
      );
      expect(
          (await firestore.collection('users/player/campaignAttempts').get())
              .docs,
          isEmpty);
      expect(
          (await firestore.collection('users/player/campaignProgress').get())
              .docs,
          isEmpty);
    });
  });

  group('Campaign rewards and persistence', () {
    test('a late failure closes a fully granted claim without another retry',
        () async {
      final result = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(stage, completed: true, score: 1200),
      );
      final claimId = result.rewardClaimId!;
      await firestore
          .doc('users/player/campaignRewardClaims/$claimId')
          .update({'currencyClaimed': true, 'xpClaimed': true});
      await service.markRewardFailed(uid: 'player', claimId: claimId);
      final claim =
          await service.loadRewardClaim(uid: 'player', claimId: claimId);
      expect(claim!.isClaimed, isTrue);
      expect(claim.retryCount, 0);
      expect(await service.loadPendingRewardClaims(uid: 'player'), isEmpty);
    });
    test('progress, attempt and reward entitlement share one transaction',
        () async {
      final result = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(
          stage,
          completed: true,
          score: stage.starRules.threeStarsMinScore,
        ),
      );

      expect(result.rewardGranted, isTrue);
      expect(
          firestore.transactionWrites.first,
          unorderedEquals(<String>[
            'users/player/campaignAttempts/${result.attempt.attemptId}',
            'users/player/campaignProgress/${stage.id}',
            'users/player/campaignRewardClaims/${result.rewardClaimId}',
          ]));
      final claim = await service.loadRewardClaim(
        uid: 'player',
        claimId: result.rewardClaimId!,
      );
      expect(claim, isNotNull);
      expect(claim!.attemptId, result.attempt.attemptId);
      expect(claim.coins, stage.rewardCoins);
      expect(claim.xp, stage.rewardXp);
      expect(claim.isClaimed, isFalse);
    });

    test(
        'star upgrades pay only the remaining reward and failed replays pay none',
        () async {
      stage = stage.copyWith(rewardCoins: 101, rewardGems: 5, rewardXp: 103);
      final first = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(
          stage,
          completed: true,
          score: stage.boardTargetScore,
        ),
      );
      final upgrade = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(
          stage,
          completed: true,
          score: stage.starRules.threeStarsMinScore,
        ),
      );
      final failure = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(stage, completed: false, score: 3000),
      );

      expect(first.newStars, 1);
      expect(upgrade.previousStars, 1);
      expect(upgrade.newStars, 3);
      expect(first.rewardCoinsGranted + upgrade.rewardCoinsGranted, 101);
      expect(first.rewardGemsGranted + upgrade.rewardGemsGranted, 5);
      expect(first.rewardXpGranted + upgrade.rewardXpGranted, 103);
      expect(failure.rewardGranted, isFalse);
      expect(failure.newStars, 3);
      expect(failure.attempt.stars, 0);
      expect(failure.updatedProgress.status, StageProgressStatus.completed);
      expect(
          (await service.loadPendingRewardClaims(uid: 'player')), hasLength(2));
    });

    test('legacy progress migrates without paying first completion again',
        () async {
      final firstCompleted = DateTime.utc(2025, 4, 2);
      await firestore.doc('users/player/campaignProgress/stage_01').set(
            _progress(stage, stars: 3, attempts: 7)
                .copyWith(stageId: 'stage_01', firstCompletedAt: firstCompleted)
                .toMap(),
          );

      final result = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: <String, dynamic>{
          ..._boardResult(stage, completed: true, score: 1200),
          'stageId': 'stage_01',
        },
      );

      expect(result.isFirstCompletion, isFalse);
      expect(result.rewardGranted, isFalse);
      expect(result.previousStars, 3);
      expect(result.updatedProgress.stageId, stage.id);
      expect(result.updatedProgress.attempts, 8);
      expect(result.updatedProgress.firstCompletedAt!.toUtc(), firstCompleted);
      expect(
          (await firestore
                  .doc('users/player/campaignProgress/${stage.id}')
                  .get())
              .exists,
          isTrue);
    });

    test('resubmitting the same native attempt preserves its pending claim',
        () async {
      final payload = <String, dynamic>{
        ..._boardResult(stage, completed: true, score: stage.boardTargetScore),
        'attemptId': 'fixed_attempt_id',
      };
      final first = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: payload,
      );
      // Model an interruption after progress committed but before the optional
      // leaderboard write reached the server.
      await firestore
          .doc(
              'stageLeaderboards/${service.leaderboardId(stage.campaignId, stage.id)}/scores/player')
          .delete();
      final replay = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: <String, dynamic>{...payload, 'playerScore': 3000},
      );

      expect(replay.attempt.attemptId, 'fixed_attempt_id');
      expect(replay.attempt.score, first.attempt.score);
      expect(replay.newStars, first.newStars);
      expect(replay.updatedProgress.attempts, 1);
      expect(replay.isFirstCompletion, isFalse);
      expect(replay.rewardClaimId, first.rewardClaimId);
      expect(replay.rewardCoinsGranted, first.rewardCoinsGranted);
      expect(replay.rewardGranted, isTrue);
      expect(replay.leaderboardUpdated, isTrue);
      final leaderboard = await service.loadStageLeaderboard(
        campaignId: stage.campaignId,
        stageId: stage.id,
      );
      expect(leaderboard.single.score, first.attempt.score);
      expect(
          (await firestore.collection('users/player/campaignAttempts').get())
              .docs,
          hasLength(1));
      expect(
          await service.loadPendingRewardClaims(uid: 'player'), hasLength(1));
    });

    test('a paid native attempt cannot reserve a second reward', () async {
      final payload = <String, dynamic>{
        ..._boardResult(stage, completed: true, score: 1200),
        'attemptId': 'paid_attempt_id',
      };
      final first = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: payload,
      );
      await service.markRewardCurrencyClaimed(
        uid: 'player',
        claimId: first.rewardClaimId!,
      );
      await service.markRewardXpClaimed(
        uid: 'player',
        claimId: first.rewardClaimId!,
      );
      final replay = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: payload,
      );
      expect(replay.rewardGranted, isFalse);
      expect(replay.rewardCoinsGranted, 0);
      expect(replay.rewardClaimStatus, 'claimed');
      expect(replay.updatedProgress.attempts, 1);
      expect(await service.loadPendingRewardClaims(uid: 'player'), isEmpty);
    });

    test(
        'failed partial claims keep their granted parts and paid claims stay paid',
        () async {
      final result = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(stage, completed: true, score: 1200),
      );
      final claimId = result.rewardClaimId!;
      await service.markRewardCurrencyClaimed(uid: 'player', claimId: claimId);
      await service.markRewardFailed(uid: 'player', claimId: claimId);
      final pending = await service.loadPendingRewardClaims(uid: 'player');
      expect(pending, hasLength(1));
      expect(pending.single.currencyClaimed, isTrue);
      expect(pending.single.xpClaimed, isFalse);
      expect(pending.single.retryCount, 1);

      await service.markRewardXpClaimed(uid: 'player', claimId: claimId);
      await service.markRewardFailed(uid: 'player', claimId: claimId);
      final paid =
          await service.loadRewardClaim(uid: 'player', claimId: claimId);
      expect(paid!.isClaimed, isTrue);
      expect(paid.retryCount, 1);
      expect(await service.loadPendingRewardClaims(uid: 'player'), isEmpty);
      await service.markRewardFailed(uid: 'player', claimId: 'missing');
      expect(await service.loadRewardClaim(uid: 'player', claimId: 'missing'),
          isNull);
    });

    test('a fast failed attempt does not become the best completion time',
        () async {
      final first = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: _boardResult(stage, completed: true, score: 1200),
      );
      final failed = await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult: <String, dynamic>{
          ..._boardResult(stage, completed: false, score: 100),
          'timeMs': 200,
        },
      );
      expect(first.updatedProgress.bestTimeMs, 60000);
      expect(failed.updatedProgress.bestTimeMs, 60000);
      expect(failed.updatedProgress.firstCompletedAt,
          first.updatedProgress.firstCompletedAt);
    });
  });

  group('Campaign progress isolation', () {
    test('legacy stage aliases resolve to canonical identities on the map', () {
      final resolved = service.resolveProgressForStages(
        stages: CampaignDefaults.stages().take(2).toList(),
        savedProgress: <String, StageProgress>{
          'stage_01': _progress(stage, stars: 2).copyWith(stageId: 'stage_01'),
        },
      );
      expect(resolved.first.stageId, 'stage_001');
      expect(resolved.first.stars, 2);
      expect(resolved[1].status, StageProgressStatus.unlocked);
    });

    test('progress from another campaign does not unlock this campaign',
        () async {
      final foreign =
          _progress(stage, stars: 3).copyWith(campaignId: 'other_campaign');
      await firestore
          .doc('users/player/campaignProgress/${stage.id}')
          .set(foreign.toMap());
      expect(await service.loadUserProgress(uid: ' player '), isEmpty);
      final resolved = service.resolveProgressForStages(
        stages: CampaignDefaults.stages().take(2).toList(),
        savedProgress: <String, StageProgress>{stage.id: foreign},
      );
      expect(resolved.first.stars, 0);
      expect(resolved[1].status, StageProgressStatus.locked);
    });

    test('campaigns can save the same stage ID without overwriting each other',
        () async {
      final custom = stage.copyWith(campaignId: 'season_two');
      await service.submitStageResult(
        uid: 'player',
        stage: stage,
        nativeResult:
            _boardResult(stage, completed: true, score: stage.boardTargetScore),
      );
      await service.submitStageResult(
        uid: 'player',
        stage: custom,
        nativeResult: _boardResult(custom,
            completed: true, score: custom.starRules.threeStarsMinScore),
      );
      final mainProgress = await service.loadUserProgress(uid: 'player');
      final customProgress = await service.loadUserProgress(
        uid: 'player',
        campaignId: custom.campaignId,
      );
      expect(mainProgress[stage.id]!.stars, 1);
      expect(customProgress[custom.id]!.stars, 3);
      expect(
          (await firestore.collection('users/player/campaignProgress').get())
              .docs,
          hasLength(2));
    });

    test(
        'old custom campaign documents migrate and newer progress wins on load',
        () async {
      final custom = stage.copyWith(campaignId: 'season_two');
      await firestore
          .doc('users/player/campaignProgress/${custom.id}')
          .set(_progress(custom, stars: 1, attempts: 4).toMap());
      final upgraded = await service.submitStageResult(
        uid: 'player',
        stage: custom,
        nativeResult: _boardResult(custom,
            completed: true, score: custom.starRules.threeStarsMinScore),
      );
      final loaded = await service.loadUserProgress(
        uid: ' player ',
        campaignId: custom.campaignId,
      );
      expect(upgraded.isFirstCompletion, isFalse);
      expect(upgraded.previousStars, 1);
      expect(upgraded.updatedProgress.attempts, 5);
      expect(loaded[custom.id]!.stars, 3);
      expect(loaded[custom.id]!.attempts, 5);
    });
  });
}

Map<String, dynamic> _boardResult(
  CampaignStage stage, {
  required bool completed,
  required int score,
}) =>
    <String, dynamic>{
      'campaignId': stage.campaignId,
      'stageId': stage.id,
      'stageType': 'board',
      'campaignMode': 'board',
      'campaignBoard': true,
      'boardKind': stage.boardKind,
      'boardTargetScore': stage.boardTargetScore,
      'completed': completed,
      'correctAnswers': 3,
      'wrongAnswers': 0,
      'money': score,
      'playerScore': score,
      'timeMs': 60000,
      'used5050': 0,
      'usedAudience': 0,
      'usedCall': 0,
    };

StageProgress _progress(CampaignStage stage,
        {required int stars, int attempts = 1}) =>
    StageProgress(
      campaignId: stage.campaignId,
      stageId: stage.id,
      status: StageProgressStatus.completed,
      stars: stars,
      bestScore: 800,
      bestMoney: 800,
      bestCorrectAnswers: 3,
      bestTimeMs: 60000,
      attempts: attempts,
      firstCompletedAt: DateTime.utc(2025, 1, 1),
    );

// Fake Firestore does not emulate atomic commits or transaction conflicts.
// Recording the writes verifies that the service places all three records in
// the same transaction; the fake still exercises their stored data and replays.
class _RecordingFirestore extends FakeFirebaseFirestore {
  final transactionWrites = <List<String>>[];

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    final writes = <String>[];
    transactionWrites.add(writes);
    return super.runTransaction<T>(
      (transaction) =>
          transactionHandler(_RecordingTransaction(transaction, writes)),
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

class _UnavailableFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this.delegate, this.writes);

  final Transaction delegate;
  final List<String> writes;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) =>
      delegate.get(ref);

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes.add(ref.path);
    delegate.set(ref, data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes.add(ref.path);
    delegate.update(ref, data);
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    writes.add(ref.path);
    delegate.delete(ref);
    return this;
  }
}
