import 'package:cloud_firestore/cloud_firestore.dart';

class DailyRewardProgress {
  const DailyRewardProgress(this.day, this.claimed);
  final int day;
  final bool claimed;

  static DateTime calendarDate(DateTime time) {
    final utc = time.toUtc();
    // Match the server wallet's calendar regardless of device timezone or DST.
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  factory DailyRewardProgress.fromData(
      Map<String, dynamic> data, DateTime now) {
    final last = data['lastStreakClaimDate'];
    final saved = ((data['streakDay'] as num?)?.toInt() ?? 1).clamp(1, 30);
    if (last is! Timestamp) return const DailyRewardProgress(1, false);
    final gap =
        calendarDate(now).difference(calendarDate(last.toDate())).inDays;
    if (gap <= 0) return DailyRewardProgress(saved, true);
    if (gap == 1) {
      return DailyRewardProgress(saved == 30 ? 1 : saved + 1, false);
    }
    return const DailyRewardProgress(1, false);
  }
}

class DailyRewardClaim {
  const DailyRewardClaim(
      {required this.day,
      required this.balances,
      required this.reward,
      required this.newlyGranted});
  final int day;
  final Map<String, int> balances;
  final Map<String, int> reward;
  final bool newlyGranted;
}

class DailyRewardService {
  DailyRewardService({required FirebaseFirestore firestore})
      : _firestore = firestore;
  final FirebaseFirestore _firestore;

  static const List<Map<String, int>> rewards = [
    {'coins': 100, 'gems': 0},
    {'coins': 150, 'gems': 0},
    {'coins': 200, 'gems': 1},
    {'coins': 250, 'gems': 0},
    {'coins': 300, 'gems': 1},
    {'coins': 400, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 300, 'gems': 1},
    {'coins': 350, 'gems': 1},
    {'coins': 400, 'gems': 2},
    {'coins': 450, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 600, 'gems': 3},
    {'coins': 800, 'gems': 5},
    {'coins': 400, 'gems': 2},
    {'coins': 450, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 550, 'gems': 3},
    {'coins': 600, 'gems': 4},
    {'coins': 700, 'gems': 4},
    {'coins': 1000, 'gems': 7},
    {'coins': 600, 'gems': 3},
    {'coins': 650, 'gems': 4},
    {'coins': 700, 'gems': 4},
    {'coins': 750, 'gems': 5},
    {'coins': 800, 'gems': 5},
    {'coins': 900, 'gems': 6},
    {'coins': 1000, 'gems': 7},
    {'coins': 1200, 'gems': 8},
    {'coins': 2000, 'gems': 15},
  ];

  static Map<String, int> rewardForDay(int day) =>
      rewards[(day - 1).clamp(0, rewards.length - 1)];

  /// Save the receipt and balance together. Replays only restore the balance.
  Future<DailyRewardClaim> claim(
      {required String uid,
      required DateTime now,
      int fallbackCoins = 0,
      int fallbackGems = 0}) async {
    if (uid.isEmpty || uid.contains('/')) throw ArgumentError.value(uid, 'uid');
    final ref = _firestore.collection('users').doc(uid);
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data() ?? <String, dynamic>{};
      final progress = DailyRewardProgress.fromData(data, now);
      final reward = rewardForDay(progress.day);
      int balance(String key, int fallback) =>
          ((data[key] as num?)?.toInt() ?? fallback).clamp(0, 2147483647);
      final balances = {
        'coins': balance('coins', fallbackCoins),
        'gems': balance('gems', fallbackGems)
      };
      if (!progress.claimed) {
        for (final key in balances.keys) {
          balances[key] = (balances[key]! + reward[key]!).clamp(0, 2147483647);
        }
        final update = <String, dynamic>{
          ...balances,
          'streakDay': progress.day,
          'lastStreakClaimDate': Timestamp.fromDate(now)
        };
        if (snapshot.exists) {
          tx.update(ref, update);
        } else {
          tx.set(ref, update);
        }
      }
      return DailyRewardClaim(
          day: progress.day,
          balances: balances,
          reward: reward,
          newlyGranted: !progress.claimed);
    });
  }
}
