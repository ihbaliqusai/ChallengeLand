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
    final result = await super.runTransaction(
        (transaction) => transactionHandler(_MergeTransaction(transaction)),
        timeout: timeout,
        maxAttempts: maxAttempts);
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

// The fake transaction drops SetOptions; preserve real Firestore merge behavior.
class _MergeTransaction implements Transaction {
  _MergeTransaction(this.delegate);
  final Transaction delegate;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) =>
      delegate.get(ref);
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    ref.set(data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    delegate.update(ref, data);
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    delegate.delete(ref);
    return this;
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
  _CloudResponseGate? nextWalletResponse;
  bool failWalletSync = false;
  bool failAchievementSync = false;
  List<String> unlockedCategories = [];
  final achievements = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> getAchievements() async => {
        'accountUid': boundUid,
        ...?achievements[boundUid],
        'unclaimedAchievements':
            999, // The UI must derive counts from receipts.
      };

  @override
  Future<void> hydrateAchievementClaims(
      {required String accountUid,
      required Iterable<String> unlockedIds,
      required Iterable<String> claimedIds}) async {
    if (failAchievementSync || accountUid != boundUid) {
      throw StateError('Receipt sync interrupted');
    }
    final data = achievements.putIfAbsent(accountUid, () => {});
    for (final id in unlockedIds) {
      data[id] = true;
    }
    for (final id in claimedIds) {
      data['${id}_CLAIMED'] = true;
    }
  }

  @override
  Future<Map<String, int>> setUserCurrency(
      {required int coins, required int gems, String? expectedUid}) async {
    if (failWalletSync || expectedUid != boundUid) {
      throw StateError('Wallet sync interrupted');
    }
    walletCoins = coins;
    walletGems = gems;
    return {'coins': coins, 'gems': gems};
  }

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
        'unlocked': List<String>.of(unlockedCategories),
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
      {required List<String> unlocked, required bool isVip}) async {
    unlockedCategories = List<String>.of(unlocked);
    return true;
  }

  @override
  Future<bool> setCharacterState(
          {required int selected, required List<int> unlocked}) async =>
      true;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  Future<Map<String, int>> getUserCurrency() async {
    final result = {'coins': walletCoins, 'gems': walletGems};
    final gate = nextWalletResponse;
    nextWalletResponse = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
    }
    return result;
  }

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
  _Harness({_Firestore? firestore}) : db = firestore ?? _Firestore();
  final _Firestore db;
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

  test('stale devices preserve permanent purchases made on another device',
      () async {
    final db = _Firestore();
    final first = _Harness(firestore: db);
    final second = _Harness(firestore: db);
    addTearDown(first.close);
    addTearDown(second.close);
    await first.seed('alice');
    await first.signIn('alice');
    await second.signIn('alice');
    first.state.purchasedCharacters.add(2);
    first.state.unlockedCategories = ['رياضة'];
    first.native.unlockedCategories = ['رياضة'];
    second.state.purchasedCharacters.add(4);
    second.state.unlockedCategories = ['أنمي'];
    second.native.unlockedCategories = ['أنمي'];

    await Future.wait(
        [first.state.loadCurrency(), second.state.loadCurrency()]);
    await _drain();
    var data = await first.privateData('alice');
    expect(data['purchasedCharacters'], unorderedEquals([2, 4]));
    expect(data['unlockedCategories'], unorderedEquals(['رياضة', 'أنمي']));

    // An old installation may know none of the account's purchases yet.
    second.state.purchasedCharacters.clear();
    second.state.unlockedCategories = [];
    second.native.unlockedCategories = [];
    await second.state.loadCurrency();
    await _drain();
    data = await first.privateData('alice');
    expect(data['purchasedCharacters'], unorderedEquals([2, 4]));
    expect(data['unlockedCategories'], unorderedEquals(['رياضة', 'أنمي']));
  });

  test('startup routing waits for the first authentication result', () async {
    final h = _Harness();
    addTearDown(h.close);
    expect(h.state.authStateLoaded, isFalse);
    expect(h.state.isAccountReady, isFalse);
    h.auth.changes.add(null);
    await _until(() => h.state.isAccountReady);
    expect(h.state.user, isNull);
    expect(h.state.characterStateLoaded, isFalse);
  });

  test('restored account becomes ready after account hydration', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    h.state;
    h.auth.emit('alice');
    expect(h.state.authStateLoaded, isTrue);
    expect(h.state.isAccountReady, isFalse);
    await _until(() => h.state.isAccountReady);
    expect(h.state.characterStateLoaded, isTrue);
    expect(h.state.user?.uid, 'alice');
  });

  test(
      'achievement claim all stays claimed after reopening and a stale device read',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.achievements['alice'] = {
      'ACH_FIRST_GAME': true,
      'ACH_FIRST_WIN': true
    };
    final batch = await h.state.claimAchievementRewards();
    expect(batch!.newlyClaimedIds.length, 2);
    expect(h.state.coins, 630);
    expect(h.state.xp, 180);
    h.native.achievements['alice'] = {
      'ACH_FIRST_GAME': true,
      'ACH_FIRST_WIN': true
    };
    final reopened = await h.state.loadAchievementState();
    expect(reopened['ACH_FIRST_GAME_CLAIMED'], isTrue);
    expect(reopened['ACH_FIRST_WIN_CLAIMED'], isTrue);
    final retry = await h.state.claimAchievementRewards();
    expect(retry!.newlyClaimedIds, isEmpty);
    expect(h.state.coins, 630);
    expect(h.state.xp, 180);
  });

  test(
      'achievement native sync failure cannot erase receipts and is safely recovered',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.achievements['alice'] = {'ACH_FIRST_GAME': true};
    h.native.failWalletSync = true;
    expect(await h.state.claimAchievementRewards(), isNull);
    expect((await h.privateData('alice'))['coins'], 550);
    expect((await h.privateData('alice'))['xp'], 130);
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 550);
    h.native.failWalletSync = false;
    final reopened = await h.state.loadAchievementState();
    expect(reopened['ACH_FIRST_GAME_CLAIMED'], isTrue);
    expect(h.native.walletCoins, 550);
    expect(h.state.xp, 130);
    expect((await h.state.claimAchievementRewards())!.newlyClaimedIds, isEmpty);
    expect(h.native.walletCoins, 550);
  });

  test('a lost achievement response keeps both XP and currency safe on replay',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.achievements['alice'] = {'ACH_FIRST_GAME': true};
    h.db.failResponseNumber =
        h.db.transactions + 2; // Progression, then payout.
    expect(await h.state.claimAchievementRewards(), isNull);
    expect((await h.privateData('alice'))['coins'], 550);
    expect((await h.privateData('alice'))['xp'], 130);
    expect(h.native.walletCoins, 500);
    final restored = await h.state.loadAchievementState();
    expect(restored['ACH_FIRST_GAME_CLAIMED'], isTrue);
    expect(h.state.coins, 550);
    expect(h.state.xp, 130);
    expect((await h.state.claimAchievementRewards())!.newlyClaimedIds, isEmpty);
    expect(h.state.xp, 130);
  });

  test(
      'receipt hydration failure does not duplicate XP already restored natively',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.achievements['alice'] = {'ACH_FIRST_GAME': true};
    h.native.failAchievementSync = true;
    expect(await h.state.claimAchievementRewards(), isNull);
    expect(h.native.walletCoins, 550);
    expect(h.native.active.stats['xp'], 130);
    h.native.failAchievementSync = false;
    final retry = await h.state.claimAchievementRewards();
    expect(retry!.newlyClaimedIds, isEmpty);
    expect(h.state.xp, 130);
    expect((await h.privateData('alice'))['xp'], 130);
  });

  test('interrupted daily delivery survives wallet refresh and retries once',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.failWalletSync = true;
    expect(await h.state.claimDailyStreak(), isNull);
    expect(h.state.claimedToday, isFalse);
    expect(h.state.dailyRewardError, isNotNull);
    expect((await h.privateData('alice'))['coins'], 600);
    await h.state.loadCurrency();
    await h.state.loadLevelData();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 600,
        reason: 'Stale native snapshots cannot erase the committed reward');
    expect(h.state.claimedToday, isFalse,
        reason: 'Interrupted delivery remains retryable');
    h.native.failWalletSync = false;
    expect(await h.state.claimDailyStreak(), {'coins': 100, 'gems': 0});
    expect(h.state.coins, 600);
    expect(h.native.walletCoins, 600);
    expect(h.state.claimedToday, isTrue);
    expect(h.state.dailyRewardError, isNull);
    await h.state.claimDailyStreak();
    expect((await h.privateData('alice'))['coins'], 600);
  });

  test('weekly counter starts empty on day eight and ends at day thirty',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    h.state.streakDay = 8;
    expect(h.state.rewardWeekStart, 8);
    expect(h.state.rewardWeekCompleted, 0);
    h.state.claimedToday = true;
    expect(h.state.rewardWeekCompleted, 1);
    h.state.streakDay = 30;
    expect(h.state.rewardWeekLength, 2);
    expect(h.state.rewardWeekCompleted, 2);
  });

  test('lost daily cloud response can be replayed without a second grant',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.db.failResponseNumber = h.db.transactions + 1;
    expect(await h.state.claimDailyStreak(), isNull);
    expect((await h.privateData('alice'))['coins'], 600);
    expect(h.native.walletCoins, 500);
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 600);
    expect(await h.state.claimDailyStreak(), {'coins': 100, 'gems': 0});
    expect(h.native.walletCoins, 600);
    expect((await h.privateData('alice'))['coins'], 600);
  });

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

  test('a delayed wallet refresh cannot overwrite the next account balance',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.seed('bob');
    await h.signIn('alice');
    h.native.walletCoins = 777;
    final gate = _CloudResponseGate();
    h.native.nextWalletResponse = gate;
    final refresh = h.state.loadCurrency();
    await gate.entered.future;
    await h.signIn('bob');
    h.native.walletCoins = 900;
    await h.state.loadCurrency();
    await _drain();
    final savedCoins = (await h.privateData('bob'))['coins'];
    gate.release.complete();
    await refresh;
    await _drain();
    expect(h.state.currentUser!.uid, 'bob');
    expect(h.state.coins, 900);
    expect((await h.privateData('bob'))['coins'], savedCoins);
    expect(savedCoins, 900);
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
