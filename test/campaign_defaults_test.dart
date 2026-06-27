import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';

/// رحلة المليون now plays the التحدي board for every stage: normal stages are a
/// solo board with a rising target score, and every 10th stage is a boss board
/// against bots. These tests pin that board design + the shared progression rules.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // worldLevels mirror (campaign_defaults.dart). Kept here so the test fails loudly
  // if the per-world difficulty bands drift.
  const worldLevels = <List<String>>[
    <String>['0', '1'],
    <String>['0', '1', '2'],
    <String>['1', '2'],
    <String>['2', '4'],
    <String>['2', '5'],
    <String>['4', '5'],
    <String>['5', '6'],
    <String>['6', '7'],
    <String>['7', '8'],
    <String>['3', '8'],
  ];

  group('CampaignDefaults (التحدي board)', () {
    test('built-in stages cover stable stage_001 through stage_100', () {
      final stages = CampaignDefaults.stages();
      final ids = stages.map((stage) => stage.id).toList(growable: false);
      final orders = stages.map((stage) => stage.order).toList(growable: false);

      expect(stages, hasLength(100));
      expect(ids.toSet(), hasLength(100));
      expect(orders.toSet(), hasLength(100));

      for (var order = 1; order <= 100; order += 1) {
        expect(ids, contains('stage_${order.toString().padLeft(3, '0')}'));
        expect(orders, contains(order));
      }
      expect(orders, List<int>.generate(100, (index) => index + 1));
    });

    test('every stage is a board stage with valid required data', () {
      for (final stage in CampaignDefaults.stages()) {
        expect(stage.questionCount, 6, reason: stage.id);
        expect(stage.type, CampaignStageType.classic, reason: stage.id);
        expect(stage.campaignMode, CampaignMode.classic, reason: stage.id);
        expect(stage.allowedLevels, isNotEmpty, reason: stage.id);
        expect(stage.categories, isNotEmpty, reason: stage.id);
        expect(stage.boardSoloPicks, 6, reason: stage.id);
        expect(stage.boardSoloCols, 4, reason: stage.id);
        expect(stage.boardTargetScore, greaterThan(0), reason: stage.id);
        expect(stage.rewardCoins, greaterThan(0), reason: stage.id);
        expect(stage.rewardGems, greaterThanOrEqualTo(0), reason: stage.id);
        expect(stage.rewardXp, greaterThan(0), reason: stage.id);
        // Guard against mojibake leaking into stage titles.
        expect(stage.title, isNot(contains('Ã˜')), reason: stage.id);
        expect(stage.title, isNot(contains('Ã™')), reason: stage.id);
      }
    });

    test('every 10th stage is a boss board against bots', () {
      final byOrder = {
        for (final stage in CampaignDefaults.stages()) stage.order: stage,
      };
      for (var order = 1; order <= 100; order += 1) {
        final stage = byOrder[order]!;
        final isBoss = order % 10 == 0;
        expect(stage.isBossStage, isBoss, reason: '$order');
        expect(stage.boardKind, isBoss ? 'boss' : 'solo', reason: '$order');
        expect(
          stage.winCondition,
          isBoss
              ? CampaignWinCondition.beatOpponent
              : CampaignWinCondition.beatTargetScore,
          reason: '$order',
        );
        if (isBoss) {
          expect(stage.botCount, greaterThanOrEqualTo(1), reason: '$order');
          expect(stage.botCount, lessThanOrEqualTo(7), reason: '$order');
          expect(stage.botIntelligence, greaterThan(0), reason: '$order');
          expect(stage.categoryPolicy, 'worldThemed', reason: '$order');
        } else {
          expect(stage.botCount, 0, reason: '$order');
          expect(stage.botIntelligence, 0, reason: '$order');
        }
      }
    });

    test('solo category policy follows the world tier', () {
      final byOrder = {
        for (final stage in CampaignDefaults.stages()) stage.order: stage,
      };
      // Worlds 1-2 let the player pick, 3-6 are curated, 7-10 are random.
      expect(byOrder[1]!.categoryPolicy, 'playerPick');
      expect(byOrder[15]!.categoryPolicy, 'playerPick');
      expect(byOrder[21]!.categoryPolicy, 'curated');
      expect(byOrder[55]!.categoryPolicy, 'curated');
      expect(byOrder[61]!.categoryPolicy, 'random');
      expect(byOrder[91]!.categoryPolicy, 'random');
    });

    test('board target score rises across the journey', () {
      final stages = CampaignDefaults.stages();
      expect(
        stages.first.boardTargetScore,
        lessThan(stages.last.boardTargetScore),
      );
    });

    test('stage levels match the per-world distribution', () {
      final byOrder = {
        for (final stage in CampaignDefaults.stages()) stage.order: stage,
      };
      for (var order = 1; order <= 100; order += 1) {
        final world = (order - 1) ~/ 10;
        expect(byOrder[order]!.allowedLevels, worldLevels[world],
            reason: '$order');
      }
    });
  });

  group('CampaignService stage loading', () {
    test('remote stages override defaults without hiding missing defaults',
        () async {
      final firestore = FakeFirebaseFirestore();
      const campaignId = CampaignDefaults.mainCampaignId;
      final defaultStages = CampaignDefaults.stages(campaignId: campaignId);

      for (final stage in defaultStages.take(50)) {
        await firestore
            .collection('campaigns')
            .doc(campaignId)
            .collection('stages')
            .doc(stage.id)
            .set(stage.toMap());
      }
      await firestore
          .collection('campaigns')
          .doc(campaignId)
          .collection('stages')
          .doc('stage_040')
          .set(<String, dynamic>{
        ...defaultStages.firstWhere((stage) => stage.id == 'stage_040').toMap(),
        'title': 'حارس مخصص',
      });
      await firestore
          .collection('campaigns')
          .doc(campaignId)
          .collection('stages')
          .doc('stage_001')
          .set(<String, dynamic>{
        ...defaultStages.first.toMap(),
        'title': 'عنوان مخصص',
      });

      final stages = await CampaignService(firestore: firestore).loadStages();
      final byId = {for (final stage in stages) stage.id: stage};

      expect(stages, hasLength(100));
      expect(byId['stage_001']!.title, 'عنوان مخصص');
      expect(byId['stage_040']!.title, 'حارس مخصص');
      expect(byId['stage_041']!.title, 'المرحلة 41');
      expect(byId, contains('stage_031'));
      expect(byId, contains('stage_050'));
      expect(byId, contains('stage_051'));
      expect(byId, contains('stage_100'));
      expect(
        stages.map((stage) => stage.order).toList(growable: false),
        List<int>.generate(100, (index) => index + 1),
      );
    });
  });

  group('Campaign progression and board QA', () {
    late List<CampaignStage> stages;
    late Map<int, CampaignStage> byOrder;
    late CampaignService service;

    setUp(() {
      stages = CampaignDefaults.stages();
      byOrder = {for (final stage in stages) stage.order: stage};
      service = CampaignService(firestore: FakeFirebaseFirestore());
    });

    test('debug unlock exposes stages without granting progress', () {
      final saved = <String, StageProgress>{
        byOrder[10]!.id: _completedProgress(byOrder[10]!, stars: 2),
      };
      final progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: saved,
        debugUnlockAllCampaignStagesOverride: true,
      );

      expect(progress, hasLength(100));
      expect(
        progress.every((item) => item.status != StageProgressStatus.locked),
        isTrue,
      );
      expect(progress[9].stageId, 'stage_010');
      expect(progress[9].status, StageProgressStatus.completed);
      expect(progress[9].stars, 2);
      expect(progress[99].stageId, 'stage_100');
      expect(progress[99].status, StageProgressStatus.unlocked);
      expect(progress[99].stars, 0);
      expect(progress[99].firstCompletedAt, isNull);
    });

    test('normal locking is restored when debug unlock is off', () {
      final progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: const <String, StageProgress>{},
        debugUnlockAllCampaignStagesOverride: false,
      );

      expect(progress.first.stageId, 'stage_001');
      expect(progress.first.status, StageProgressStatus.unlocked);
      expect(progress[1].stageId, 'stage_002');
      expect(progress[1].status, StageProgressStatus.locked);
      expect(progress[49].stageId, 'stage_050');
      expect(progress[49].status, StageProgressStatus.locked);
      expect(progress[99].stageId, 'stage_100');
      expect(progress[99].status, StageProgressStatus.locked);
    });

    test('next stage requires at least one star on the previous stage', () {
      final saved = <String, StageProgress>{
        byOrder[1]!.id: _completedProgress(byOrder[1]!, stars: 0),
      };
      final progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: saved,
        debugUnlockAllCampaignStagesOverride: false,
      );

      expect(progress[0].stageId, 'stage_001');
      expect(progress[0].status, StageProgressStatus.unlocked);
      expect(progress[0].stars, 0);
      expect(progress[1].stageId, 'stage_002');
      expect(progress[1].status, StageProgressStatus.locked);
    });

    test('unlock chain stays reachable by previous completion', () {
      final saved = <String, StageProgress>{
        for (final stage in stages.take(30))
          stage.id: _completedProgress(stage, stars: 1),
      };
      var progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: saved,
        debugUnlockAllCampaignStagesOverride: false,
      );
      expect(progress[30].stageId, 'stage_031');
      expect(progress[30].status, StageProgressStatus.unlocked);

      // Boss stage 40 must be completed before world 5 (stage 41) unlocks.
      for (final stage in stages.take(39)) {
        saved[stage.id] = _completedProgress(stage, stars: 1);
      }
      progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: saved,
        debugUnlockAllCampaignStagesOverride: false,
      );
      expect(progress[39].stageId, 'stage_040');
      expect(progress[39].status, StageProgressStatus.unlocked);
      expect(progress[40].stageId, 'stage_041');
      expect(progress[40].status, StageProgressStatus.locked);

      saved[byOrder[40]!.id] = _completedProgress(byOrder[40]!, stars: 1);
      progress = service.resolveProgressForStages(
        stages: stages,
        savedProgress: saved,
        debugUnlockAllCampaignStagesOverride: false,
      );
      expect(progress[40].stageId, 'stage_041');
      expect(progress[40].status, StageProgressStatus.unlocked);
    });

    test('board stages complete strictly on the native completed flag', () {
      for (final order in <int>[1, 31, 40, 100]) {
        final stage = byOrder[order]!;
        expect(_completed(service, stage, completed: true), isTrue,
            reason: '$order');
        expect(_completed(service, stage, completed: false), isFalse,
            reason: '$order');
      }
    });

    test('board stars are score driven, gated by completion', () {
      final stage = byOrder[31]!; // solo board, target 860
      expect(_stars(service, stage, completed: false, score: 5000), 0);
      expect(_stars(service, stage, completed: true, score: 1), 1);
      expect(
        _stars(service, stage, completed: true, score: stage.boardTargetScore),
        1,
      );
      expect(
        _stars(service, stage,
            completed: true, score: (stage.boardTargetScore * 1.7).round()),
        3,
      );
    });

    test('failed and repeated attempts do not duplicate rewards', () async {
      final firestore = FakeFirebaseFirestore();
      final campaignService = CampaignService(firestore: firestore);
      final stage = byOrder[31]!;
      final oneStarScore = stage.boardTargetScore; // exactly the target -> 1 star
      final threeStarScore = (stage.boardTargetScore * 1.7).round();

      final failed = await campaignService.submitStageResult(
        uid: 'qa_user',
        stage: stage,
        nativeResult: _boardResult(stage, completed: false, playerScore: 200),
      );
      expect(failed.rewardGranted, isFalse);
      expect(failed.attempt.stars, 0);
      expect(failed.updatedProgress.status, StageProgressStatus.unlocked);

      final oneStar = await campaignService.submitStageResult(
        uid: 'qa_user',
        stage: stage,
        nativeResult:
            _boardResult(stage, completed: true, playerScore: oneStarScore),
      );
      expect(oneStar.rewardGranted, isTrue);
      expect(oneStar.newStars, 1);
      expect(oneStar.rewardCoinsGranted, stage.rewardCoins ~/ 3);

      final repeatedOneStar = await campaignService.submitStageResult(
        uid: 'qa_user',
        stage: stage,
        nativeResult:
            _boardResult(stage, completed: true, playerScore: oneStarScore),
      );
      expect(repeatedOneStar.rewardGranted, isFalse);
      expect(repeatedOneStar.newStars, 1);

      final improved = await campaignService.submitStageResult(
        uid: 'qa_user',
        stage: stage,
        nativeResult:
            _boardResult(stage, completed: true, playerScore: threeStarScore),
      );
      expect(improved.rewardGranted, isTrue);
      expect(improved.previousStars, 1);
      expect(improved.newStars, 3);
      expect(
        improved.rewardCoinsGranted,
        stage.rewardCoins - oneStar.rewardCoinsGranted,
      );
    });
  });
}

StageProgress _completedProgress(CampaignStage stage, {required int stars}) {
  return StageProgress(
    campaignId: stage.campaignId,
    stageId: stage.id,
    status: StageProgressStatus.completed,
    stars: stars,
    bestScore: 1000,
    bestMoney: 0,
    bestCorrectAnswers: 6,
    bestTimeMs: 60000,
    attempts: 1,
    firstCompletedAt: DateTime(2026),
    lastPlayedAt: DateTime(2026),
  );
}

bool _completed(
  CampaignService service,
  CampaignStage stage, {
  required bool completed,
  int score = 0,
}) {
  return service.normalizeStageCompleted(
    stage: stage,
    nativeResult: _boardResult(stage, completed: completed, playerScore: score),
    correctAnswers: 0,
    wrongAnswers: 0,
  );
}

int _stars(
  CampaignService service,
  CampaignStage stage, {
  required bool completed,
  required int score,
}) {
  return service.calculateStars(
    stage: stage,
    completed: completed,
    score: score,
    correctAnswers: 0,
    wrongAnswers: 0,
    timeMs: 60000,
    usedLifelines: 0,
    playerScore: score,
  );
}

/// A native result payload shaped like the التحدي board emits (campaignMode
/// 'board' normalizes to classic on the Flutter side, so completion follows the
/// native `completed` flag and stars follow the board score).
Map<String, dynamic> _boardResult(
  CampaignStage stage, {
  required bool completed,
  int playerScore = 0,
}) {
  return <String, dynamic>{
    'campaignId': stage.campaignId,
    'stageId': stage.id,
    'stageType': 'board',
    'campaignMode': 'board',
    'winCondition': stage.winCondition.value,
    'campaignBoard': true,
    'boardKind': stage.boardKind,
    'completed': completed,
    'money': playerScore,
    'correctAnswers': 0,
    'wrongAnswers': 0,
    'timeMs': 60000,
    'used5050': 0,
    'usedAudience': 0,
    'usedCall': 0,
    'playerScore': playerScore,
    'boardTargetScore': stage.boardTargetScore,
  };
}
