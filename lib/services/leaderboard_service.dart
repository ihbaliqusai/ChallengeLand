import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'progression_service.dart';

enum LeaderboardScope { world, country, friends }

class LeaderboardPlayer {
  const LeaderboardPlayer({
    required this.uid,
    required this.username,
    required this.trophies,
    this.level = 1,
    this.xp = 0,
    this.photoUrl = '',
    this.friendCode = '',
    this.countryCode = '',
    this.teamName = '',
    this.wins = 0,
    this.lastSeenAt,
  });

  final String uid;
  final String username;
  final int trophies;
  final int level;
  final int xp;
  final String photoUrl;
  final String friendCode;
  final String countryCode;
  final String teamName;
  final int wins;
  final DateTime? lastSeenAt;

  factory LeaderboardPlayer.fromMap(Map<String, dynamic> data,
      {required String uid}) {
    final stats = ProgressionService.readStats(data);
    final lastSeen = data['lastSeenAt'];
    var username = 'لاعب';
    final names = <String?>[
      for (final key in ['username', 'playerName', 'displayName', 'name'])
        data[key]?.toString(),
      data['email']?.toString().split('@').first,
    ];
    for (final name in names) {
      final candidate = name?.trim() ?? '';
      if (candidate.isNotEmpty &&
          !['guest', 'player'].contains(candidate.toLowerCase())) {
        username = candidate;
        break;
      }
    }
    return LeaderboardPlayer(
      uid: uid,
      username: username,
      trophies: stats['trophies']!,
      level: stats['level']!,
      xp: stats['xp']!,
      photoUrl: data['photoUrl']?.toString() ?? '',
      friendCode: data['friendCode']?.toString() ?? '',
      countryCode:
          LeaderboardService.normalizeCountryCode(data['countryCode']) ?? '',
      teamName: (data['teamName'] ?? '').toString().trim(),
      wins: stats['wins']!,
      lastSeenAt: lastSeen is Timestamp
          ? lastSeen.toDate()
          : lastSeen is DateTime
              ? lastSeen
              : null,
    );
  }
}

/// Each scope is loaded independently so its ranks are never inferred from
/// the global top-player window.
class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const maxPlayers = 200;
  static const _profileBatchSize = 30;
  static final _caches = Expando<_LeaderboardCache>();

  _LeaderboardCache get _cache => _caches[_firestore] ??= _LeaderboardCache();

  _LeaderboardCacheKey _key({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) =>
      (
        scope,
        uid ?? '',
        scope == LeaderboardScope.country
            ? normalizeCountryCode(countryCode) ?? ''
            : '',
      );

  /// Previous results are available synchronously while the query reconnects.
  /// Country and friend boards never share cached entries with another account.
  List<LeaderboardPlayer>? cached({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) =>
      _cache.read(_key(scope: scope, uid: uid, countryCode: countryCode));

  String? cachedCountry(String uid) => _cache.countries[uid];

  static String? normalizeCountryCode(dynamic value) {
    final code = value?.toString().trim().toUpperCase() ?? '';
    return RegExp(r'^[A-Z]{2}$').hasMatch(code) ? code : null;
  }

  Future<String?> loadCountry(String uid) async {
    if (uid.trim().isEmpty) return null;
    final profile = await _firestore
        .collection('public_profiles')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .firstWhere(
            (snapshot) => snapshot.exists || !snapshot.metadata.isFromCache);
    final code = normalizeCountryCode(profile.data()?['countryCode']);
    _cache.rememberCountry(uid, code);
    return code;
  }

  Future<void> saveCountry(String uid, String code) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError.value(uid, 'uid', 'A player account is required');
    }
    final normalized = normalizeCountryCode(code);
    if (normalized == null) {
      throw ArgumentError.value(code, 'code', 'Use a two-letter country code');
    }
    // Merge only identity fields. Never publish screen-cached score totals.
    await _firestore.collection('public_profiles').doc(uid).set({
      'uid': uid,
      'countryCode': normalized,
    }, SetOptions(merge: true));
    _cache.rememberCountry(uid, normalized);
  }

  Query<Map<String, dynamic>>? _query(
      LeaderboardScope scope, String? countryCode) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('public_profiles');
    if (scope == LeaderboardScope.country) {
      final code = normalizeCountryCode(countryCode);
      if (code == null) return null;
      query = query.where('countryCode', isEqualTo: code);
    }
    return query.orderBy('trophies', descending: true).limit(maxPlayers);
  }

  List<LeaderboardPlayer> _rankedSnapshot(
          QuerySnapshot<Map<String, dynamic>> snapshot) =>
      _sort(snapshot.docs
          .map((doc) => LeaderboardPlayer.fromMap(doc.data(), uid: doc.id))
          .where((player) => player.trophies > 0));

  // An empty disk-cache event does not establish that the server board is empty.
  static bool _hasUsableSnapshot(
          QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.isNotEmpty || !snapshot.metadata.isFromCache;

  /// Native snapshots deliver persisted local results before waiting for the
  /// server, then keep totals current without repeating a full screen load.
  Stream<List<LeaderboardPlayer>> watch({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) {
    final key = _key(scope: scope, uid: uid, countryCode: countryCode);
    if (scope == LeaderboardScope.friends) {
      if (uid == null || uid.trim().isEmpty) {
        return Stream.value(_cache.remember(key, const []));
      }
      return _watchFriends(uid).map((players) => _cache.remember(key, players));
    }
    final query = _query(scope, countryCode);
    if (query == null) return Stream.value(_cache.remember(key, const []));
    return query
        .snapshots(includeMetadataChanges: true)
        .where(_hasUsableSnapshot)
        .map((snapshot) => _cache.remember(key, _rankedSnapshot(snapshot)));
  }

  Future<List<LeaderboardPlayer>> load({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) async {
    final key = _key(scope: scope, uid: uid, countryCode: countryCode);
    if (scope == LeaderboardScope.friends) {
      return _cache.remember(key, await _loadFriends(uid));
    }
    final query = _query(scope, countryCode);
    if (query == null) return _cache.remember(key, const []);
    return _cache.remember(key, _rankedSnapshot(await query.get()));
  }

  List<String> _friendIds(
    String uid,
    QuerySnapshot<Map<String, dynamic>> links,
    QuerySnapshot<Map<String, dynamic>> blocks,
  ) {
    final blocked = blocks.docs
        .map((doc) => doc.data()['targetUid'])
        .whereType<String>()
        .toSet();
    final ids = <String>{uid};
    for (final doc in links.docs) {
      final data = doc.data();
      if (data['status'] != 'accepted') continue;
      final members = data['members'];
      if (members is! List) continue;
      ids.addAll(members.whereType<String>().where(
          (id) => id.isNotEmpty && !id.contains('/') && !blocked.contains(id)));
    }
    return ids.toList()..sort();
  }

  Iterable<Query<Map<String, dynamic>>> _profileQueries(
      List<String> ids) sync* {
    for (var start = 0; start < ids.length; start += _profileBatchSize) {
      final end = (start + _profileBatchSize).clamp(0, ids.length);
      yield _firestore
          .collection('public_profiles')
          .where(FieldPath.documentId, whereIn: ids.sublist(start, end));
    }
  }

  Stream<List<LeaderboardPlayer>> _watchFriends(String uid) {
    late final StreamController<List<LeaderboardPlayer>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? linksSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? blocksSubscription;
    final profileSubscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    QuerySnapshot<Map<String, dynamic>>? links, blocks;
    String? membership;
    var disposed = false;
    var generation = 0;

    void reportError(Object error, StackTrace stack) {
      if (!disposed) controller.addError(error, stack);
    }

    Future<void> refreshProfiles() async {
      if (disposed || links == null || blocks == null) return;
      final ids = _friendIds(uid, links!, blocks!);
      final signature = ids.join('\u0000');
      if (signature == membership) return;
      membership = signature;
      final current = ++generation;
      final previous = List.of(profileSubscriptions);
      profileSubscriptions.clear();
      await Future.wait(previous.map((subscription) => subscription.cancel()));
      if (disposed || current != generation) return;
      final queries = _profileQueries(ids).toList(growable: false);
      final batches = <int, List<LeaderboardPlayer>>{};
      for (var index = 0; index < queries.length; index++) {
        final batch = index;
        profileSubscriptions.add(queries[index]
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
          if (disposed ||
              current != generation ||
              !_hasUsableSnapshot(snapshot)) {
            return;
          }
          batches[batch] = snapshot.docs
              .map((doc) => LeaderboardPlayer.fromMap(doc.data(), uid: doc.id))
              .toList(growable: false);
          // Publishing one profile batch would invent intermediate ranks.
          if (batches.length == queries.length) {
            controller.add(_sort(batches.values.expand((players) => players)));
          }
        }, onError: (Object error, StackTrace stack) {
          if (current == generation) reportError(error, stack);
        }));
      }
    }

    controller = StreamController<List<LeaderboardPlayer>>(
      onListen: () {
        linksSubscription = _firestore
            .collection('social_links')
            .where('members', arrayContains: uid)
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
          if (!_hasUsableSnapshot(snapshot)) return;
          links = snapshot;
          unawaited(refreshProfiles().catchError(reportError));
        }, onError: reportError);
        blocksSubscription = _firestore
            .collection('social_blocks')
            .where('ownerUid', isEqualTo: uid)
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
          if (!_hasUsableSnapshot(snapshot)) return;
          blocks = snapshot;
          unawaited(refreshProfiles().catchError(reportError));
        }, onError: reportError);
      },
      onCancel: () async {
        disposed = true;
        generation++;
        await Future.wait([
          if (linksSubscription != null) linksSubscription!.cancel(),
          if (blocksSubscription != null) blocksSubscription!.cancel(),
          for (final subscription in profileSubscriptions)
            subscription.cancel(),
        ]);
      },
    );
    return controller.stream;
  }

  Future<List<LeaderboardPlayer>> _loadFriends(String? uid) async {
    if (uid == null || uid.trim().isEmpty) return const [];
    final snapshots = await Future.wait([
      _firestore
          .collection('social_links')
          .where('members', arrayContains: uid)
          .get(),
      _firestore
          .collection('social_blocks')
          .where('ownerUid', isEqualTo: uid)
          .get(),
    ]);
    final ids = _friendIds(uid, snapshots[0], snapshots[1]);
    final profiles =
        await Future.wait(_profileQueries(ids).map((query) => query.get()));
    return _sort(profiles
        .expand((snapshot) => snapshot.docs)
        .map((doc) => LeaderboardPlayer.fromMap(doc.data(), uid: doc.id)));
  }

  static List<LeaderboardPlayer> _sort(Iterable<LeaderboardPlayer> players) {
    final sorted = players.toList();
    sorted.sort((a, b) {
      final score = b.trophies.compareTo(a.trophies);
      return score != 0 ? score : b.uid.compareTo(a.uid);
    });
    return sorted.take(maxPlayers).toList(growable: false);
  }
}

typedef _LeaderboardCacheKey = (LeaderboardScope, String, String);

class _LeaderboardCache {
  static const capacity = 8;
  final boards = <_LeaderboardCacheKey, List<LeaderboardPlayer>>{};
  final countries = <String, String?>{};

  List<LeaderboardPlayer>? read(_LeaderboardCacheKey key) {
    final players = boards.remove(key);
    if (players != null) boards[key] = players;
    return players;
  }

  List<LeaderboardPlayer> remember(
      _LeaderboardCacheKey key, Iterable<LeaderboardPlayer> players) {
    final snapshot = List<LeaderboardPlayer>.unmodifiable(players);
    boards.remove(key);
    boards[key] = snapshot;
    if (boards.length > capacity) boards.remove(boards.keys.first);
    return snapshot;
  }

  void rememberCountry(String uid, String? country) {
    countries.remove(uid);
    countries[uid] = country;
    if (countries.length > capacity) countries.remove(countries.keys.first);
  }
}
