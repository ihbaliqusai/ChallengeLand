import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/achievement_rewards.dart';
import 'progression_service.dart';

class AchievementPayout {
  const AchievementPayout(
      {required this.claimedIds,
      required this.unlockedIds,
      required this.newlyClaimedIds,
      required this.coins,
      required this.xp,
      required this.balances,
      required this.stats});
  final Set<String> claimedIds;
  final Set<String> unlockedIds;
  final Set<String> newlyClaimedIds;
  final int coins;
  final int xp;
  final Map<String, int> balances;
  final Map<String, int> stats;
}

/// The account receipt, wallet and XP commit in one Firestore transaction.
/// Local legacy receipts are imported without awarding them again.
class AchievementRewardService {
  AchievementRewardService({required FirebaseFirestore firestore})
      : _firestore = firestore;
  final FirebaseFirestore _firestore;

  Set<String> _ids(dynamic value) => value is List
      ? value
          .whereType<String>()
          .where(AchievementRewards.catalog.containsKey)
          .toSet()
      : <String>{};

  Future<AchievementPayout> synchronize(
          {required String uid, required Map<String, dynamic> native}) =>
      _execute(uid: uid, native: native, pay: false);

  Future<AchievementPayout> claim(
          {required String uid,
          required Map<String, dynamic> native,
          String? key,
          required Map<String, dynamic> identity}) =>
      _execute(
          uid: uid, native: native, key: key, pay: true, identity: identity);

  Future<AchievementPayout> _execute(
      {required String uid,
      required Map<String, dynamic> native,
      required bool pay,
      String? key,
      Map<String, dynamic> identity = const {}}) async {
    if (uid.trim().isEmpty ||
        uid.contains('/') ||
        native['accountUid'] != uid) {
      throw StateError('Achievement snapshot belongs to another account');
    }
    if (key != null && !AchievementRewards.catalog.containsKey(key)) {
      throw ArgumentError.value(key, 'key');
    }
    final localUnlocked = <String>{};
    final localClaimed = <String>{};
    for (final id in AchievementRewards.catalog.keys) {
      if (native[id] == true) localUnlocked.add(id);
      if (native['${id}_CLAIMED'] == true) {
        localClaimed.add(id);
        localUnlocked.add(id);
      }
    }
    final userRef = _firestore.collection('users').doc(uid);
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final claimed = _ids(data['claimedAchievementIds'])..addAll(localClaimed);
      final unlocked = _ids(data['unlockedAchievementIds'])
        ..addAll(localUnlocked)
        ..addAll(claimed);
      final fresh = pay
          ? unlocked
              .where(
                  (id) => !claimed.contains(id) && (key == null || key == id))
              .toSet()
          : <String>{};
      final rewardCoins = fresh.fold<int>(
          0, (total, id) => total + AchievementRewards.catalog[id]!.coins);
      final rewardXp = fresh.fold<int>(
          0, (total, id) => total + AchievementRewards.catalog[id]!.xp);
      final balances = {
        'coins': (ProgressionService.integer(data['coins']) + rewardCoins)
            .clamp(0, ProgressionService.maxValue),
        'gems': ProgressionService.integer(data['gems']),
      };
      var stats = ProgressionService.readStats(data);
      stats['xp'] =
          (stats['xp']! + rewardXp).clamp(0, ProgressionService.maxValue);
      stats = ProgressionService.normalize(stats);
      claimed.addAll(fresh);
      final update = <String, dynamic>{
        'claimedAchievementIds': claimed.toList()..sort(),
        'unlockedAchievementIds': unlocked.toList()..sort(),
        'achievementClaimsVersion': 2,
        'achievementUpdatedAt': FieldValue.serverTimestamp(),
        if (fresh.isNotEmpty) ...balances,
        if (fresh.isNotEmpty) ...ProgressionService.privatePayload(stats),
      };
      if (snapshot.exists) {
        tx.update(userRef, update);
      } else {
        tx.set(userRef, update);
      }
      if (fresh.isNotEmpty) {
        tx.set(
            _firestore.collection('public_profiles').doc(uid),
            ProgressionService.publicPayload(uid, stats, identity),
            SetOptions(merge: true));
      }
      return AchievementPayout(
          claimedIds: claimed,
          unlockedIds: unlocked,
          newlyClaimedIds: fresh,
          coins: rewardCoins,
          xp: rewardXp,
          balances: balances,
          stats: stats);
    });
  }
}
