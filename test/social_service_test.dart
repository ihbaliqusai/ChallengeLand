import 'dart:async';
import 'package:challenge_land/models/social_player_activity.dart';
import 'package:challenge_land/services/social_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedProfiles extends SocialService {
  _DelayedProfiles({required super.firestore, required super.clock});
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> profile(String uid,
          {bool forceRefresh = false}) =>
      pending.future;
}

class _StakesBridge extends NativeBridgeService {
  final calls = <Map<String, dynamic>>[];
  String? failure;
  @override
  Future<Map<String, dynamic>> friendStakes(Map<String, dynamic> data) async {
    calls.add(data);
    if (failure != null) throw EconomyOperationException(failure!);
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late SocialService service;
  late DateTime now;
  setUp(() async {
    now = DateTime.now();
    db = FakeFirebaseFirestore(clock: Clock(() => now));
    service = SocialService(firestore: db, clock: () => now);
    for (final uid in ['alice', 'bob', 'carol']) {
      await db.collection('player_presence').doc(uid).set({
        'uid': uid,
        'state': 'available',
        'heartbeatAt': Timestamp.fromDate(now),
        'discoverable': true,
      });
    }
  });

  test(
      'paid invitations and acceptance use server escrow without client writes',
      () async {
    final bridge = _StakesBridge();
    final paid = SocialService(firestore: db, nativeBridge: bridge);
    for (final amount in SocialService.stakeAmounts) {
      await paid.sendStakedChallenge('alice', 'bob', amount);
      expect(bridge.calls.last, containsPair('stakeCoins', amount));
      expect(bridge.calls.last, containsPair('action', 'invite'));
      expect(bridge.calls.last, containsPair('peerUid', 'bob'));
      expect(bridge.calls.last, containsPair('gameplayVersion', 2));
    }
    expect(bridge.calls.map((c) => c['operationId']).toSet(), hasLength(7));
    await paid.respondStakedChallenge('alice:bob', 'accepted',
        expectedAmount: 50);
    expect(bridge.calls.last, containsPair('expectedAmount', 50));
    expect(bridge.calls.last, containsPair('status', 'accepted'));
    expect(bridge.calls.last, containsPair('gameplayVersion', 2));
    expect((await db.collection('social_challenges').get()).docs, isEmpty);
    expect((await db.collection('social_reservations').get()).docs, isEmpty);
  });

  test(
      'unsupported amounts fail before calling server and failures are visible',
      () async {
    final bridge = _StakesBridge();
    final paid = SocialService(firestore: db, nativeBridge: bridge);
    await expectLater(paid.sendStakedChallenge('alice', 'bob', 25),
        throwsA(isA<SocialException>()));
    expect(bridge.calls, isEmpty);
    bridge.failure = 'رصيدك لا يكفي';
    await expectLater(
        paid.sendStakedChallenge('alice', 'bob', 50),
        throwsA(isA<SocialException>()
            .having((error) => error.message, 'message', 'رصيدك لا يكفي')));
  });

  test(
      'paid invitations cannot be accepted through the free client transaction',
      () async {
    await db.doc('social_challenges/alice:bob').set({
      'members': ['alice', 'bob'],
      'fromUid': 'alice',
      'toUid': 'bob',
      'status': 'pending',
      'serverStake': true,
      'stakeCoins': 50,
      'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30))),
    });
    await expectLater(
        service.respond('bob', 'alice:bob', 'accepted', challenge: true),
        throwsA(isA<SocialException>()));
    expect(
        (await db.doc('social_challenges/alice:bob').get()).data()?['status'],
        'pending');
    expect((await db.collection('social_reservations').get()).docs, isEmpty);
  });

  test(
      'friend requests remain pending until recipient accepts, then survive a new service',
      () async {
    await service.send('alice', 'bob', challenge: false);
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'pending');
    await expectLater(
        service.respond('alice', 'alice:bob', 'accepted', challenge: false),
        throwsA(isA<SocialException>()));
    await service.respond('bob', 'alice:bob', 'accepted', challenge: false);
    final restored = SocialService(firestore: db, clock: () => now);
    expect((await restored.links('alice').first).docs.single.data()['status'],
        'accepted');
    await expectLater(restored.send('alice', 'bob', challenge: false),
        throwsA(isA<SocialException>()));
  });
  test('recipient cannot cancel sender request or remove a pending friendship',
      () async {
    await service.send('alice', 'bob', challenge: false);
    await expectLater(
        service.respond('bob', 'alice:bob', 'cancelled', challenge: false),
        throwsA(isA<SocialException>()));
    await expectLater(
        service.respond('alice', 'alice:bob', 'removed', challenge: false),
        throwsA(isA<SocialException>()));
    await service.respond('alice', 'alice:bob', 'cancelled', challenge: false);
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'cancelled');
  });
  test(
      'rate limits apply across different targets and paired cooldown outlives cancellation',
      () async {
    await service.send('alice', 'bob', challenge: false);
    await service.respond('alice', 'alice:bob', 'cancelled', challenge: false);
    await expectLater(service.send('alice', 'carol', challenge: false),
        throwsA(isA<SocialException>()));
    now = now.add(const Duration(seconds: 15));
    await expectLater(service.send('alice', 'bob', challenge: false),
        throwsA(isA<SocialException>()));
    await service.send('alice', 'carol', challenge: false);
  });
  test('blocks are idempotent and prevent requests in both directions',
      () async {
    await service.block('bob', 'alice');
    await service.block('bob', 'alice');
    await expectLater(service.send('alice', 'bob', challenge: false),
        throwsA(isA<SocialException>()));
    await expectLater(service.send('bob', 'alice', challenge: true),
        throwsA(isA<SocialException>()));
    await service.unblock('bob', 'alice');
    await service.send('alice', 'bob', challenge: false);
  });
  test('friends-only challenges require an accepted friendship', () async {
    await service.setSettings('bob', true, 'friends');
    await expectLater(service.send('alice', 'bob', challenge: true),
        throwsA(isA<SocialException>()));
    await service.send('alice', 'bob', challenge: false);
    await service.respond('bob', 'alice:bob', 'accepted', challenge: false);
    await service.send('alice', 'bob', challenge: true);
    expect(
        (await db.doc('social_challenges/alice:bob').get()).data()?['status'],
        'pending');
  });
  test('discoverable players accept direct challenges without a friendship',
      () async {
    await service.setSettings('bob', true, 'everyone');
    await service.send('alice', 'bob', challenge: true);
    expect((await db.doc('social_links/alice:bob').get()).exists, isFalse);
    expect(
        (await db.doc('social_challenges/alice:bob').get()).data()?['status'],
        'pending');
  });
  test('direct challenges still respect disabled invitations', () async {
    await service.setSettings('bob', true, 'none');
    await expectLater(service.send('alice', 'bob', challenge: true),
        throwsA(isA<SocialException>()));
    expect((await db.doc('social_challenges/alice:bob').get()).exists, isFalse);
  });
  test(
      'accepting a challenge reserves both players and prevents a second acceptance',
      () async {
    await service.send('alice', 'bob', challenge: true);
    await service.send('carol', 'bob', challenge: true);
    await service.respond('bob', 'alice:bob', 'accepted', challenge: true);
    for (final uid in ['alice', 'bob']) {
      final lock = (await db.doc('social_reservations/$uid').get()).data()!;
      expect(lock['challengeId'], 'alice:bob');
      expect((lock['expiresAt'] as Timestamp).toDate(),
          now.add(const Duration(minutes: 2)));
    }
    await expectLater(
        service.respond('bob', 'bob:carol', 'accepted', challenge: true),
        throwsA(isA<SocialException>()));
    expect(
        (await db.doc('social_challenges/bob:carol').get()).data()?['status'],
        'pending');
  });
  test('expired invitations and stale players cannot enter acceptance',
      () async {
    await service.send('alice', 'bob', challenge: true);
    now = now.add(const Duration(seconds: 30));
    await expectLater(
        service.respond('bob', 'alice:bob', 'accepted', challenge: true),
        throwsA(isA<SocialException>()));
    expect((await db.doc('social_reservations/bob').get()).exists, isFalse);
    now = now.add(const Duration(seconds: 46));
    await expectLater(service.send('carol', 'bob', challenge: true),
        throwsA(isA<SocialException>()));
  });
  test('discovery suggests available opponents near the caller trophy count',
      () async {
    for (final entry in {'alice': 100, 'bob': 140, 'carol': 110}.entries) {
      await db
          .doc('public_profiles/${entry.key}')
          .set({'trophies': entry.value, 'username': entry.key});
    }
    final ranked = await service
        .suggestedPlayers(112)
        .firstWhere((docs) => docs.first.id == 'carol');
    expect(ranked.map((d) => d.id), ['carol', 'alice', 'bob']);
    await db.doc('player_presence/carol').update({'state': 'in_match'});
    final updated = await service
        .suggestedPlayers(112)
        .firstWhere((docs) => docs.last.id == 'carol');
    expect(updated.map((d) => d.id), ['alice', 'bob', 'carol']);
  });
  test('discovery emits presence without waiting for unavailable profile reads',
      () async {
    final delayed = _DelayedProfiles(firestore: db, clock: () => now);
    try {
      final first = await delayed
          .suggestedPlayers(100)
          .first
          .timeout(const Duration(seconds: 1));
      expect(first.map((d) => d.id).toSet(), {'alice', 'bob', 'carol'});
    } finally {
      delayed.pending.complete({});
    }
  });
  test('recent discovery includes today, excludes hidden and older players',
      () async {
    now = DateTime.utc(2026, 10, 12, 12);
    final feedDb = FakeFirebaseFirestore(clock: Clock(() => now));
    final feed = SocialService(firestore: feedDb, clock: () => now);
    for (final entry in {
      'online': const Duration(seconds: 1),
      'hour': const Duration(minutes: 30),
      'six': const Duration(hours: 3),
      'today': const Duration(hours: 8),
      'yesterday': const Duration(hours: 25),
      'hidden': Duration.zero,
    }.entries) {
      await feedDb.doc('player_presence/${entry.key}').set({
        'uid': entry.key,
        'discoverable': entry.key != 'hidden',
        'state': entry.key == 'online' ? 'available' : 'away',
        'heartbeatAt': Timestamp.fromDate(now.subtract(entry.value)),
      });
    }
    final documents = (await feed.recentPlayers().first).docs;
    expect(documents.map((doc) => doc.id), ['online', 'hour', 'six', 'today']);
  });
  test('recent discovery crosses midnight and keeps its stream stable',
      () async {
    now = DateTime.utc(2026, 10, 12, 0, 30);
    final feedDb = FakeFirebaseFirestore(clock: Clock(() => now));
    final feed = SocialService(firestore: feedDb, clock: () => now);
    for (final entry in {
      'hour': const Duration(minutes: 45),
      'six': const Duration(hours: 3),
      'old': const Duration(hours: 7),
    }.entries) {
      await feedDb.doc('player_presence/${entry.key}').set({
        'discoverable': true,
        'state': 'away',
        'heartbeatAt': Timestamp.fromDate(now.subtract(entry.value)),
      });
    }
    final stream = feed.recentPlayers();
    expect((await stream.first).docs.map((doc) => doc.id), ['hour', 'six']);
    now = now.add(const Duration(hours: 7));
    expect(identical(feed.recentPlayers(), stream), isTrue);
    now = now.add(const Duration(days: 1));
    expect(identical(feed.recentPlayers(), stream), isFalse);
    final nextDay = feed.recentPlayers();
    feed.refreshReads();
    expect(identical(feed.recentPlayers(), nextDay), isFalse);
  });
  test('recent discovery bounds reads and prioritizes the newest presence',
      () async {
    now = DateTime.utc(2026, 10, 12, 12);
    final feedDb = FakeFirebaseFirestore(clock: Clock(() => now));
    final feed = SocialService(firestore: feedDb, clock: () => now);
    for (var index = 0; index < 125; index++) {
      await feedDb.doc('player_presence/player-$index').set({
        'discoverable': true,
        'state': 'available',
        'heartbeatAt':
            Timestamp.fromDate(now.subtract(Duration(seconds: index))),
      });
    }
    final documents = (await feed.recentPlayers().first).docs;
    expect(documents, hasLength(120));
    expect(documents.first.id, 'player-0');
    expect(documents.last.id, 'player-119');
  });
  test('server clock correction keeps previous-day recent players discoverable',
      () async {
    now = DateTime.utc(2026, 10, 12, 0, 30);
    final feedDb = FakeFirebaseFirestore(clock: Clock(() => now));
    final feed = SocialService(firestore: feedDb, clock: () => now);
    await feedDb.doc('player_presence/recent').set({
      'discoverable': true,
      'state': 'away',
      'heartbeatAt': Timestamp.fromDate(DateTime.utc(2026, 10, 11, 18, 20)),
    });
    final stream = feed.recentPlayers();
    final initial = (await stream.first).docs.single;
    expect(SocialActivity.classify(initial.data(), now), isNull);
    now = DateTime.utc(2026, 10, 12, 0, 10);
    expect(identical(feed.recentPlayers(), stream), isTrue);
    final corrected = (await feed.recentPlayers().first).docs.single;
    expect(corrected.id, 'recent');
    expect(SocialActivity.classify(corrected.data(), now),
        SocialPlayerActivity.lastSixHours);
  });
}
