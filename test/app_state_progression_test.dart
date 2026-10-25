import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/services/auth_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/progression_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> pendingSnapshotGrants = [];
  _CloudResponseGate? nextWalletResponse;
  Completer<Map<String, dynamic>>? nextEconomyResponse;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? wheelHandler;
  final wheelRequests = <Map<String, dynamic>>[];
  Map<String, dynamic> economyState = {'revision': 1};
  Future<Map<String, dynamic>> Function()? economyReadHandler;
  Completer<void>? adRewardEntered;
  bool failWalletSync = false;
  bool failLegacySync = false;
  int legacySyncCalls = 0;
  _CloudResponseGate? nextLegacySync;
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
    legacySyncCalls++;
    if (failLegacySync) throw StateError('Initial account binding interrupted');
    boundUid = uid;
    accounts.putIfAbsent(
        uid, () => _NativeAccount('installation-${++installation}', {}));
    final gate = nextLegacySync;
    nextLegacySync = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
    }
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
        'pendingSnapshotGrants': pendingSnapshotGrants,
      };
  @override
  Future<Map<String, dynamic>> getCategoryState() async => {
        'unlocked': List<String>.of(unlockedCategories),
        'rentals': <String, int>{},
      };

  @override
  Future<Map<String, dynamic>> economy(Map<String, dynamic> data) async {
    if (data['action'] == 'spinWheel') {
      wheelRequests.add(Map.of(data));
      return wheelHandler!(data);
    }
    if (data['action'] == 'adReward') {
      adRewardEntered?.complete();
      final response = nextEconomyResponse;
      if (response != null) return response.future;
    }
    if (economyReadHandler != null) return economyReadHandler!();
    return <String, dynamic>{'state': Map<String, dynamic>.of(economyState)};
  }

  @override
  Future<bool> hydrateCommerceWallet(
      {required String accountUid,
      required int coins,
      required int gems,
      int? referralRevision,
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('referral revision restores both currencies before a stale wallet save',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.db.doc('users/alice').set({
      'coins': 1500,
      'gems': 20,
      'referralRevision': 1,
    }, SetOptions(merge: true));
    expect(h.native.walletCoins, 500);
    await h.state.refreshReferralWallet();
    expect(h.native.walletCoins, 1500);
    expect(h.native.walletGems, 20);
    expect(h.state.coins, 1500);
    expect(h.state.gems, 20);
    await h.state.refreshReferralWallet();
    final saved = await h.privateData('alice');
    expect(saved['coins'], 1500);
    expect(saved['gems'], 20);
    expect(saved['referralRevision'], 1);
  });

  Map<String, dynamic> wheelDelivery({
    bool claimed = true,
    int revision = 2,
    int wheelSpins = 0,
    bool usedFreeSpin = true,
  }) =>
      {
        'spin': {
          'prizeId': 'chest',
          'grants': {'coins': 1000, 'gems': 20, 'keys': 2, 'tickets': 2},
          'newlyGranted': true,
          'usedFreeSpin': usedFreeSpin,
        },
        'state': {
          'revision': revision,
          'keys': 2,
          'tickets': 5,
          'wheelSpins': wheelSpins,
          'wheelClaimedToday': claimed
        },
        'currency': {'coins': 1500, 'gems': 30},
        'purchasedCharacters': [2],
      };

  test(
      'a wheel tap recovers account hydration after a transient startup failure',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    h.native.failLegacySync = true;
    h.state;
    h.auth.emit('alice');
    await _until(() => h.state.characterStateLoaded);
    expect(h.state.isCommerceReady, isFalse);
    h.native.failLegacySync = false;
    h.native.wheelHandler = (_) async => wheelDelivery();

    final prize = await h.state.spinLuckyWheel();

    expect(prize, isNotNull);
    expect(h.state.isCommerceReady, isTrue);
    expect(h.native.wheelRequests, hasLength(1));
    expect(h.state.luckyWheelError, isNull);
  });

  test(
      'a wheel tap joins an in-flight account hydration instead of duplicating it',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    final gate = _CloudResponseGate();
    h.native.nextLegacySync = gate;
    h.state;
    h.auth.emit('alice');
    await gate.entered.future;
    h.native.wheelHandler = (_) async => wheelDelivery();

    final prize = h.state.spinLuckyWheel();
    await _drain();
    expect(h.native.legacySyncCalls, 1);
    expect(h.native.wheelRequests, isEmpty);
    gate.release.complete();

    expect(await prize, isNotNull);
    expect(h.native.wheelRequests, hasLength(1));
    expect(h.state.isCommerceReady, isTrue);
  });

  test('switching account during wheel hydration never sends the old spin',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.seed('bob');
    h.native.failLegacySync = true;
    h.state;
    h.auth.emit('alice');
    await _until(() => h.state.characterStateLoaded);
    h.native.failLegacySync = false;
    final gate = _CloudResponseGate();
    h.native.nextLegacySync = gate;
    h.native.wheelHandler = (_) async => wheelDelivery();
    final prize = h.state.spinLuckyWheel();
    await gate.entered.future;

    h.auth.emit('bob');
    await _until(() => h.state.isCommerceReady);
    gate.release.complete();

    expect(await prize, isNull);
    expect(h.state.currentUser!.uid, 'bob');
    expect(h.native.boundUid, 'bob');
    expect(h.native.wheelRequests, isEmpty);
    expect(h.state.coins, 500);
  });

  test('a stalled wallet snapshot releases the wheel for a safe retry',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    final gate = _CloudResponseGate();
    h.db.nextResponse = gate;
    final save = h.state.refreshReferralWallet();
    await gate.entered.future;
    h.native.wheelHandler = (_) async => wheelDelivery();

    final prize = await h.state.spinLuckyWheel();

    expect(prize, isNull);
    expect(h.state.spinningLuckyWheel, isFalse);
    expect(h.state.luckyWheelError, contains('استغرقت مزامنة حسابك'));
    expect(h.native.wheelRequests, isEmpty);
    expect(h.state.hasPendingLuckyWheelSpin, isFalse);
    gate.release.complete();
    await save;
    expect(await h.state.spinLuckyWheel(), isNotNull);
    expect(h.native.wheelRequests, hasLength(1));
  });

  test(
      'same-day paid spins use fresh operation IDs and update the banked balance',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.state.claimedToday = true;
    h.state.economyWallet = EconomyWallet.fromMap({
      'revision': 1,
      'wheelSpins': 2,
    });
    h.native.wheelHandler = (_) async => wheelDelivery(
        revision: h.native.wheelRequests.length + 1,
        wheelSpins: 2 - h.native.wheelRequests.length,
        usedFreeSpin: false);
    expect(h.state.canSpinLuckyWheel, isTrue);
    final first = await h.state.spinLuckyWheel();
    expect(first!.usedFreeSpin, isFalse);
    expect(h.state.claimedToday, isTrue);
    expect(h.state.purchasedWheelSpins, 1);
    expect(h.state.canSpinLuckyWheel, isTrue);
    final second = await h.state.spinLuckyWheel();
    expect(second!.usedFreeSpin, isFalse);
    expect(h.state.purchasedWheelSpins, 0);
    expect(h.state.canSpinLuckyWheel, isFalse);
    expect(h.native.wheelRequests[0]['operationId'],
        isNot(h.native.wheelRequests[1]['operationId']));
  });

  test('an interrupted paid spin retries its original debit receipt', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.state.claimedToday = true;
    h.state.economyWallet = EconomyWallet.fromMap({
      'revision': 1,
      'wheelSpins': 1,
    });
    h.native.wheelHandler = (_) async {
      if (h.native.wheelRequests.length == 1) {
        throw StateError('The paid spin committed but its response was lost');
      }
      return wheelDelivery(wheelSpins: 0, usedFreeSpin: false);
    };
    expect(await h.state.spinLuckyWheel(), isNull);
    expect(h.state.purchasedWheelSpins, 1);
    expect(await h.state.spinLuckyWheel(), isNotNull);
    expect(h.native.wheelRequests[0]['operationId'],
        h.native.wheelRequests[1]['operationId']);
    expect(h.state.purchasedWheelSpins, 0);
  });

  test(
      'a proven no-credit rejection clears recovery and refreshes purchase availability',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.db
        .doc('users/alice')
        .set({'lastStreakClaimDate': Timestamp.now()}, SetOptions(merge: true));
    h.state.claimedToday = true;
    h.state.economyWallet = EconomyWallet.fromMap({
      'revision': 1,
      'wheelSpins': 1,
    });
    h.native.economyState = {
      'revision': 2,
      'wheelSpins': 0,
      'wheelClaimedToday': true,
    };
    h.native.wheelHandler = (_) async => {
          'wheelRejection': {
            'code': 'FAILED_PRECONDITION',
            'message': 'لا توجد لفات إضافية. اشترِ المزيد للمتابعة.',
          },
        };
    expect(await h.state.spinLuckyWheel(), isNull);
    expect(h.state.purchasedWheelSpins, 0);
    expect(h.state.hasPendingLuckyWheelSpin, isFalse);
    expect(h.state.canSpinLuckyWheel, isFalse);
    expect(
        h.state.luckyWheelError, 'لا توجد لفات إضافية. اشترِ المزيد للمتابعة.');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lucky_wheel_operation_alice'), isNull);

    // A rejected request must also release the wallet writer and daily refresh;
    // only an uncertain committed delivery needs the stale-snapshot guard.
    h.native.walletCoins = 700;
    await h.state.loadCurrency();
    await h.state.loadLevelData();
    await _drain();
    expect(h.state.claimedToday, isTrue);
    expect((await h.privateData('alice'))['coins'], 700);
    expect(h.state.canSpinLuckyWheel, isFalse);
  });

  test(
      'a restarted account recovers the saved paid-spin operation before buying again',
      () async {
    final first = _Harness();
    addTearDown(first.close);
    await first.seed('alice');
    await first.signIn('alice');
    first.state.claimedToday = true;
    first.state.economyWallet = EconomyWallet.fromMap({
      'revision': 1,
      'wheelSpins': 1,
    });
    first.native.wheelHandler = (_) async {
      await first.db.doc('users/alice').set(
          {'lastStreakClaimDate': Timestamp.now()}, SetOptions(merge: true));
      throw StateError(
          'Process stopped after the server consumed the paid spin');
    };
    expect(await first.state.spinLuckyWheel(), isNull);
    final originalId = first.native.wheelRequests.single['operationId'];
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lucky_wheel_operation_alice'), originalId);

    final restarted = _Harness(firestore: first.db);
    addTearDown(restarted.close);
    await restarted.signIn('alice');
    restarted.state.claimedToday = true;
    expect(restarted.state.purchasedWheelSpins, 0);
    expect(restarted.state.canSpinLuckyWheel, isTrue,
        reason:
            'An interrupted paid receipt stays recoverable at zero balance');
    restarted.native.wheelHandler =
        (_) async => wheelDelivery(wheelSpins: 0, usedFreeSpin: false);
    expect(await restarted.state.spinLuckyWheel(), isNotNull);
    expect(restarted.native.wheelRequests.single['operationId'], originalId);
    expect(prefs.getString('lucky_wheel_operation_alice'), isNull);
    expect(restarted.state.canSpinLuckyWheel, isFalse);
  });

  test('a delayed paid spin cannot restore an older purchased-spin balance',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.state.claimedToday = true;
    h.state.economyWallet = EconomyWallet.fromMap({
      'revision': 10,
      'wheelSpins': 2,
    });
    h.native.wheelHandler = (_) async =>
        wheelDelivery(revision: 5, wheelSpins: 3, usedFreeSpin: false);
    expect(await h.state.spinLuckyWheel(), isNotNull);
    expect(h.state.economyWallet.revision, 10);
    expect(h.state.purchasedWheelSpins, 2);
  });

  test('a verified spin-pack delivery refreshes banked spins without spinning',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.state.claimedToday = true;
    h.native.economyState = {
      'revision': 8,
      'wheelSpins': 3,
      'wheelClaimedToday': true,
    };
    // Installs the real platform event dispatcher while the account bridge
    // keeps all wallet calls local to this test.
    NativeBridgeService();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final completed = Completer<void>();
    await messenger.handlePlatformMessage(
        'millionaire/native',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onPurchaseDelivered', {'productId': 'wheel_spins_3'})),
        (_) => completed.complete());
    await completed.future;
    await _until(() => h.state.purchasedWheelSpins == 3);
    expect(h.state.claimedToday, isTrue);
    expect(h.state.canSpinLuckyWheel, isTrue);
    expect(h.native.wheelRequests, isEmpty);
  });

  test('spin-pack delivery reads again after an older zero-credit response',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    final oldRead = Completer<Map<String, dynamic>>();
    var reads = 0;
    h.native.economyReadHandler = () async {
      reads++;
      if (reads == 1) return oldRead.future;
      return {
        'state': {
          'revision': 3,
          'wheelSpins': 3,
          'wheelClaimedToday': true,
        }
      };
    };
    final beforePurchase = h.state.loadEconomy();
    await _until(() => reads == 1);

    NativeBridgeService();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final completed = Completer<void>();
    await messenger.handlePlatformMessage(
        'millionaire/native',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onPurchaseDelivered', {'productId': 'wheel_spins_3'})),
        (_) => completed.complete());
    await completed.future;
    await _drain();
    expect(reads, 1,
        reason: 'The delivery waits for the in-flight pre-purchase read');
    oldRead.complete({
      'state': {
        'revision': 2,
        'wheelSpins': 0,
        'wheelClaimedToday': true,
      }
    });
    await beforePurchase;
    await _until(() => h.state.purchasedWheelSpins == 3);
    expect(reads, 2,
        reason:
            'A fresh read after delivery must observe the purchased credits');
    expect(h.state.economyWallet.revision, 3);
    expect(h.native.wheelRequests, isEmpty);
  });

  test('lost wheel delivery retries one receipt and protects cloud totals',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.wheelHandler = (_) async {
      if (h.native.wheelRequests.length == 1) {
        await h.db.doc('users/alice').set(
            {'coins': 1500, 'gems': 30, 'lastStreakClaimDate': Timestamp.now()},
            SetOptions(merge: true));
        throw StateError('Committed response was lost');
      }
      h.native.walletCoins = 1500;
      h.native.walletGems = 30;
      return wheelDelivery();
    };
    expect(await h.state.spinLuckyWheel(), isNull);
    await h.state.loadCurrency();
    await h.state.loadLevelData();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 1500);
    expect(h.state.claimedToday, isFalse);
    final retry = await h.state.spinLuckyWheel();
    expect(retry!.prize.id, 'chest');
    expect(h.native.wheelRequests[0]['operationId'],
        h.native.wheelRequests[1]['operationId']);
    expect(h.state.coins, 1500);
    expect(h.state.purchasedCharacters, contains(2));
    expect(h.state.claimedToday, isTrue);
  });

  test('wheel double taps and an account change cannot apply an old delivery',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    final response = Completer<Map<String, dynamic>>();
    h.native.wheelHandler = (_) => response.future;
    final spin = h.state.spinLuckyWheel();
    await _until(() => h.native.wheelRequests.isNotEmpty);
    expect(await h.state.spinLuckyWheel(), isNull);
    expect(h.native.wheelRequests, hasLength(1));
    h.state.user = _AccountUser('bob');
    response.complete(wheelDelivery());
    expect(await spin, isNull);
    expect(h.state.coins, 500);
    expect(h.state.purchasedCharacters, isEmpty);
    expect(h.state.claimedToday, isFalse);
  });

  test('delayed wheel result reads the current native balance after spending',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.wheelHandler = (_) async {
      // A newer purchase has already consumed the committed wheel coins.
      h.native.walletCoins = 100;
      h.native.walletGems = 25;
      return wheelDelivery();
    };
    expect(await h.state.spinLuckyWheel(), isNotNull);
    expect(h.state.coins, 100);
    expect(h.state.gems, 25);
    expect(h.native.walletCoins, 100);
  });

  test('recovering a previous day wheel receipt preserves today\'s free spin',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.wheelHandler = (_) async => wheelDelivery(claimed: false);
    expect(await h.state.spinLuckyWheel(), isNotNull);
    expect(h.state.claimedToday, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_reward_claimed_date_alice'), isNull);
  });

  test('a committed ad reward is not reported as failed after account switch',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    final response = Completer<Map<String, dynamic>>();
    final entered = Completer<void>();
    h.native.nextEconomyResponse = response;
    h.native.adRewardEntered = entered;
    h.state.user = _AccountUser('alice');

    final claim = h.state.claimAdResource('keys');
    await entered.future;
    h.state.user = _AccountUser('bob');
    response.complete(<String, dynamic>{
      'state': <String, dynamic>{'revision': 2, 'keys': 1},
    });

    expect(await claim, isTrue);
  });

  test(
      'local reward claim suppresses a stale read and belongs only to its account',
      () async {
    final today = DateTime.now().toUtc();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues(
        {'daily_reward_claimed_date_alice': date});
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.seed('bob');
    await h.signIn('alice');
    await h.state.loadLevelData();
    expect(h.state.claimedToday, isTrue);
    await h.signIn('bob');
    await h.state.loadLevelData();
    expect(h.state.claimedToday, isFalse);
  });

  test('a saved daily claim expires on the next UTC day', () async {
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final date =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues(
        {'daily_reward_claimed_date_alice': date});
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.state.loadLevelData();
    expect(h.state.dailyStreakLoaded, isTrue);
    expect(h.state.claimedToday, isFalse);
  });

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
    final reward = AppState.getRewardForDay(1);
    final total = 500 + reward['coins']!;
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.failWalletSync = true;
    expect(await h.state.claimDailyStreak(), isNull);
    expect(h.state.claimedToday, isFalse);
    expect(h.state.dailyRewardError, isNotNull);
    expect((await h.privateData('alice'))['coins'], total);
    await h.state.loadCurrency();
    await h.state.loadLevelData();
    await _drain();
    expect((await h.privateData('alice'))['coins'], total,
        reason: 'Stale native snapshots cannot erase the committed reward');
    expect(h.state.claimedToday, isFalse,
        reason: 'Interrupted delivery remains retryable');
    h.native.failWalletSync = false;
    expect(await h.state.claimDailyStreak(), reward);
    expect(h.state.coins, total);
    expect(h.native.walletCoins, total);
    expect(h.state.claimedToday, isTrue);
    expect(h.state.dailyRewardError, isNull);
    await h.state.claimDailyStreak();
    expect((await h.privateData('alice'))['coins'], total);
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
    final reward = AppState.getRewardForDay(1);
    final total = 500 + reward['coins']!;
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.db.failResponseNumber = h.db.transactions + 1;
    expect(await h.state.claimDailyStreak(), isNull);
    expect((await h.privateData('alice'))['coins'], total);
    expect(h.native.walletCoins, 500);
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], total);
    expect(await h.state.claimDailyStreak(), reward);
    expect(h.native.walletCoins, total);
    expect((await h.privateData('alice'))['coins'], total);
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

  test('a stale native wallet cannot restore held friend challenge coins',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.db.doc('users/alice').set({
      'coins': 450,
      'friendStakeRevision': 1,
      'friendStakeMatchId': 'paid-match',
    }, SetOptions(merge: true));
    h.native.walletCoins = 500;
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 450);
    expect(h.native.walletCoins, 450);
    expect(h.state.coins, 450);

    // A second snapshot must remain read-only while the hold is live.
    h.native.walletCoins = 999;
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 450);
    expect(h.native.walletCoins, 450);
  });

  test(
      'stake wallet refresh retains pending purchases without replaying receipts',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    h.native.pendingSnapshotGrants = [
      {'deliveryId': 'new', 'coins': 100, 'gems': 3},
      {'deliveryId': 'new', 'coins': 100, 'gems': 3},
      {'deliveryId': 'already-saved', 'coins': 40, 'gems': 1},
    ];
    await h.db.doc('users/alice').set({
      'coins': 450,
      'gems': 10,
      'friendStakeRevision': 1,
      'friendStakeMatchId': 'paid-match',
      'appliedCommerceDeliveryIds': ['already-saved'],
    }, SetOptions(merge: true));
    for (var retry = 0; retry < 2; retry++) {
      await h.state.loadCurrency();
      await _drain();
      expect((await h.privateData('alice'))['coins'], 450);
      expect(h.native.walletCoins, 550);
      expect(h.native.walletGems, 13);
    }
  });

  test('a friend challenge payout replaces a stale local balance once',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.seed('alice');
    await h.signIn('alice');
    await h.db.doc('users/alice').set({
      'coins': 550,
      'friendStakeRevision': 2,
      'friendStakeMatchId': '',
    }, SetOptions(merge: true));
    h.native.walletCoins = 450;
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 550);
    expect(h.native.walletCoins, 550);
    expect(h.state.coins, 550);

    // Legitimate later local earnings still use the existing wallet flow.
    h.native.walletCoins += 20;
    await h.state.loadCurrency();
    await _drain();
    expect((await h.privateData('alice'))['coins'], 570);
    expect((await h.privateData('alice'))['friendStakeRevision'], 2);
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
