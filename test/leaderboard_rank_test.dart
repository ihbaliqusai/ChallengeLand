import 'dart:async';

import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LeaderboardService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = LeaderboardService(firestore: firestore);
  });

  Future<void> player(String uid, int trophies, {int level = 1}) =>
      firestore.doc('public_profiles/$uid').set({
        'uid': uid,
        'username': uid,
        'trophies': trophies,
        'level': level,
      });

  test('the published trophy ranking replaces a player level', () async {
    await player('leader', 500, level: 2);
    await player('me', 300, level: 99);
    await player('third', 100, level: 200);
    expect(await service.loadWorldRank(uid: 'leader'), 1);
    expect(await service.loadWorldRank(uid: 'me'), 2);
    expect(await service.loadWorldRank(uid: 'third'), 3);
  });

  test('tied ranks follow the same descending uid order as the world board',
      () async {
    await player('first', 500);
    for (final uid in ['a', 'b', 'z']) {
      await player(uid, 300);
    }
    await player('last', 20);
    final board = await service.load(scope: LeaderboardScope.world, uid: 'b');
    expect(board.map((entry) => entry.uid), ['first', 'z', 'b', 'a', 'last']);
    for (var index = 0; index < board.length; index++) {
      expect(await service.loadWorldRank(uid: board[index].uid), index + 1);
    }
  });

  test('rank is exact beyond the top 200 player window', () async {
    for (var index = 0; index < 230; index++) {
      await player('ahead_$index', 1000 - index);
    }
    await player('me', 1);
    final board = await service.load(scope: LeaderboardScope.world, uid: 'me');
    expect(board.length, LeaderboardService.maxPlayers);
    expect(board.any((entry) => entry.uid == 'me'), isFalse);
    expect(await service.loadWorldRank(uid: 'me'), 231);
  });

  test('unpublished and nonpositive profiles are unranked', () async {
    await player('zero', 0, level: 99);
    await player('negative', -5);
    await firestore.doc('public_profiles/no_score').set({'level': 500});
    for (final uid in [
      'missing',
      'zero',
      'negative',
      'no_score',
      '',
      'bad/id'
    ]) {
      expect(await service.loadWorldRank(uid: uid), isNull);
    }
  });

  test('zero and negative trophy totals do not count ahead of ranked players',
      () async {
    await player('zero', 0);
    await player('negative', -10);
    await player('me', 10);
    expect(await service.loadWorldRank(uid: 'me'), 1);
  });

  test('a profile read error is not represented by an invented rank', () async {
    final denied = FakeFirebaseFirestore(securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /public_profiles/{uid} { allow read: if false; }
        }
      }
    ''');
    await expectLater(
        LeaderboardService(firestore: denied).loadWorldRank(uid: 'me'),
        throwsA(isA<Exception>().having(
            (error) => error.toString(), 'reason', contains('not allowed'))));
  });

  test('a rank count error propagates after a successful profile read',
      () async {
    final denied = FakeFirebaseFirestore(securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /public_profiles/{uid} {
            allow write: if true;
            allow read: if uid == 'me';
          }
        }
      }
    ''');
    await denied.doc('public_profiles/me').set({'trophies': 100});
    await denied.doc('public_profiles/higher').set({'trophies': 200});
    await expectLater(
        LeaderboardService(firestore: denied).loadWorldRank(uid: 'me'),
        throwsA(isA<Exception>().having(
            (error) => error.toString(), 'reason', contains('not allowed'))));
  });

  test('watch updates rank after published score changes and removal',
      () async {
    await player('other', 200);
    await player('me', 100);
    final iterator = StreamIterator(service.watchWorldRank(uid: 'me'));
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, 2);
    await firestore.doc('public_profiles/me').update({'trophies': 300});
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, 1);
    await firestore.doc('public_profiles/me').delete();
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isNull);
  });

  test('a rank watcher starts unranked until a profile is published', () async {
    await player('other', 200);
    final iterator = StreamIterator(service.watchWorldRank(uid: 'me'));
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isNull);
    await player('me', 100);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, 2);
  });

  test('canceled rank watchers stop delivering updates', () async {
    await player('me', 100);
    final ranks = <int?>[];
    final first = Completer<void>();
    final subscription = service.watchWorldRank(uid: 'me').listen((rank) {
      ranks.add(rank);
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    expect(ranks, [1]);
    await subscription.cancel();
    await player('higher', 300);
    await firestore.doc('public_profiles/me').update({'trophies': 200});
    await Future<void>.delayed(Duration.zero);
    expect(ranks, [1]);
  });
}
