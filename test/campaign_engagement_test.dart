import 'dart:convert';

import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_engagement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late CampaignEngagementService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 3, 12);
    service = CampaignEngagementService(now: () => now);
  });

  Future<void> record(String id,
      {bool completed = true, int stars = 2, DateTime? createdAt}) async {
    await service.recordAttempt(
        playerId: 'player',
        campaignId: 'main',
        attempt: StageAttempt.fromMap({
          ...StageAttempt.empty().toMap(),
          'attemptId': id,
          'completed': completed,
          'stars': stars,
          'createdAt': createdAt
        }));
  }

  test('each attempt counts once, including simultaneous result consumers',
      () async {
    await Future.wait([record('one'), record('one'), record('two')]);
    final daily = await service.load(playerId: 'player', campaignId: 'main');
    expect(daily.attempts, 2);
    expect(daily.wins, 2);
    expect(daily.stars, 4);
    expect(daily.goalsCompleted, 3);
    expect(daily.activityDays, ['2026-10-03']);
    final restored = await CampaignEngagementService(now: () => now)
        .load(playerId: 'player', campaignId: 'main');
    expect(restored.toMap(), daily.toMap());
  });

  test('failed rounds count as play but earn no victory or stars', () async {
    await record('failed', completed: false, stars: 3);
    final daily = await service.load(playerId: 'player', campaignId: 'main');
    expect(daily.attempts, 1);
    expect(daily.wins, 0);
    expect(daily.stars, 0);
  });

  test(
      'midnight resets goals while retaining activity and duplicate protection',
      () async {
    await record('yesterday');
    now = DateTime(2026, 10, 4, 0, 1);
    await record('yesterday');
    final reset = await service.load(playerId: 'player', campaignId: 'main');
    expect(reset.attempts, 0);
    expect(reset.stars, 0);
    expect(reset.activityDays, ['2026-10-03']);
    await record('today', stars: 3);
    final next = await service.load(playerId: 'player', campaignId: 'main');
    expect(next.attempts, 1);
    expect(next.activityDays, ['2026-10-03', '2026-10-04']);
  });

  test('delayed historical result does not fulfil current daily goals',
      () async {
    await record('delayed', createdAt: DateTime(2026, 10, 2, 22));
    final daily = await service.load(playerId: 'player', campaignId: 'main');
    expect(daily.attempts, 0);
    expect(daily.activityDays, ['2026-10-02']);
  });

  test('goals remain isolated between players and campaigns', () async {
    await record('a');
    expect((await service.load(playerId: 'guest', campaignId: 'main')).attempts,
        0);
    expect(
        (await service.load(playerId: 'player', campaignId: 'other')).attempts,
        0);
  });

  test('malformed local storage recovers without blocking the map', () async {
    SharedPreferences.setMockInitialValues(
        {'campaign_journey_v1:player:main': '{'});
    expect(
        (await service.load(playerId: 'player', campaignId: 'main')).attempts,
        0);
    SharedPreferences.setMockInitialValues({
      'campaign_journey_v1:player:main': jsonEncode({
        'dayKey': '2026-10-03',
        'attempts': -9,
        'stars': 'wrong',
        'activityDays': [12]
      })
    });
    final daily = await service.load(playerId: 'player', campaignId: 'main');
    expect(daily.attempts, 0);
    expect(daily.stars, 0);
    expect(daily.activityDays, isEmpty);
  });

  test('daily recommendation excludes locks and favours unfinished mastery',
      () {
    final stages = CampaignDefaults.stages();
    final progress = [
      StageProgress.empty().copyWith(
          stageId: stages[0].id,
          status: StageProgressStatus.completed,
          stars: 3),
      StageProgress.empty().copyWith(
          stageId: stages[1].id,
          status: StageProgressStatus.completed,
          stars: 1),
      StageProgress.empty().copyWith(
          stageId: stages[2].id, status: StageProgressStatus.unlocked),
      StageProgress.empty().copyWith(stageId: stages[3].id),
    ];
    expect(service.recommendedStage(stages: stages, progress: progress)?.id,
        stages[1].id);
    expect(
        service
            .recommendedStage(
                stages: stages.reversed.toList(), progress: progress)
            ?.id,
        stages[1].id);
    expect(service.recommendedStage(stages: stages, progress: []), isNull);
  });
}
