import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/social_player_activity.dart';

/// Shared social protocol. Membership, deadlines and transitions are also
/// enforced by Firestore rules; UI state is never the authority.
class SocialService {
  SocialService({FirebaseFirestore? firestore, DateTime Function()? clock})
      : db = firestore ?? FirebaseFirestore.instance,
        _clock = clock;
  final FirebaseFirestore db;
  final DateTime Function()? _clock;
  DateTime? _serverAnchor;
  final _elapsed = Stopwatch();
  Future<void>? _clockSync;
  final _rankedStreams =
      <int, Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>{};
  DateTime get now =>
      _clock?.call() ??
      (_serverAnchor == null
          ? DateTime.now()
          : _serverAnchor!.add(_elapsed.elapsed));

  Future<void> syncClock() async {
    if (_clock != null ||
        (_serverAnchor != null && _elapsed.elapsed.inSeconds < 30)) {
      return;
    }
    if (_clockSync != null) return _clockSync;
    _clockSync = _readClock();
    try {
      await _clockSync;
    } finally {
      _clockSync = null;
    }
  }

  Future<void> _readClock() async {
    try {
      final milliseconds = await const MethodChannel('millionaire/native')
          .invokeMethod<int>('getSocialServerTime');
      if (milliseconds != null) {
        _serverAnchor = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        _elapsed
          ..reset()
          ..start();
      }
    } on PlatformException {
      /* Fall back until the native connection returns. */
    } on MissingPluginException {
      /* Non-Android previews use their local clock. */
    }
  }

  final _queryStreams = <String, Stream<QuerySnapshot<Map<String, dynamic>>>>{};
  final _documentStreams =
      <String, Stream<DocumentSnapshot<Map<String, dynamic>>>>{};
  final _profiles = <String, Future<Map<String, dynamic>>>{};
  final _profileTimes = <String, DateTime>{};
  static const presenceLease = SocialActivity.presenceLease;
  static const invitationLifetime = Duration(seconds: 30);
  static const profileTimeout = Duration(seconds: 8);

  /// Retry creates fresh listeners rather than reusing a failed transformed
  /// broadcast stream. Existing shell subscriptions continue independently.
  void refreshReads() {
    _queryStreams.clear();
    _documentStreams.clear();
    _rankedStreams.clear();
    _profiles.clear();
    _profileTimes.clear();
  }

  static String pairId(String a, String b) {
    final valid = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (a == b || !valid.hasMatch(a) || !valid.hasMatch(b)) {
      throw const SocialException('لا يمكن تنفيذ الطلب لهذا الحساب.');
    }
    final pair = [a, b]..sort();
    return pair.join(':');
  }

  static bool fresh(Map<String, dynamic>? data, DateTime now) {
    final stamp = data?['heartbeatAt'];
    if (stamp is! Timestamp) return false;
    final age = now.difference(stamp.toDate());
    return age >= const Duration(seconds: -10) &&
        age < presenceLease &&
        (data?['state'] == 'available' || data?['state'] == 'in_match');
  }

  static bool pending(Map<String, dynamic> data, DateTime now) =>
      data['status'] == 'pending' &&
      data['expiresAt'] is Timestamp &&
      (data['expiresAt'] as Timestamp).toDate().isAfter(now);

  Stream<QuerySnapshot<Map<String, dynamic>>> links(String uid) =>
      _queryStreams.putIfAbsent(
          'links:$uid',
          () => db
              .collection('social_links')
              .where('members', arrayContains: uid)
              .orderBy('updatedAt', descending: true)
              .snapshots());
  Stream<QuerySnapshot<Map<String, dynamic>>> challenges(String uid) =>
      _queryStreams.putIfAbsent(
          'challenges:$uid',
          () => db
              .collection('social_challenges')
              .where('members', arrayContains: uid)
              .orderBy('createdAt', descending: true)
              .limit(40)
              .snapshots());
  Stream<QuerySnapshot<Map<String, dynamic>>> players() =>
      _queryStreams.putIfAbsent(
          'players',
          () => db
              .collection('player_presence')
              .where('discoverable', isEqualTo: true)
              .orderBy('heartbeatAt', descending: true)
              .limit(60)
              .snapshots());

  /// Includes today's discoverable players plus six hours before midnight.
  /// The fixed daily bound tolerates a server clock correction after opening
  /// the page. UI activity groups filter this bounded feed as time advances;
  /// the stream itself remains stable throughout the day.
  Stream<QuerySnapshot<Map<String, dynamic>>> recentPlayers() {
    final current = now;
    final midnight = current.isUtc
        ? DateTime.utc(current.year, current.month, current.day)
        : DateTime(current.year, current.month, current.day);
    final cutoff = midnight.subtract(const Duration(hours: 6));
    return _queryStreams.putIfAbsent(
        'recentPlayers:${midnight.toIso8601String()}',
        () => db
            .collection('player_presence')
            .where('discoverable', isEqualTo: true)
            .where('heartbeatAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
            .orderBy('heartbeatAt', descending: true)
            .limit(120)
            .snapshots());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> presence(String uid) =>
      _documentStreams.putIfAbsent('presence:$uid',
          () => db.collection('player_presence').doc(uid).snapshots());
  Stream<DocumentSnapshot<Map<String, dynamic>>> settings(String uid) =>
      _documentStreams.putIfAbsent('settings:$uid',
          () => db.collection('social_settings').doc(uid).snapshots());
  Stream<QuerySnapshot<Map<String, dynamic>>> blocks(String uid) =>
      _queryStreams.putIfAbsent(
          'blocks:$uid',
          () => db
              .collection('social_blocks')
              .where('ownerUid', isEqualTo: uid)
              .snapshots());
  Future<Map<String, dynamic>> profile(String uid,
      {bool forceRefresh = false}) {
    final loaded = _profileTimes[uid];
    if (forceRefresh ||
        loaded == null ||
        now.difference(loaded).inSeconds >= 60) {
      _profileTimes[uid] = now;
      _profiles[uid] = _readProfile(uid);
    }
    return _profiles[uid]!;
  }

  Future<Map<String, dynamic>> _readProfile(String uid) async =>
      (await db
              .collection('public_profiles')
              .doc(uid)
              .get()
              .timeout(profileTimeout))
          .data() ??
      {
        'uid': uid,
        'username': 'لاعب',
        '_profileMissing': true,
      };

  Future<String> findCode(String code) async {
    final result = await db
        .collection('public_profiles')
        .where('friendCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (result.docs.isEmpty) {
      throw const SocialException('لم يُعثر على لاعب بهذا الرمز.');
    }
    return result.docs.first.id;
  }

  Future<void> setSettings(String uid, bool discoverable, String policy) =>
      db.collection('social_settings').doc(uid).set({
        'discoverable': discoverable,
        'allowChallenges': policy,
      });

  /// A bounded discovery feed prioritizes available opponents near the caller's
  /// trophy count. It suggests peers; it does not alter competitive matchmaking.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> suggestedPlayers(
          int trophies) =>
      _rankedStreams.putIfAbsent(
          trophies,
          () => players().asyncExpand((snapshot) async* {
                final documents =
                    snapshot.docs.where((d) => fresh(d.data(), now)).toList();
                // Presence is sufficient to show the list. Profile lookups are
                // optional enrichment and must never hold the whole page.
                yield documents.toList();
                final profiles = await Future.wait(documents.map((d) =>
                    profile(d.id)
                        .catchError((Object _) => <String, dynamic>{})));
                final ratings = <String, int>{};
                for (var i = 0; i < documents.length; i++) {
                  final value = profiles[i]['trophies'];
                  ratings[documents[i].id] = value is num ? value.toInt() : 0;
                }
                documents.sort((a, b) {
                  final availability =
                      (a.data()['state'] == 'available' ? 0 : 1)
                          .compareTo(b.data()['state'] == 'available' ? 0 : 1);
                  return availability != 0
                      ? availability
                      : ((ratings[a.id] ?? 0) - trophies)
                          .abs()
                          .compareTo(((ratings[b.id] ?? 0) - trophies).abs());
                });
                yield documents;
              }));

  Future<void> send(String uid, String peer, {required bool challenge}) async {
    await syncClock();
    final id = pairId(uid, peer);
    final collection = challenge ? 'social_challenges' : 'social_links';
    final ref = db.collection(collection).doc(id);
    await db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final blocked =
          await tx.get(db.collection('social_blocks').doc('$uid:$peer'));
      final blockedBy =
          await tx.get(db.collection('social_blocks').doc('$peer:$uid'));
      final limitRef = db.collection('social_limits').doc(uid);
      final limit = await tx.get(limitRef);
      final now = this.now;
      if (blocked.exists || blockedBy.exists) {
        throw const SocialException('هذا الطلب غير متاح.');
      }
      if (old.exists &&
          (pending(old.data()!, now) ||
              (!challenge && old.data()!['status'] == 'accepted'))) {
        throw const SocialException('يوجد طلب قائم أو صداقة بالفعل.');
      }
      final previousAt = old.data()?['updatedAt'];
      if (previousAt is Timestamp &&
          now.difference(previousAt.toDate()).inSeconds < 30) {
        throw const SocialException(
            'انتظر قليلاً قبل إعادة الطلب لهذا اللاعب.');
      }
      final last =
          limit.data()?[challenge ? 'challengeSentAt' : 'friendSentAt'];
      if (last is Timestamp && now.difference(last.toDate()).inSeconds < 10) {
        throw const SocialException('انتظر قليلاً قبل إرسال طلب جديد.');
      }
      if (challenge) {
        final presence =
            await tx.get(db.collection('player_presence').doc(peer));
        final mine = await tx.get(db.collection('player_presence').doc(uid));
        final policy = await tx.get(db.collection('social_settings').doc(peer));
        final link = await tx.get(db.collection('social_links').doc(id));
        final ownLock =
            await tx.get(db.collection('social_reservations').doc(uid));
        final peerLock =
            await tx.get(db.collection('social_reservations').doc(peer));
        final allowed = policy.data()?['allowChallenges'] ?? 'everyone';
        if (!fresh(presence.data(), now) ||
            presence.data()?['state'] != 'available' ||
            !fresh(mine.data(), now) ||
            mine.data()?['state'] != 'available') {
          throw const SocialException('اللاعب غير متاح الآن.');
        }
        if (allowed == 'none' ||
            (allowed == 'friends' && link.data()?['status'] != 'accepted')) {
          throw const SocialException('إعدادات اللاعب لا تسمح بهذا التحدي.');
        }
        if (_locked(ownLock.data(), now) || _locked(peerLock.data(), now)) {
          throw const SocialException('أحد اللاعبين يستعد لمواجهة أخرى.');
        }
      }
      tx.set(
          limitRef,
          {
            challenge ? 'challengeSentAt' : 'friendSentAt':
                FieldValue.serverTimestamp()
          },
          SetOptions(merge: true));
      tx.set(ref, {
        'members': [uid, peer]..sort(),
        'fromUid': uid,
        'toUid': peer,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
            now.add(challenge ? invitationLifetime : const Duration(days: 7))),
        if (challenge) 'mode': 'duel',
      });
    });
  }

  static bool _locked(Map<String, dynamic>? data, DateTime now) =>
      data?['expiresAt'] is Timestamp &&
      (data!['expiresAt'] as Timestamp).toDate().isAfter(now);

  Future<void> respond(String uid, String id, String status,
      {required bool challenge}) async {
    await syncClock();
    final ref =
        db.collection(challenge ? 'social_challenges' : 'social_links').doc(id);
    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      final now = this.now;
      if (data == null || !(data['members'] as List).contains(uid)) {
        throw const SocialException('الطلب غير موجود.');
      }
      if (status != 'removed' && !pending(data, now)) {
        throw const SocialException('انتهت صلاحية الطلب.');
      }
      if ((status == 'accepted' || status == 'declined') &&
          data['toUid'] != uid) {
        throw const SocialException('القبول متاح لمستلم الطلب فقط.');
      }
      if ((status == 'cancelled' && data['fromUid'] != uid) ||
          (status == 'removed' &&
              (challenge || data['status'] != 'accepted')) ||
          !['accepted', 'declined', 'cancelled', 'removed'].contains(status)) {
        throw const SocialException('هذا الإجراء غير متاح لهذا الطلب.');
      }
      if (status == 'accepted') {
        final from = data['fromUid'] as String;
        final to = data['toUid'] as String;
        final a = await tx.get(db.collection('social_blocks').doc('$from:$to'));
        final b = await tx.get(db.collection('social_blocks').doc('$to:$from'));
        if (a.exists || b.exists) {
          throw const SocialException('هذا الطلب غير متاح.');
        }
      }
      if (challenge && status == 'accepted') {
        final from = data['fromUid'] as String;
        final aRef = db.collection('social_reservations').doc(from);
        final bRef = db.collection('social_reservations').doc(uid);
        final a = await tx.get(aRef);
        final b = await tx.get(bRef);
        final fromPresence =
            await tx.get(db.collection('player_presence').doc(from));
        final toPresence =
            await tx.get(db.collection('player_presence').doc(uid));
        if (_locked(a.data(), now) ||
            _locked(b.data(), now) ||
            !fresh(fromPresence.data(), now) ||
            !fresh(toPresence.data(), now) ||
            fromPresence.data()?['state'] != 'available' ||
            toPresence.data()?['state'] != 'available') {
          throw const SocialException('لم يعد أحد اللاعبين متاحًا.');
        }
        final expires = Timestamp.fromDate(now.add(const Duration(minutes: 2)));
        tx.set(aRef, {
          'challengeId': id,
          'acceptedAt': FieldValue.serverTimestamp(),
          'expiresAt': expires
        });
        tx.set(bRef, {
          'challengeId': id,
          'acceptedAt': FieldValue.serverTimestamp(),
          'expiresAt': expires
        });
      }
      tx.update(ref, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (challenge && status == 'accepted')
          'acceptedAt': FieldValue.serverTimestamp()
      });
    });
  }

  Future<void> block(String uid, String peer) async {
    pairId(uid, peer);
    final ref = db.collection('social_blocks').doc('$uid:$peer');
    await db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return;
      tx.set(ref, {
        'ownerUid': uid,
        'targetUid': peer,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> unblock(String uid, String peer) =>
      db.collection('social_blocks').doc('$uid:$peer').delete();
}

class SocialException implements Exception {
  const SocialException(this.message);
  final String message;
  @override
  String toString() => message;
}
