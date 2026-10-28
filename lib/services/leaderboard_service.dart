import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/leaderboard_countries.dart';
import 'device_country_service.dart';
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
  LeaderboardService(
      {FirebaseFirestore? firestore,
      Future<String?> Function()? detectCountry,
      Duration countryReadTimeout = const Duration(seconds: 2)})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _detectCountry =
            detectCountry ?? DeviceCountryService().detectCountryCode,
        _countryReadTimeout = countryReadTimeout;

  final FirebaseFirestore _firestore;
  final Future<String?> Function() _detectCountry;
  final Duration _countryReadTimeout;
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
    return leaderboardCountries.containsKey(code) ? code : null;
  }

  Future<String?> loadCountry(String uid) =>
      _resolveCountry(uid, isActive: () => true);

  /// Authentication can change while a stored profile or device hint is read.
  /// The caller's guard also protects the deferred write after this returns.
  Future<String?> ensureCountry(String uid,
          {required bool Function() isActive}) =>
      _resolveCountry(uid, isActive: isActive);

  Future<DocumentSnapshot<Map<String, dynamic>>?> _countryProfile(String uid,
      {required bool Function() isActive}) {
    final result = Completer<DocumentSnapshot<Map<String, dynamic>>?>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? deadline, activityCheck;
    void cancel() {
      deadline?.cancel();
      activityCheck?.cancel();
      unawaited(subscription?.cancel().catchError((_) {}));
    }

    void finish(DocumentSnapshot<Map<String, dynamic>>? snapshot) {
      if (result.isCompleted) return;
      result.complete(snapshot);
      cancel();
    }

    deadline = Timer(_countryReadTimeout, () => finish(null));
    activityCheck = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!isActive()) finish(null);
    });
    subscription = _firestore
        .collection('public_profiles')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (result.isCompleted ||
          (!snapshot.exists && snapshot.metadata.isFromCache)) {
        return;
      }
      // First usable data is available before listener teardown finishes.
      finish(snapshot);
    }, onError: (Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
      cancel();
    }, onDone: () => finish(null));
    // Also handle streams whose first event arrives synchronously in listen().
    if (result.isCompleted) cancel();
    return result.future;
  }

  Future<String?> _resolveCountry(String uid,
      {required bool Function() isActive}) async {
    if (uid.trim().isEmpty || uid.contains('/') || !isActive()) return null;
    final version = _cache.countryVersion(uid);
    bool current() =>
        isActive() && identical(_cache.countryVersions[uid], version);
    final profile = await _countryProfile(uid, isActive: current);
    if (!isActive()) return null;
    if (!current()) return cachedCountry(uid);
    final stored = normalizeCountryCode(profile?.data()?['countryCode']);
    if (stored != null) {
      _cache.rememberCountry(uid, stored);
      return stored;
    }
    String? detected;
    try {
      detected = normalizeCountryCode(await _detectCountry());
    } catch (_) {
      // Device hints can be unavailable; never substitute an invented country.
      return current() ? cachedCountry(uid) : null;
    }
    if (!isActive()) return null;
    if (!current()) return cachedCountry(uid);
    if (detected == null || !leaderboardCountries.containsKey(detected)) {
      return null;
    }
    _cache.rememberCountry(uid, detected);
    unawaited(_persistDetectedCountry(uid, detected, isCurrent: current));
    return detected;
  }

  Future<void> _persistDetectedCountry(String uid, String country,
      {required bool Function() isCurrent}) async {
    try {
      final reference = _firestore.collection('public_profiles').doc(uid);
      final stored =
          await _firestore.runTransaction<String?>((transaction) async {
        if (!isCurrent()) return null;
        final profile = await transaction.get(reference);
        if (!isCurrent()) return null;
        final previous = normalizeCountryCode(profile.data()?['countryCode']);
        if (previous != null) return previous;
        if (!isCurrent()) return null;
        // A retry sees a concurrent manual choice and leaves it intact.
        if (profile.exists) {
          transaction.update(reference, {'uid': uid, 'countryCode': country});
        } else {
          transaction.set(reference, {'uid': uid, 'countryCode': country});
        }
        return country;
      });
      if (isCurrent() && stored != null) _cache.rememberCountry(uid, stored);
    } catch (_) {
      // Country detection remains useful offline. A later resolution retries
      // persistence; no network transaction belongs on the UI's critical path.
    }
  }

  Future<void> saveCountry(String uid, String code) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError.value(uid, 'uid', 'A player account is required');
    }
    final normalized = normalizeCountryCode(code);
    if (normalized == null) {
      throw ArgumentError.value(code, 'code', 'Use a two-letter country code');
    }
    // Invalidate an automatic hint as soon as a manual choice starts, including
    // automatic work owned by another service instance for the same database.
    final version = _cache.beginCountryEdit(uid);
    // Merge only identity fields. Never publish screen-cached score totals.
    await _firestore.collection('public_profiles').doc(uid).set({
      'uid': uid,
      'countryCode': normalized,
    }, SetOptions(merge: true));
    if (identical(_cache.countryVersions[uid], version)) {
      _cache.rememberCountry(uid, normalized);
    }
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

  /// Counts the published players ahead of this account, beyond the top window.
  Future<int?> loadWorldRank({required String uid}) async {
    final id = uid.trim();
    if (id.isEmpty || id.contains('/')) return null;
    final profile = await _firestore
        .collection('public_profiles')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (profile.metadata.hasPendingWrites || profile.metadata.isFromCache) {
      throw StateError('The published player score is not confirmed');
    }
    return _worldRank(profile);
  }

  Future<int?> _worldRank(
      DocumentSnapshot<Map<String, dynamic>> profile) async {
    final trophies = profile.data()?['trophies'];
    if (!profile.exists ||
        trophies is! num ||
        !trophies.isFinite ||
        trophies <= 0) {
      return null;
    }
    final ahead = await _firestore
        .collection('public_profiles')
        .where('trophies', isGreaterThan: 0)
        .orderBy('trophies', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .endBeforeDocument(profile)
        .count()
        .get();
    final count = ahead.count;
    if (count == null) throw StateError('The global rank count is unavailable');
    return count + 1;
  }

  /// Score publications refresh this account's rank without downloading boards.
  Stream<int?> watchWorldRank({required String uid}) {
    final id = uid.trim();
    if (id.isEmpty || id.contains('/')) return Stream.value(null);
    late final StreamController<int?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    var disposed = false;
    var revision = 0;
    var hasScore = false;
    num? score;
    controller = StreamController<int?>(
      onListen: () {
        subscription = _firestore
            .collection('public_profiles')
            .doc(id)
            .snapshots(includeMetadataChanges: true)
            .listen((profile) {
          if (profile.metadata.isFromCache ||
              profile.metadata.hasPendingWrites) {
            return;
          }
          final value = profile.data()?['trophies'];
          final published =
              value is num && value.isFinite && value > 0 ? value : null;
          if (hasScore && score == published) return;
          hasScore = true;
          score = published;
          final current = ++revision;
          unawaited(() async {
            try {
              final rank = await _worldRank(profile);
              if (!disposed && current == revision) controller.add(rank);
            } catch (error, stack) {
              if (!disposed && current == revision) {
                controller.addError(error, stack);
              }
            }
          }());
        }, onError: (Object error, StackTrace stack) {
          if (!disposed) controller.addError(error, stack);
        });
      },
      onCancel: () {
        disposed = true;
        revision++;
        return subscription?.cancel();
      },
    );
    return controller.stream;
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
  final countryVersions = <String, Object>{};

  Object countryVersion(String uid) {
    if (!countries.containsKey(uid)) rememberCountry(uid, null);
    return countryVersions.putIfAbsent(uid, Object.new);
  }

  Object beginCountryEdit(String uid) {
    rememberCountry(uid, countries[uid]);
    return countryVersions[uid] = Object();
  }

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
    if (countries.length > capacity) {
      final oldest = countries.keys.first;
      countries.remove(oldest);
      countryVersions.remove(oldest);
    }
  }
}
