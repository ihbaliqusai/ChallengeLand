import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/player_rank.dart';

/// Account totals and installation acknowledgements commit together. Replaying
/// a transaction after its response is lost never awards the same play twice.
class ProgressionService {
  ProgressionService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  static const version = 2;
  static const maxValue = 2147483647;
  static const modes = <String>[
    'campaign',
    'offline',
    'local_teams',
    'board',
    'battle',
    'team_battle',
    'blitz',
    'elimination',
    'survival',
    'series',
  ];
  static const modeOutcomes = <String>[
    'games',
    'wins',
    'losses',
    'draws',
    'abandoned',
  ];
  static const additiveKeys = <String>[
    'xp',
    'gamesPlayed',
    'wins',
    'losses',
    'draws',
    'abandoned',
    'correctAnswers',
    'wrongAnswers',
    'totalEarnings',
    'onlineWins',
    'trophiesEarned',
    'trophiesLost',
    'blitzFinishes',
    'eliminationWins',
    'survivalWins',
    'seriesWins',
    'teamBattleWins',
    'localTeamsPlayed',
    'offlineBoardPlayed',
    'offlineBoardWins',
    'friendMatchesPlayed',
    'randomMatchesPlayed',
  ];
  static const maximumKeys = <String>[
    'bestStreak',
    'bestWinStreak',
    'highestMoney',
    'bestTrophies',
  ];
  static final modeKeys = <String>[
    for (final mode in modes)
      for (final outcome in modeOutcomes) 'mode_${mode}_$outcome',
  ];
  static final cumulativeKeys = <String>[...additiveKeys, ...modeKeys];
  static final statKeys = <String>[
    ...cumulativeKeys,
    ...maximumKeys,
    'trophies',
    'winStreak',
    'lastPrize',
  ];
  static const publicIdentityKeys = <String>[
    'username',
    'photoUrl',
    'friendCode',
    'rating',
    'createdAt',
  ];
  static const publicStatKeys = <String>[
    ...additiveKeys,
    ...maximumKeys,
    'trophies',
    'winStreak',
    'lastPrize',
    'level',
    'totalAnswered',
    'accuracy',
    'winPercent',
    'progressionVersion',
  ];

  static int integer(dynamic value) =>
      value is num && value.isFinite ? value.toInt().clamp(0, maxValue) : 0;

  static int _signedInteger(dynamic value) => value is num && value.isFinite
      ? value.toInt().clamp(-maxValue, maxValue)
      : 0;

  static String _documentId(String value, String name) {
    final id = value.trim();
    if (id.isEmpty || id.contains('/') || id == '.' || id == '..') {
      throw ArgumentError.value(value, name, 'A valid document ID is required');
    }
    return id;
  }

  static Map<String, int> readStats(Map<String, dynamic> data) {
    final nested = data['playerStats'];
    final source = nested is Map ? Map<String, dynamic>.from(nested) : data;
    final result = <String, int>{
      for (final key in statKeys) key: integer(source[key] ?? data[key]),
    };
    if (source['xp'] == null && data['xp'] == null) {
      // Older profiles sometimes published only a level. Its entry threshold
      // is the conservative XP floor that preserves earned unlocks on restore.
      final legacyLevel = integer(
        source['level'] ?? data['level'],
      ).clamp(1, 999999);
      result['xp'] = math.max(
        integer(data['totalScore']),
        PlayerRank.xpForLevel(legacyLevel).clamp(0, maxValue),
      );
    }
    if (nested is! Map) {
      result['gamesPlayed'] = math.max(
        result['gamesPlayed']!,
        integer(data['lastKnownGamesPlayed'] ?? data['totalMatches']),
      );
      result['wins'] = math.max(
        result['wins']!,
        integer(data['lastKnownWins']),
      );
    }
    return normalize(result);
  }

  static Map<String, int> normalize(Map<String, int> stats) {
    final result = <String, int>{
      for (final key in statKeys) key: integer(stats[key]),
    };
    final xp = result['xp']!;
    final games = result['gamesPlayed']!;
    final correct = result['correctAnswers']!;
    final answered = correct + result['wrongAnswers']!;
    result.addAll({
      'level': PlayerRank.levelForXp(xp),
      'totalAnswered': answered.clamp(0, maxValue),
      'accuracy': answered == 0 ? 0 : (correct * 100 / answered).round(),
      'winPercent': games == 0
          ? 0
          : (result['wins']! * 100 / games).round().clamp(0, 100),
      'bestTrophies': math.max(result['bestTrophies']!, result['trophies']!),
      'progressionVersion': version,
    });
    return result;
  }

  Future<Map<String, int>> synchronize({
    required String uid,
    required String deviceId,
    required Map<String, int> nativeStats,
    required Map<String, int> contributions,
    required Map<String, dynamic> identity,
  }) async {
    final playerId = _documentId(uid, 'uid');
    final installationId = _documentId(deviceId, 'deviceId');
    final userRef = _firestore.collection('users').doc(playerId);
    final checkpointRef = userRef
        .collection('progressionDevices')
        .doc(installationId);
    final publicRef = _firestore.collection('public_profiles').doc(playerId);
    // Capture immutable inputs before Firestore retries this callback.
    final local = Map<String, int>.from(nativeStats);
    final captured = Map<String, int>.from(contributions);
    final publicIdentity = Map<String, dynamic>.from(identity);
    return _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      final checkpoint = await transaction.get(checkpointRef);
      final data = user.data() ?? <String, dynamic>{};
      final previous = checkpoint.data()?['contributions'];
      final previousCounters = previous is Map ? previous : const {};
      final acknowledged = <String, int>{};
      var totals = readStats(data);
      final importLegacy =
          !checkpoint.exists && integer(data['progressionVersion']) < version;
      var stale = false;
      var newGames = false;

      for (final key in cumulativeKeys) {
        final before = integer(previousCounters[key]);
        // A partial/older capture cannot erase an acknowledgement and cause a
        // subsequent retry to award the missing counters again.
        final incoming = captured.containsKey(key)
            ? integer(captured[key])
            : before;
        if (incoming < before) stale = true;
        final after = math.max(before, incoming);
        acknowledged[key] = after;
        final delta = after - before;
        if (key == 'gamesPlayed') newGames = delta > 0;
        totals[key] = importLegacy
            ? math.max(totals[key] ?? 0, integer(local[key]))
            : ((totals[key] ?? 0) + delta).clamp(0, maxValue);
      }

      // Unlike every cumulative counter, the installation's net trophy
      // contribution is signed: losses must lower the account's current total.
      final previousTrophies = _signedInteger(previousCounters['trophies']);
      final trophyContribution = stale
          ? previousTrophies
          : captured.containsKey('trophies')
          ? _signedInteger(captured['trophies'])
          : previousTrophies;
      acknowledged['trophies'] = trophyContribution;
      totals['trophies'] = importLegacy
          ? math.max(totals['trophies'] ?? 0, integer(local['trophies']))
          : ((totals['trophies'] ?? 0) + trophyContribution - previousTrophies)
                .clamp(0, maxValue);
      for (final key in maximumKeys) {
        totals[key] = math.max(totals[key] ?? 0, integer(local[key]));
      }
      if (newGames || importLegacy) {
        totals['winStreak'] = integer(local['winStreak']);
        totals['lastPrize'] = integer(local['lastPrize']);
      }
      totals = normalize(totals);
      transaction.set(checkpointRef, {
        'contributions': acknowledged,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': version,
      });
      transaction.set(userRef, privatePayload(totals), SetOptions(merge: true));
      transaction.set(
        publicRef,
        publicPayload(playerId, totals, publicIdentity),
        SetOptions(merge: true),
      );
      return totals;
    });
  }

  Future<Map<String, int>> grantCampaignXp({
    required String uid,
    required String claimId,
    required Map<String, dynamic> identity,
  }) async {
    final playerId = _documentId(uid, 'uid');
    final receiptId = _documentId(claimId, 'claimId');
    final userRef = _firestore.collection('users').doc(playerId);
    final claimRef = userRef.collection('campaignRewardClaims').doc(receiptId);
    final publicIdentity = Map<String, dynamic>.from(identity);
    return _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      final claim = await transaction.get(claimRef);
      if (!claim.exists) throw StateError('Campaign reward claim is missing');
      final receipt = claim.data()!;
      if (receipt['uid'] != playerId) {
        throw StateError('Campaign reward belongs to a different account');
      }
      var totals = readStats(user.data() ?? {});
      if (receipt['xpClaimed'] != true) {
        final reward = receipt['xp'];
        if (reward is! int || reward < 0 || reward > maxValue) {
          throw StateError('Campaign XP reward is invalid');
        }
        totals['xp'] = ((totals['xp'] ?? 0) + reward).clamp(0, maxValue);
        totals = normalize(totals);
        transaction.update(claimRef, {
          'xpClaimed': true,
          if (receipt['currencyClaimed'] == true) 'status': 'claimed',
          if (receipt['currencyClaimed'] == true)
            'claimedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(userRef, privatePayload(totals), SetOptions(merge: true));
      transaction.set(
        _firestore.collection('public_profiles').doc(playerId),
        publicPayload(playerId, totals, publicIdentity),
        SetOptions(merge: true),
      );
      return totals;
    });
  }

  static Map<String, dynamic> privatePayload(Map<String, int> stats) => {
    'playerStats': stats,
    'xp': stats['xp'] ?? 0,
    'level': stats['level'] ?? 1,
    'trophies': stats['trophies'] ?? 0,
    'bestTrophies': stats['bestTrophies'] ?? 0,
    'wins': stats['wins'] ?? 0,
    'losses': stats['losses'] ?? 0,
    'draws': stats['draws'] ?? 0,
    'totalMatches': stats['gamesPlayed'] ?? 0,
    'totalScore': stats['xp'] ?? 0,
    'progressionVersion': version,
    'progressionUpdatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, dynamic> publicPayload(
    String uid,
    Map<String, int> stats,
    Map<String, dynamic> identity,
  ) {
    final normalized = normalize(stats);
    return {
      'uid': uid,
      for (final key in publicIdentityKeys)
        if (identity.containsKey(key)) key: identity[key],
      for (final key in publicStatKeys) key: normalized[key],
      'totalMatches': normalized['gamesPlayed'],
      'totalScore': normalized['xp'],
      'lastSeenAt': FieldValue.serverTimestamp(),
    };
  }
}
