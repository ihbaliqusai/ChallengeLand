import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/daily_reward_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 10, 12);
  Map<String, dynamic> saved(int day, DateTime date) => {
        'streakDay': day,
        'lastStreakClaimDate': Timestamp.fromDate(date),
      };

  test('calendar progression handles midnight, missed days and cycle rollover',
      () {
    expect(DailyRewardProgress.fromData({}, now).day, 1);
    final today = DailyRewardProgress.fromData(saved(7, now), now);
    expect(today.day, 7);
    expect(today.claimed, isTrue);
    final midnight = DailyRewardProgress.fromData(
        saved(7, DateTime(2026, 10, 9, 23, 59)), DateTime(2026, 10, 10, 0, 1));
    expect(midnight.day, 8);
    expect(midnight.claimed, isFalse);
    expect(
        DailyRewardProgress.fromData(saved(20, DateTime(2026, 10, 8)), now).day,
        1);
    expect(
        DailyRewardProgress.fromData(saved(30, DateTime(2026, 10, 9)), now).day,
        1);
    expect(
        DailyRewardProgress.fromData(saved(7, DateTime(2026, 10, 11)), now)
            .claimed,
        isTrue);
  });

  test('a second device restores a claim without another grant or profile loss',
      () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/player').set({
      'coins': 500,
      'gems': 10,
      'username': 'Player',
      ...saved(6, DateTime(2026, 10, 9))
    });
    final first =
        await DailyRewardService(firestore: db).claim(uid: 'player', now: now);
    expect(first.day, 7);
    expect(first.newlyGranted, isTrue);
    expect(first.balances, {'coins': 1000, 'gems': 13});
    final replay = await DailyRewardService(firestore: db)
        .claim(uid: 'player', now: now, fallbackCoins: 9999);
    expect(replay.newlyGranted, isFalse);
    expect(replay.balances, first.balances);
    final data = (await db.doc('users/player').get()).data()!;
    expect(data['username'], 'Player');
    expect(data['coins'], 1000);
    expect(data['streakDay'], 7);
  });

  test('legacy claimed days stay claimed and native balances cannot overflow',
      () async {
    final db = FakeFirebaseFirestore();
    final service = DailyRewardService(firestore: db);
    await db
        .doc('users/legacy')
        .set({'coins': 120, 'gems': 2, ...saved(7, now)});
    final legacy = await service.claim(uid: 'legacy', now: now);
    expect(legacy.newlyGranted, isFalse);
    expect(legacy.balances, {'coins': 120, 'gems': 2});
    await db.doc('users/maximum').set({
      'coins': 2147483646,
      'gems': 2147483646,
      ...saved(29, DateTime(2026, 10, 9))
    });
    final capped = await service.claim(uid: 'maximum', now: now);
    expect(capped.balances, {'coins': 2147483647, 'gems': 2147483647});
  });
  group('Daily Reward & Streak Tests', () {
    test('AppState.streakRewards contains 30 days of balanced rewards', () {
      expect(AppState.streakRewards.length, 30);

      // Verify Day 1
      final day1 = AppState.getRewardForDay(1);
      expect(day1['coins'], greaterThanOrEqualTo(100));
      expect(day1['gems'], greaterThanOrEqualTo(0));

      // Verify Day 7 milestone
      final day7 = AppState.getRewardForDay(7);
      expect(day7['coins'], greaterThanOrEqualTo(500));
      expect(day7['gems'], greaterThanOrEqualTo(3));

      // Verify Day 30 grand milestone
      final day30 = AppState.getRewardForDay(30);
      expect(day30['coins'], 2000);
      expect(day30['gems'], 15);
    });

    test('AppState.getRewardForDay clamps correctly out of range', () {
      final below = AppState.getRewardForDay(0);
      expect(below, AppState.streakRewards.first);

      final above = AppState.getRewardForDay(999);
      expect(above, AppState.streakRewards.last);
    });
  });
}
