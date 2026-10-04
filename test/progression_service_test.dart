import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/models/player_profile.dart';
import 'package:challenge_land/services/progression_service.dart';
import 'package:challenge_land/services/profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TransactionalFirestore firestore;
  late ProgressionService service;
  const identity = <String, dynamic>{
    'username': 'Player',
    'photoUrl': null,
    'friendCode': 'PLAYER123',
  };

  Future<void> seed(Map<String, int> stats) =>
      firestore.doc('users/player').set({
        ...ProgressionService.privatePayload(
            ProgressionService.normalize(stats)),
        'coins': 50,
        'email': 'private@example.test',
      });

  Future<Map<String, int>> sync(String device, Map<String, int> contributions,
          {Map<String, int>? native}) =>
      service.synchronize(
        uid: 'player',
        deviceId: device,
        contributions: contributions,
        nativeStats: native ?? contributions,
        identity: identity,
      );

  setUp(() {
    firestore = _TransactionalFirestore();
    service = ProgressionService(firestore: firestore);
  });

  test('lost commit response can be retried without duplicating rewards',
      () async {
    await seed({'xp': 1000, 'trophies': 100, 'gamesPlayed': 5});
    firestore.loseNextResponse = true;
    final contributions = {
      'xp': 180,
      'trophies': -8,
      'trophiesLost': 8,
      'gamesPlayed': 1,
      'losses': 1,
    };
    await expectLater(
        sync('one', contributions), throwsA(isA<FirebaseException>()));
    final retry = await ProgressionService(firestore: firestore).synchronize(
      uid: 'player',
      deviceId: 'one',
      nativeStats: contributions,
      contributions: contributions,
      identity: identity,
    );
    expect(retry['xp'], 1180);
    expect(retry['trophies'], 92);
    expect(retry['gamesPlayed'], 6);
    expect(retry['losses'], 1);
    final checkpoint =
        (await firestore.doc('users/player/progressionDevices/one').get())
            .data()!;
    expect(checkpoint['contributions']['trophies'], -8);
    expect((await firestore.doc('public_profiles/player').get()).data()!['xp'],
        1180);
  });

  test('Firestore callback retries stage one atomic account publication',
      () async {
    await seed({'xp': 100});
    firestore.retryNextCallback = true;
    final totals = await sync('one', {'xp': 90, 'gamesPlayed': 1, 'wins': 1});
    expect(totals['xp'], 190);
    expect(totals['wins'], 1);
    expect(firestore.retriedCallbacks, 1);
    final private = (await firestore.doc('users/player').get()).data()!;
    final public =
        (await firestore.doc('public_profiles/player').get()).data()!;
    expect(private['xp'], public['xp']);
    expect(private['coins'], 50);
    expect(private['email'], 'private@example.test');
    expect(public.containsKey('email'), isFalse);
  });

  test('two devices add only independent contributions to restored totals',
      () async {
    await seed({'xp': 1000, 'gamesPlayed': 5, 'trophies': 80});
    await sync('one', {'xp': 200, 'gamesPlayed': 1, 'wins': 1, 'trophies': 20},
        native: {'xp': 1200, 'gamesPlayed': 6, 'trophies': 100});
    final second = await sync('two',
        {'xp': 300, 'gamesPlayed': 2, 'draws': 1, 'losses': 1, 'trophies': -10},
        native: {'xp': 1300, 'gamesPlayed': 7, 'trophies': 70});
    expect(second['xp'], 1500);
    expect(second['gamesPlayed'], 8);
    expect(second['trophies'], 90);
    final restored = await sync('three', {}, native: {
      'xp': 1500,
      'gamesPlayed': 8,
      'trophies': 90,
    });
    expect(restored['xp'], 1500);
    expect(restored['gamesPlayed'], 8);
    expect(restored['trophies'], 90);
    final later = await sync(
        'one', {'xp': 260, 'gamesPlayed': 2, 'wins': 2, 'trophies': 42},
        native: {'xp': 1560, 'gamesPlayed': 9, 'trophies': 112});
    expect(later['xp'], 1560);
    expect(later['gamesPlayed'], 9);
    expect(later['trophies'], 112);
  });

  test('legacy maxima migrate once without importing another device totals',
      () async {
    await firestore.doc('users/player').set({
      'xp': 500,
      'trophies': 1000,
      'totalMatches': 10,
      'lastKnownWins': 4,
    });
    final imported = await sync('old', {
      'xp': 200,
      'gamesPlayed': 1
    }, native: {
      'xp': 800,
      'gamesPlayed': 12,
      'wins': 5,
      'trophies': 900,
      'mode_offline_games': 2,
    });
    expect(imported['xp'], 800);
    expect(imported['gamesPlayed'], 12);
    expect(imported['trophies'], 1000);
    expect(imported['mode_offline_games'], 2);
    final continued = await sync('old', {'xp': 250, 'gamesPlayed': 2},
        native: {'xp': 850, 'gamesPlayed': 13});
    expect(continued['xp'], 850);
    expect(continued['gamesPlayed'], 13);
    final other = await sync('fresh', {'xp': 30},
        native: {'xp': 99999, 'gamesPlayed': 999});
    expect(other['xp'], 880);
    expect(other['gamesPlayed'], 13);
  });

  test('mode outcomes accumulate independently on each installation', () async {
    await seed({'mode_battle_games': 3, 'mode_battle_wins': 2});
    await sync('one', {
      'mode_battle_games': 1,
      'mode_battle_losses': 1,
      'mode_campaign_games': 2,
      'mode_campaign_wins': 1
    });
    await sync('two', {
      'mode_battle_games': 2,
      'mode_battle_wins': 1,
      'mode_battle_draws': 1,
      'mode_survival_abandoned': 1
    });
    final totals = await sync('one', {
      'mode_battle_games': 1,
      'mode_battle_losses': 1,
      'mode_campaign_games': 2,
      'mode_campaign_wins': 1
    });
    expect(totals['mode_battle_games'], 6);
    expect(totals['mode_battle_wins'], 3);
    expect(totals['mode_battle_losses'], 1);
    expect(totals['mode_battle_draws'], 1);
    expect(totals['mode_campaign_games'], 2);
    expect(totals['mode_survival_abandoned'], 1);
  });

  test('trophy losses lower current trophies and preserve best trophies',
      () async {
    await seed({'trophies': 40, 'bestTrophies': 60});
    final loss = await sync('one', {'trophies': -20, 'trophiesLost': 20});
    expect(loss['trophies'], 20);
    expect(loss['bestTrophies'], 60);
    final win = await sync(
        'one', {'trophies': 15, 'trophiesLost': 20, 'trophiesEarned': 35});
    expect(win['trophies'], 55);
    expect(win['trophiesLost'], 20);
    expect(win['trophiesEarned'], 35);
    expect(win['bestTrophies'], 60);
  });

  test('older captures cannot roll back acknowledgements or replay rewards',
      () async {
    await seed({'xp': 100, 'trophies': 100});
    await sync('one',
        {'xp': 100, 'gamesPlayed': 2, 'trophies': -20, 'trophiesLost': 20});
    final older = await sync(
        'one', {'xp': 50, 'gamesPlayed': 1, 'trophies': 10, 'trophiesLost': 0});
    expect(older['xp'], 200);
    expect(older['trophies'], 80);
    final replay = await sync('one',
        {'xp': 100, 'gamesPlayed': 2, 'trophies': -20, 'trophiesLost': 20});
    expect(replay['xp'], 200);
    expect(replay['trophies'], 80);
  });

  test(
      'campaign receipts and native XP share one total without hydration credit',
      () async {
    await seed({'xp': 1000, 'correctAnswers': 20});
    await sync('one', {'xp': 60, 'correctAnswers': 3});
    await firestore.doc('users/player/campaignRewardClaims/stage').set({
      'uid': 'player',
      'xp': 240,
      'xpClaimed': false,
      'currencyClaimed': true,
      'status': 'pending',
    });
    final granted = await service.grantCampaignXp(
        uid: 'player', claimId: 'stage', identity: identity);
    expect(granted['xp'], 1300);
    expect(granted['level'], PlayerRank.levelForXp(1300));
    final hydrated = await sync('one', {'xp': 60, 'correctAnswers': 3},
        native: {'xp': 1300, 'correctAnswers': 23});
    expect(hydrated['xp'], 1300);
    final replay = await service.grantCampaignXp(
        uid: 'player', claimId: 'stage', identity: identity);
    expect(replay['xp'], 1300);
    final freshXp = await sync('one', {'xp': 80, 'correctAnswers': 4},
        native: {'xp': 1320, 'correctAnswers': 24});
    expect(freshXp['xp'], 1320);
    final claim =
        (await firestore.doc('users/player/campaignRewardClaims/stage').get())
            .data()!;
    expect(claim['xpClaimed'], isTrue);
    expect(claim['status'], 'claimed');
    expect((await firestore.doc('public_profiles/player').get()).data()!['xp'],
        1320);
  });

  test('campaign commit response loss remains idempotent across instances',
      () async {
    await seed({'xp': 100});
    await firestore.doc('users/player/campaignRewardClaims/stage').set({
      'uid': 'player',
      'xp': 200,
      'xpClaimed': false,
      'currencyClaimed': false,
      'status': 'pending',
    });
    firestore.loseNextResponse = true;
    await expectLater(
        service.grantCampaignXp(
            uid: 'player', claimId: 'stage', identity: identity),
        throwsA(isA<FirebaseException>()));
    final replay = await ProgressionService(firestore: firestore)
        .grantCampaignXp(uid: 'player', claimId: 'stage', identity: identity);
    expect(replay['xp'], 300);
    expect((await firestore.doc('public_profiles/player').get()).data()!['xp'],
        300);
    expect(
        (await firestore.doc('users/player/campaignRewardClaims/stage').get())
            .data()!['status'],
        'pending');
  });

  test('invalid and missing campaign claims leave all totals unchanged',
      () async {
    await seed({'xp': 100});
    await expectLater(
        service.grantCampaignXp(
            uid: 'player', claimId: 'missing', identity: identity),
        throwsStateError);
    for (final invalid in [-1, '100', 2147483648]) {
      await firestore.doc('users/player/campaignRewardClaims/invalid').set({
        'uid': 'player',
        'xp': invalid,
        'xpClaimed': false,
      });
      await expectLater(
          service.grantCampaignXp(
              uid: 'player', claimId: 'invalid', identity: identity),
          throwsStateError);
    }
    expect((await firestore.doc('users/player').get()).data()!['xp'], 100);
    expect(
        (await firestore.doc('public_profiles/player').get()).exists, isFalse);
  });

  test('native integer limits and public identity filtering remain consistent',
      () async {
    await seed({'xp': ProgressionService.maxValue - 5, 'trophies': 2});
    final totals = await sync('one', {
      'xp': 50,
      'trophies': -20,
      'correctAnswers': 9,
      'wrongAnswers': 1,
      'gamesPlayed': 2,
      'wins': 1
    });
    expect(totals['xp'], ProgressionService.maxValue);
    expect(totals['trophies'], 0);
    expect(totals['accuracy'], 90);
    expect(totals['winPercent'], 50);
    final public = ProgressionService.publicPayload('player', totals, {
      ...identity,
      'uid': 'attacker',
      'xp': -999,
      'email': 'private',
      'admin': true,
    });
    expect(public['uid'], 'player');
    expect(public['xp'], ProgressionService.maxValue);
    expect(public.containsKey('email'), isFalse);
    expect(public.containsKey('admin'), isFalse);
    final profile = PlayerProfile.fromMap(public);
    expect(profile.xp, totals['xp']);
    expect(profile.level, totals['level']);
    expect(profile.trophies, totals['trophies']);
    expect(profile.friendCode, 'PLAYER123');
  });

  test('invalid account and device paths fail before creating documents',
      () async {
    for (final invalid in ['', ' ', '/', '.', '..', 'users/player']) {
      await expectLater(
          service.synchronize(
              uid: invalid,
              deviceId: 'one',
              nativeStats: {},
              contributions: {},
              identity: identity),
          throwsArgumentError);
      await expectLater(
          service.synchronize(
              uid: 'player',
              deviceId: invalid,
              nativeStats: {},
              contributions: {},
              identity: identity),
          throwsArgumentError);
    }
    expect((await firestore.collection('users').get()).docs, isEmpty);
  });

  test('level-only legacy profiles preserve the XP floor on a fresh device',
      () async {
    await firestore.doc('users/player').set({'level': 30, 'trophies': 750});
    final restored = await sync('fresh', {}, native: {});
    expect(restored['level'], 30);
    expect(restored['xp'], PlayerRank.xpForLevel(30));
    expect(restored['trophies'], 750);
  });

  test('public profile fetch and stream show committed account progression',
      () async {
    await seed({'xp': 100, 'trophies': 60});
    await sync('one', {}, native: {'xp': 100, 'trophies': 60});
    final profiles = ProfileService(firestore: firestore);
    final fetched = await profiles.fetchProfile('player');
    expect(fetched!.uid, 'player');
    expect(fetched.xp, 100);
    expect(fetched.friendCode, 'PLAYER123');
    final updated = profiles
        .watchProfile('player')
        .firstWhere((profile) => profile.xp == 300);
    await sync('one', {
      'xp': 200,
      'gamesPlayed': 1,
      'wins': 1,
      'correctAnswers': 8,
      'wrongAnswers': 2,
      'trophies': 22
    });
    final observed = await updated;
    expect(observed.level, PlayerRank.levelForXp(300));
    expect(observed.trophies, 82);
    expect(observed.wins, 1);
    expect(observed.accuracy, 80);
    expect(observed.email, isEmpty);
    final ranking = await firestore
        .collection('public_profiles')
        .orderBy('trophies', descending: true)
        .get();
    expect(ranking.docs.single.data()['trophies'], observed.trophies);
  });

  test('legacy profile copies derive XP and rank consistently from totalScore',
      () {
    final profile = PlayerProfile.empty().copyWith(
      totalScore: 500,
      totalMatches: 2,
      wins: 1,
      trophies: 50,
      correctAnswers: 8,
      wrongAnswers: 2,
    );
    expect(profile.xp, 500);
    expect(profile.level, PlayerRank.levelForXp(500));
    expect(profile.bestTrophies, 50);
    expect(profile.accuracy, 80);
    expect(profile.winPercent, 50);
    expect(PlayerProfile.fromMap(profile.toMap()).xp, 500);
    final advanced = profile.copyWith(xp: 1000, trophies: 40);
    expect(advanced.totalScore, 1000);
    expect(advanced.level, PlayerRank.levelForXp(1000));
    expect(advanced.bestTrophies, 50);
  });
}

/// The package's dummy Transaction drops merge options and writes immediately.
/// Stage writes in a batch so tests exercise callback retry/abort and lost
/// responses after a complete commit, preserving the real transaction contract.
class _TransactionalFirestore extends FakeFirebaseFirestore {
  bool loseNextResponse = false;
  bool retryNextCallback = false;
  int retriedCallbacks = 0;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (retryNextCallback) {
      retryNextCallback = false;
      await transactionHandler(_StagedTransaction(batch()));
      retriedCallbacks++;
    }
    final transaction = _StagedTransaction(batch());
    final result = await transactionHandler(transaction);
    await transaction.batch.commit();
    if (loseNextResponse) {
      loseNextResponse = false;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return result;
  }
}

class _StagedTransaction implements Transaction {
  _StagedTransaction(this.batch);
  final WriteBatch batch;
  bool _writing = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(DocumentReference<T> ref) {
    if (_writing) throw StateError('Transaction reads must precede writes');
    return ref.get();
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    _writing = true;
    batch.set(ref, data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    _writing = true;
    batch.update(ref, data);
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    _writing = true;
    batch.delete(ref);
    return this;
  }
}
