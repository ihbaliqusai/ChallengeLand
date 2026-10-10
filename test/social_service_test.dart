import 'dart:async';
import 'package:challenge_land/services/social_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedProfiles extends SocialService {
  _DelayedProfiles({required super.firestore, required super.clock});
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> profile(String uid) => pending.future;
}

void main() {
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
}
