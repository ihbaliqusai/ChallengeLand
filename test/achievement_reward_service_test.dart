import 'dart:io';

import 'package:challenge_land/models/achievement_rewards.dart';
import 'package:challenge_land/services/achievement_reward_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late AchievementRewardService service;
  const native = {
    'accountUid': 'player',
    'ACH_FIRST_GAME': true,
    'ACH_FIRST_WIN': true
  };
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = AchievementRewardService(firestore: db);
    await db
        .doc('users/player')
        .set({'coins': 500, 'gems': 10, 'xp': 100, 'username': 'Player'});
  });

  test(
      'claim all commits wallet, XP and permanent receipts; stale device replay pays zero',
      () async {
    final first = await service
        .claim(uid: 'player', native: native, identity: {'username': 'Player'});
    expect(first.newlyClaimedIds, {'ACH_FIRST_GAME', 'ACH_FIRST_WIN'});
    expect(first.coins, 130);
    expect(first.xp, 80);
    expect(first.balances, {'coins': 630, 'gems': 10});
    expect(first.stats['xp'], 180);
    final otherDevice = AchievementRewardService(firestore: db);
    final replay =
        await otherDevice.claim(uid: 'player', native: native, identity: {});
    expect(replay.newlyClaimedIds, isEmpty);
    expect(replay.coins, 0);
    expect(replay.xp, 0);
    expect(replay.balances, first.balances);
    final saved = (await db.doc('users/player').get()).data()!;
    expect(saved['username'], 'Player');
    expect(saved['claimedAchievementIds'], containsAll(first.claimedIds));
    expect((await db.doc('public_profiles/player').get()).data()!['xp'], 180);
  });

  test('individual claim and claim all share the same receipt ledger',
      () async {
    final single = await service.claim(
        uid: 'player', native: native, key: 'ACH_FIRST_GAME', identity: {});
    expect(single.coins, 50);
    final batch =
        await service.claim(uid: 'player', native: native, identity: {});
    expect(batch.newlyClaimedIds, {'ACH_FIRST_WIN'});
    expect(batch.coins, 80);
    expect(batch.balances['coins'], 630);
  });

  test(
      'legacy local claims migrate without another reward; restored device keeps receipts',
      () async {
    final migrated = await service.synchronize(
        uid: 'player', native: {...native, 'ACH_FIRST_GAME_CLAIMED': true});
    expect(migrated.claimedIds, {'ACH_FIRST_GAME'});
    expect(migrated.newlyClaimedIds, isEmpty);
    expect(migrated.balances['coins'], 500);
    final restored = await service
        .synchronize(uid: 'player', native: {'accountUid': 'player'});
    expect(restored.claimedIds, migrated.claimedIds);
    expect(restored.unlockedIds, migrated.unlockedIds);
    final batch = await service
        .claim(uid: 'player', native: {'accountUid': 'player'}, identity: {});
    expect(batch.newlyClaimedIds, {'ACH_FIRST_WIN'});
    expect(batch.stats['xp'], 150);
  });

  test('locked, unknown and wrong-account achievements cannot be paid',
      () async {
    final locked = await service.claim(
        uid: 'player',
        native: {'accountUid': 'player'},
        key: 'ACH_FIRST_GAME',
        identity: {});
    expect(locked.newlyClaimedIds, isEmpty);
    await expectLater(
        service.claim(
            uid: 'player', native: native, key: 'invented', identity: {}),
        throwsArgumentError);
    await expectLater(service.claim(uid: 'other', native: native, identity: {}),
        throwsStateError);
    expect((await db.doc('users/player').get()).data()!['coins'], 500);
    expect((await db.doc('users/other').get()).exists, isFalse);
  });

  test('a newly unlocked achievement is distinct from already claimed rewards',
      () async {
    await service.claim(uid: 'player', native: native, identity: {});
    final later = await service.claim(
        uid: 'player',
        native: {...native, 'ACH_FIRST_ONLINE': true},
        identity: {});
    expect(later.newlyClaimedIds, {'ACH_FIRST_ONLINE'});
    expect(later.claimedIds.length, 3);
    expect(later.balances['coins'], 710);
  });

  test('Flutter previews and native legacy payouts have the same rewards', () {
    final source = File(
            'android/app/src/main/java/com/Qi7bali/challengeland/PlayerProgress.java')
        .readAsStringSync();
    final entries = RegExp(
            r'((?:\s*case ACH_[A-Z0-9_]+:)+)\s*return new AchievementReward\((\d+), (\d+)\);')
        .allMatches(source);
    final nativeRewards = <String, List<int>>{};
    for (final entry in entries) {
      for (final key in RegExp(r'ACH_[A-Z0-9_]+').allMatches(entry[1]!)) {
        nativeRewards[key[0]!] = [int.parse(entry[2]!), int.parse(entry[3]!)];
      }
    }
    expect(nativeRewards.keys.toSet(), AchievementRewards.catalog.keys.toSet());
    for (final entry in AchievementRewards.catalog.entries) {
      expect([entry.value.coins, entry.value.xp], nativeRewards[entry.key],
          reason: entry.key);
    }
  });
}
