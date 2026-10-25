import 'dart:async';

import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LeaderboardService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = LeaderboardService(firestore: db);
  });

  test('legacy profiles resolve an email prefix after empty or generic names',
      () {
    final profile = LeaderboardPlayer.fromMap({
      'username': 'Guest',
      'displayName': ' ',
      'email': 'legacy-player@example.test',
    }, uid: 'legacy');
    expect(profile.username, 'legacy-player');
  });

  Future<void> player(String uid, int trophies, {String? country}) =>
      db.doc('public_profiles/$uid').set({
        'uid': uid,
        'username': uid,
        'trophies': trophies,
        if (country != null) 'countryCode': country,
      });

  Future<void> link(String uid, String status) =>
      db.doc('social_links/me:$uid').set({
        'members': ['me', uid],
        'status': status,
      });

  Future<List<LeaderboardPlayer>> nextMatching(
    StreamIterator<List<LeaderboardPlayer>> iterator,
    bool Function(List<LeaderboardPlayer>) matches,
  ) async {
    while (await iterator.moveNext().timeout(const Duration(seconds: 3))) {
      if (matches(iterator.current)) return iterator.current;
    }
    throw StateError('Leaderboard stream ended before the expected update');
  }

  test('warm boards restore across service instances and cannot be mutated',
      () async {
    await player('leader', 100, country: 'JO');
    expect(service.cached(scope: LeaderboardScope.world, uid: 'me'), isNull);
    final loaded = await service.load(scope: LeaderboardScope.world, uid: 'me');
    final reopened = LeaderboardService(firestore: db);
    final cached = reopened.cached(scope: LeaderboardScope.world, uid: 'me');
    expect(cached, same(loaded));
    expect(cached!.single.uid, 'leader');
    expect(() => cached.clear(), throwsUnsupportedError);
  });

  test(
      'cached boards isolate accounts, countries, scopes and database instances',
      () async {
    await player('leader', 100, country: 'JO');
    await service.load(
        scope: LeaderboardScope.country, uid: 'me', countryCode: 'JO');
    expect(
        service.cached(
            scope: LeaderboardScope.country, uid: 'me', countryCode: 'jo'),
        isNotNull);
    expect(
        service.cached(
            scope: LeaderboardScope.country, uid: 'other', countryCode: 'JO'),
        isNull);
    expect(
        service.cached(
            scope: LeaderboardScope.country, uid: 'me', countryCode: 'SA'),
        isNull);
    expect(service.cached(scope: LeaderboardScope.world, uid: 'me'), isNull);
    expect(
        LeaderboardService(firestore: FakeFirebaseFirestore()).cached(
            scope: LeaderboardScope.country, uid: 'me', countryCode: 'JO'),
        isNull);
    final empty = await service.load(
        scope: LeaderboardScope.country, uid: 'me', countryCode: 'SA');
    expect(empty, isEmpty);
    expect(
        service.cached(
            scope: LeaderboardScope.country, uid: 'me', countryCode: 'SA'),
        isEmpty);
  });

  test('query memory stays bounded and recently read boards remain available',
      () async {
    await service.load(scope: LeaderboardScope.world, uid: 'first');
    await service.load(scope: LeaderboardScope.world, uid: 'keep');
    for (var index = 0; index < 6; index++) {
      await service.load(scope: LeaderboardScope.world, uid: 'account-$index');
    }
    expect(service.cached(scope: LeaderboardScope.world, uid: 'keep'), isEmpty);
    await service.load(scope: LeaderboardScope.world, uid: 'latest');
    expect(service.cached(scope: LeaderboardScope.world, uid: 'first'), isNull);
    expect(service.cached(scope: LeaderboardScope.world, uid: 'keep'), isEmpty);
  });

  test('country memory follows loaded and saved choices for each account',
      () async {
    await player('me', 10, country: 'JO');
    expect(service.cachedCountry('me'), isNull);
    await service.loadCountry('me');
    expect(LeaderboardService(firestore: db).cachedCountry('me'), 'JO');
    await service.saveCountry('me', 'SA');
    expect(service.cachedCountry('me'), 'SA');
    expect(service.cachedCountry('other'), isNull);
  });

  test(
      'world watch delivers totals and stops changing cached results on cancel',
      () async {
    await player('a', 10);
    await player('b', 20);
    final iterator =
        StreamIterator(service.watch(scope: LeaderboardScope.world, uid: 'me'));
    addTearDown(iterator.cancel);
    final initial =
        await nextMatching(iterator, (players) => players.length == 2);
    expect(initial.map((player) => player.uid), ['b', 'a']);
    await db.doc('public_profiles/a').update({'trophies': 30});
    final updated = await nextMatching(iterator,
        (players) => players.first.uid == 'a' && players.first.trophies == 30);
    expect(updated.map((player) => player.uid), ['a', 'b']);
    expect(
        service
            .cached(scope: LeaderboardScope.world, uid: 'me')!
            .first
            .trophies,
        30);
    await iterator.cancel();
    await db.doc('public_profiles/a').update({'trophies': 40});
    await Future<void>.delayed(Duration.zero);
    expect(
        service
            .cached(scope: LeaderboardScope.world, uid: 'me')!
            .first
            .trophies,
        30);
  });

  test('friend watch reacts to accepted links, blocks and score changes',
      () async {
    await player('me', 20);
    await player('friend', 10);
    await player('pending', 1000);
    await link('friend', 'accepted');
    await link('pending', 'pending');
    final iterator = StreamIterator(
        service.watch(scope: LeaderboardScope.friends, uid: 'me'));
    addTearDown(iterator.cancel);
    final initial =
        await nextMatching(iterator, (players) => players.length == 2);
    expect(initial.map((player) => player.uid), ['me', 'friend']);
    await db.doc('public_profiles/friend').update({'trophies': 30});
    await nextMatching(iterator, (players) => players.first.uid == 'friend');
    await db
        .doc('social_blocks/me:friend')
        .set({'ownerUid': 'me', 'targetUid': 'friend'});
    final blocked = await nextMatching(iterator,
        (players) => players.length == 1 && players.single.uid == 'me');
    expect(blocked.single.uid, 'me');
    await link('pending', 'accepted');
    final accepted = await nextMatching(iterator,
        (players) => players.length == 2 && players.first.uid == 'pending');
    expect(accepted.map((player) => player.uid), ['pending', 'me']);
    await link('pending', 'removed');
    await nextMatching(iterator, (players) => players.length == 1);
    await db.doc('social_blocks/me:friend').delete();
    final unblocked = await nextMatching(iterator,
        (players) => players.length == 2 && players.first.uid == 'friend');
    expect(unblocked.map((player) => player.uid), ['friend', 'me']);
    await iterator.cancel();
    await db.doc('public_profiles/friend').update({'trophies': 400});
    await Future<void>.delayed(Duration.zero);
    expect(
        service
            .cached(scope: LeaderboardScope.friends, uid: 'me')!
            .first
            .trophies,
        30);
  });

  test('friend watch publishes full membership across all profile batches',
      () async {
    await player('me', 1);
    for (var index = 0; index < 65; index++) {
      final id = 'friend-$index';
      await player(id, index + 2);
      await link(id, 'accepted');
    }
    final iterator = StreamIterator(
        service.watch(scope: LeaderboardScope.friends, uid: 'me'));
    addTearDown(iterator.cancel);
    expect(
        await iterator.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    expect(iterator.current, hasLength(66));
    expect(iterator.current.first.uid, 'friend-64');
    expect(iterator.current.last.uid, 'me');
  });

  test('world ranks positive trophy totals with stable descending ID ties',
      () async {
    await player('a', 100);
    await player('b', 100);
    await player('first', 200);
    await player('zero', 0);
    final result = await service.load(scope: LeaderboardScope.world);
    expect(result.map((p) => p.uid), ['first', 'b', 'a']);
  });

  test('country loads its own top players outside the global window', () async {
    for (var i = 0; i < 201; i++) {
      await player('global-$i', 1000 + i, country: 'US');
    }
    await player('jordan-a', 20, country: 'JO');
    await player('jordan-b', 40, country: 'JO');
    final world = await service.load(scope: LeaderboardScope.world);
    expect(world, hasLength(200));
    expect(world.any((p) => p.countryCode == 'JO'), isFalse);
    final country =
        await service.load(scope: LeaderboardScope.country, countryCode: 'jo');
    expect(country.map((p) => p.uid), ['jordan-b', 'jordan-a']);
  });

  test('missing country and missing friend account return no fabricated board',
      () async {
    await player('global', 500);
    expect(await service.load(scope: LeaderboardScope.country), isEmpty);
    expect(await service.load(scope: LeaderboardScope.friends), isEmpty);
    expect(await service.loadCountry('missing'), isNull);
  });

  test('friends includes accepted peers and self, omitting blocked and pending',
      () async {
    await player('me', 5);
    await player('friend', 15);
    await player('new-friend', 0);
    await player('pending', 1000);
    await player('removed', 900);
    await player('blocked', 800);
    await player('stranger', 5000);
    await link('friend', 'accepted');
    await link('new-friend', 'accepted');
    await link('pending', 'pending');
    await link('removed', 'removed');
    await link('blocked', 'accepted');
    await db.doc('social_blocks/me:blocked').set({
      'ownerUid': 'me',
      'targetUid': 'blocked',
    });
    final result =
        await service.load(scope: LeaderboardScope.friends, uid: 'me');
    expect(result.map((p) => p.uid), ['friend', 'me', 'new-friend']);
  });

  test('friends batches profile reads and sorts before applying top 200',
      () async {
    await player('me', 0);
    for (var i = 0; i < 205; i++) {
      final id = 'friend-${i.toString().padLeft(3, '0')}';
      await player(id, i + 1);
      await link(id, 'accepted');
    }
    final result =
        await service.load(scope: LeaderboardScope.friends, uid: 'me');
    expect(result, hasLength(200));
    expect(result.first.uid, 'friend-204');
    expect(result.last.uid, 'friend-005');
  });

  test('country save normalizes identity without replacing score fields',
      () async {
    await player('me', 91);
    await service.saveCountry('me', ' jo ');
    expect(await service.loadCountry('me'), 'JO');
    final saved = (await db.doc('public_profiles/me').get()).data()!;
    expect(saved['trophies'], 91);
    expect(saved['username'], 'me');
    expect(saved['countryCode'], 'JO');
    await expectLater(
        service.saveCountry('me', 'Jordan'), throwsA(isA<ArgumentError>()));
    await expectLater(
        service.saveCountry('', 'JO'), throwsA(isA<ArgumentError>()));
  });

  test('country save can create an identity before scores are available',
      () async {
    await service.saveCountry('new-player', 'TR');
    expect((await db.doc('public_profiles/new-player').get()).data(), {
      'uid': 'new-player',
      'countryCode': 'TR',
    });
  });
}
