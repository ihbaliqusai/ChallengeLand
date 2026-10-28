import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomStagesService extends CampaignService {
  _CustomStagesService(FakeFirebaseFirestore firestore, this.stages)
      : super(firestore: firestore);

  final List<CampaignStage> stages;

  @override
  Future<List<CampaignStage>> loadStages({
    String campaignId = CampaignDefaults.mainCampaignId,
  }) async =>
      stages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late CampaignService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = CampaignService(firestore: firestore);
  });

  Future<void> complete(int count, {bool legacyIds = false}) async {
    for (final stage in CampaignDefaults.stages().take(count)) {
      final id = legacyIds
          ? 'stage_${stage.order.toString().padLeft(2, '0')}'
          : stage.id;
      await firestore.doc('users/player/campaignProgress/$id').set({
        'campaignId': stage.campaignId,
        'stageId': id,
        'status': 'completed',
        'stars': 1,
      });
    }
  }

  test('a new player has reached the first real campaign stage', () async {
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.reachedStage, 1);
    expect(progress.totalStages, CampaignDefaults.stages().length);
    expect(progress.label, '1/100');
  });

  test('four completed stages display the unlocked fifth stage', () async {
    await complete(4);
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.label, '5/100');
  });

  test('the completed campaign stays at the final stage', () async {
    await complete(100);
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.label, '100/100');
  });

  test('legacy progress identities contribute to the reached stage', () async {
    await complete(4, legacyIds: true);
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.label, '5/100');
  });

  test('a remote extra stage is included in the real campaign total', () async {
    final extra = CampaignDefaults.stages().last.copyWith(
          id: 'bonus_stage',
          order: 101,
        );
    await firestore
        .doc('campaigns/main_campaign/stages/${extra.id}')
        .set(extra.toMap());
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.label, '1/101');
  });

  test('sparse stage orders use their position in the actual campaign',
      () async {
    final stages = CampaignDefaults.stages().take(3).toList();
    stages[1] = stages[1].copyWith(order: 20);
    stages[2] = stages[2].copyWith(order: 40);
    final custom = _CustomStagesService(firestore, stages);
    await complete(2);
    final progress = await custom.loadHomeProgress(uid: 'player');
    expect(progress.label, '3/3');
  });

  test('another campaign cannot advance the home campaign label', () async {
    await firestore.doc('users/player/campaignProgress/stage_004').set({
      'campaignId': 'another_campaign',
      'stageId': 'stage_004',
      'status': 'completed',
      'stars': 3,
    });
    final progress = await service.loadHomeProgress(uid: 'player');
    expect(progress.label, '1/100');
  });

  test('a denied progress read does not reset the home label to stage one',
      () async {
    final deniedFirestore = FakeFirebaseFirestore(securityRules: '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /campaigns/{document=**} {
      allow read: if true;
    }
    match /users/{uid}/campaignProgress/{stageId} {
      allow read: if false;
      allow write: if true;
    }
  }
}
''');
    await deniedFirestore.doc('users/player/campaignProgress/stage_004').set({
      'campaignId': CampaignDefaults.mainCampaignId,
      'stageId': 'stage_004',
      'status': 'completed',
      'stars': 3,
    });
    final denied = CampaignService(firestore: deniedFirestore);
    await expectLater(
      denied.loadHomeProgress(uid: 'player'),
      throwsA(isA<Exception>().having((error) => error.toString(),
          'security error', contains('not allowed'))),
    );
    expect(await denied.loadUserProgress(uid: 'player'), isEmpty,
        reason: 'Existing map callers keep their offline fallback');
  });
}
