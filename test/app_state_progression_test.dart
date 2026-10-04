import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/services/auth_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/progression_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _AccountUser implements User {
  _AccountUser(this.uid);

  @override
  final String uid;
  @override
  String get displayName => 'Player $uid';
  @override
  String get email => '$uid@example.test';
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthService {
  final changes = StreamController<User?>.broadcast(sync: true);
  User? account;

  @override
  User? get currentUser => account;
  @override
  Stream<User?> authStateChanges() => changes.stream;

  void emit(String uid) {
    account = _AccountUser(uid);
    changes.add(account);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CloudResponseGate {
  final entered = Completer<void>();
  final release = Completer<void>();
}

class _Firestore extends FakeFirebaseFirestore {
  _CloudResponseGate? nextResponse;
  int transactions = 0;
  int? failResponseNumber;

  // A committed response can arrive after the player has played another match
  // or switched accounts. The database still behaves as the real service does.
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final number = ++transactions;
    final gate = nextResponse;
    nextResponse = null;
    final result = await super.runTransaction(transactionHandler,
        timeout: timeout, maxAttempts: maxAttempts);
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
    }
    if (number == failResponseNumber) {
      throw StateError('The committed cloud response was lost');
    }
    return result;
  }
}

class _NativeAccount {
  _NativeAccount(this.deviceId, Map<String, int> initial)
      : stats = Map.of(initial);

  final String deviceId;
  Map<String, int> stats;
  final contributions = <String, int>{};
}

/// Fake of the durable native contract: cloud hydration acknowledges only the
/// captured contributions and keeps play that happened while awaiting cloud.
class _Native implements NativeBridgeService {
  final accounts = <String, _NativeAccount>{};
  final hydratedUids = <String>[];
  String? boundUid;
  int installation = 0;
  int walletCoins = 500;
  int walletGems = 10;

  _NativeAccount get active => accounts[boundUid]!;

  void seed(String uid, Map<String, int> stats) {
    accounts[uid] = _NativeAccount('installation-${++installation}', stats);
  }

  void play({required int xp, required int trophies, bool won = true}) {
    final changes = {
      'xp': xp,
      'trophies': trophies,
      'gamesPlayed': 1,
      won ? 'wins' : 'losses': 1,
      'mode_offline_games': 1,
      won ? 'mode_offline_wins' : 'mode_offline_losses': 1,
    };
    for (final entry in changes.entries) {
      active.stats[entry.key] = (active.stats[entry.key] ?? 0) + entry.value;
      active.contributions[entry.key] =
          (active.contributions[entry.key] ?? 0) + entry.value;
    }
    final peak = active.stats['bestTrophies'] ?? 0;
    if (active.stats['trophies']! > peak) {
      active.stats['bestTrophies'] = active.stats['trophies']!;
    }
  }

  @override
  Future<void> syncLegacyUser(
      {required String uid, String? username, String? photoUrl}) async {
    boundUid = uid;
    accounts.putIfAbsent(
        uid, () => _NativeAccount('installation-${++installation}', {}));
  }

  @override
  Future<void> resetLegacyUser() async => boundUid = null;

  @override
  Future<Map<String, dynamic>> getProgressionSnapshot() async => {
        'accountUid': boundUid,
        'deviceId': active.deviceId,
        'stats': Map<String, int>.of(active.stats),
        'contributions': Map<String, int>.of(active.contributions),
      };

  @override
  Future<Map<String, dynamic>> hydrateProgression(
      {required String accountUid,
      required Map<String, int> stats,
      required Map<String, int> acknowledged}) async {
    if (accountUid != boundUid) {
      throw StateError('Hydration belongs to an inactive native account');
    }
    final restored = Map<String, int>.of(stats);
    for (final contribution in active.contributions.entries) {
      final pending =
          contribution.value - (acknowledged[contribution.key] ?? 0);
      restored[contribution.key] = (restored[contribution.key] ?? 0) + pending;
    }
    if ((active.stats['bestTrophies'] ?? 0) > (restored['bestTrophies'] ?? 0)) {
      restored['bestTrophies'] = active.stats['bestTrophies']!;
    }
    active.stats = restored;
    hydratedUids.add(accountUid);
    return getProgressionSnapshot();
  }

  @override
  Future<Map<String, dynamic>> getCommerceState() async => {
        'accountUid': boundUid,
        'walletAccountUid': boundUid,
        'walletCoins': walletCoins,
        'walletGems': walletGems,
        'appliedDeliveryIds': <String>[],
        'pendingSnapshotGrants': <Map<String, dynamic>>[],
      };
  @override
  Future<Map<String, dynamic>> getCategoryState() async => {
        'unlocked': <String>[],
        'rentals': <String, int>{},
      };
  @override
  Future<bool> hydrateCommerceWallet(
      {required String accountUid,
      required int coins,
      required int gems,
      required List<String> deliveryIds}) async {
    if (boundUid != accountUid) return false;
    walletCoins = coins;
    walletGems = gems;
    return true;
  }

  @override
  Future<bool> setCategoryState(
          {required List<String> unlocked, required bool isVip}) async =>
      true;
  @override
  Future<bool> setCharacterState(
          {required int selected, required List<int> unlocked}) async =>
      true;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  Future<Map<String, int>> getUserCurrency() async => {
        'coins': walletCoins,
        'gems': walletGems,
      };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 250 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue, reason: 'The asynchronous account load settled');
}

class _Harness {
  final db = _Firestore();
  final auth = _FakeAuth();
  final native = _Native();
  late final AppState state = AppState(
    authService: auth,
    nativeBridgeService: native,
    firestore: db,
  );

  Future<void> seed(String uid, {int xp = 100, int trophies = 50}) async {
    final stats = ProgressionService.normalize({
      'xp': xp,
      'trophies': trophies,
      'bestTrophies': trophies,
    });
    await db.collection('users').doc(uid).set({
      ...ProgressionService.privatePayload(stats),
      'coins': 500,
      'gems': 10,
    });
    await db.collection('public_profiles').doc(uid).set(
        ProgressionService.publicPayload(
            uid, stats, {'username': 'Player $uid'}));
    native.seed(uid, stats);
  }

  Future<void> signIn(String uid) async {
    // Ensure the stream listener has been registered before emitting.
    state;
    auth.emit(uid);
    await _until(() => state.isCommerceReady && state.characterStateLoaded);
    await state.checkAndAwardXpForGames();
    await _drain();
  }

  Future<void> receipt(String uid, String claimId, int xp) => db
          .collection('users')
          .doc(uid)
          .collection('campaignRewardClaims')
          .doc(claimId)
          .set({
        'uid': uid,
        'xp': xp,
        'xpClaimed': false,
        'currencyClaimed': true,
      });

  Future<Map<String, dynamic>> privateData(String uid) async =>
      (await db.collection('users').doc(uid).get()).data()!;
  Future<Map<String, dynamic>> publicData(String uid) async =>
      (await db.collection('public_profiles').doc(uid).get()).data()!;

  Future<void> close() async {
    await _drain();
    state.dispose();
    await auth.changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native play and campaign receipts update real state once across reset',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.play(xp: 130, trophies: 22);
    await h.receipt('alice', 'stage-1', 70);

    expect(await h.state.grantCampaignXp(xpReward: 999, claimId: 'stage-1'),
        isTrue);
    expect(h.state.xp, 300, reason: 'XP comes from the server receipt');
    expect(h.state.level, PlayerRank.levelForXp(300));
    expect(h.state.trophies, 72);
    expect(h.state.bestTrophies, 72);
    expect(h.state.playerStats['mode_offline_games'], 1);
    expect((await h.privateData('alice'))['xp'], 300);
    expect((await h.publicData('alice'))['xp'], 300);

    expect(await h.state.grantCampaignXp(xpReward: 70, claimId: 'stage-1'),
        isTrue);
    h.native.seed('alice', {}); // Device reset: a fresh contribution ledger.
    expect(await h.state.grantCampaignXp(xpReward: 70, claimId: 'stage-1'),
        isTrue);
    expect(h.state.xp, 300);
    expect(h.state.trophies, 72);
    expect((await h.privateData('alice'))['xp'], 300);
  });

  test('a lost campaign response cannot award the same receipt twice',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.play(xp: 120, trophies: 22);
    await h.receipt('alice', 'stage-2', 70);
    // Synchronize play first, then lose only the campaign transaction response.
    h.db.failResponseNumber = h.db.transactions + 2;
    expect(await h.state.grantCampaignXp(xpReward: 70, claimId: 'stage-2'),
        isFalse);
    expect((await h.privateData('alice'))['xp'], 290);

    expect(await h.state.grantCampaignXp(xpReward: 70, claimId: 'stage-2'),
        isTrue);
    expect(h.state.xp, 290);
    expect(h.native.active.stats['xp'], 290);
    expect((await h.publicData('alice'))['xp'], 290);
  });

  test('play during a cloud request survives serialized campaign hydration',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.receipt('alice', 'stage-3', 50);
    h.native.play(xp: 80, trophies: 22);
    final gate = _CloudResponseGate();
    h.db.nextResponse = gate;
    final sync = h.state.checkAndAwardXpForGames();
    await gate.entered.future;
    h.native.play(xp: 30, trophies: -10, won: false);
    final campaign = h.state.grantCampaignXp(xpReward: 50, claimId: 'stage-3');
    final duplicateRefresh = h.state.checkAndAwardXpForGames();
    gate.release.complete();
    await sync;
    await duplicateRefresh;
    expect(await campaign, isTrue);

    expect(h.state.xp, 260);
    expect(h.state.trophies, 62);
    expect(h.state.bestTrophies, 72);
    expect(h.state.playerStats['gamesPlayed'], 2);
    expect(h.state.playerStats['wins'], 1);
    expect(h.state.playerStats['losses'], 1);
    expect(h.native.active.stats['xp'], 260);
    expect((await h.privateData('alice'))['xp'], 260);
    expect((await h.publicData('alice'))['trophies'], 62);
    await h.state.checkAndAwardXpForGames();
    expect(h.state.xp, 260, reason: 'Acknowledged play must not replay');
  });

  test('wallet saves and stale screen totals retain newer device progression',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice', xp: 100, trophies: 100);
    await h.signIn('alice');
    final newer = ProgressionService.normalize({
      'xp': 4000,
      'trophies': 82,
      'bestTrophies': 150,
    });
    await h.db
        .collection('users')
        .doc('alice')
        .set(ProgressionService.privatePayload(newer), SetOptions(merge: true));
    await h.db.collection('public_profiles').doc('alice').set(
        ProgressionService.publicPayload('alice', newer, {}),
        SetOptions(merge: true));
    h.native.walletCoins = 777;
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 777);
    expect((await h.privateData('alice'))['xp'], 4000);
    expect((await h.privateData('alice'))['trophies'], 82);

    await h.state.syncPublicProfile(level: 1, trophies: 999);
    expect(h.state.xp, 4000);
    expect(h.state.trophies, 82, reason: 'Newer remote losses must remain');
    expect(h.state.bestTrophies, 150);
    expect((await h.publicData('alice'))['xp'], 4000);
    expect((await h.publicData('alice'))['trophies'], 82);
  });

  test('an old account response cannot hydrate the newly signed in account',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice', xp: 100, trophies: 50);
    await h.seed('bob', xp: 900, trophies: 20);
    await h.signIn('alice');
    h.native.play(xp: 120, trophies: 22);
    final gate = _CloudResponseGate();
    h.db.nextResponse = gate;
    final oldSync = h.state.checkAndAwardXpForGames();
    await gate.entered.future;
    final aliceHydrations =
        h.native.hydratedUids.where((uid) => uid == 'alice').length;
    h.auth.emit('bob');
    await _until(() => h.native.boundUid == 'bob');
    gate.release.complete();
    await oldSync;
    await _until(() => h.state.isCommerceReady && h.state.characterStateLoaded);
    await h.state.checkAndAwardXpForGames();
    await _drain();

    expect(h.state.currentUser!.uid, 'bob');
    expect(h.state.xp, 900);
    expect(h.state.trophies, 20);
    expect(h.native.active.stats['xp'], 900);
    expect(h.native.hydratedUids.where((uid) => uid == 'alice').length,
        aliceHydrations);
    expect((await h.privateData('bob'))['xp'], 900);
    expect((await h.privateData('alice'))['xp'], 220);
  });
}
