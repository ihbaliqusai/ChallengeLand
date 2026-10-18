import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/game_character.dart';
import '../models/game_category.dart';
import '../models/economy_wallet.dart';
import '../services/auth_service.dart';
import '../services/achievement_reward_service.dart';
import '../services/daily_reward_service.dart';
import '../services/campaign_currency_service.dart';
import '../services/native_bridge_service.dart';
import '../services/progression_service.dart';
import 'player_rank.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthService authService,
    required NativeBridgeService nativeBridgeService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _nativeBridgeService = nativeBridgeService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _progressionService = ProgressionService(firestore: firestore) {
    NativeBridgeService.addPurchaseDeliveredListener(_onPurchaseDelivered);
    unawaited(loadCategoryState());
    _authSubscription = _authService.authStateChanges().listen(_onAuthChanged);
  }

  void _onPurchaseDelivered(String productId) {
    unawaited(_refreshDeliveredPurchase());
  }

  Future<void> _refreshDeliveredPurchase() async {
    await loadCurrency();
    await loadCategoryState();
    final uid = currentUser?.uid;
    if (uid != null) await _saveFullUserSnapshot(uid);
  }

  final AuthService _authService;
  final NativeBridgeService _nativeBridgeService;
  final FirebaseFirestore _firestore;
  final ProgressionService _progressionService;

  StreamSubscription<User?>? _authSubscription;

  User? user;
  bool authStateLoaded = false;

  /// The initial route can be chosen without flashing login or character setup.
  bool get isAccountReady =>
      authStateLoaded && (user == null || characterStateLoaded);
  bool isBusy = false;
  String? error;
  int coins = 0;
  int gems = 0;
  EconomyWallet economyWallet = const EconomyWallet();
  bool economyLoaded = false;
  String? economyError;
  Future<void>? _economyLoading;
  bool _disposed = false;

  Future<void> loadEconomy() => _economyLoading ??=
      _loadEconomy().whenComplete(() => _economyLoading = null);

  Future<void> _loadEconomy() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await _nativeBridgeService.economy({'action': 'login'});
      if (_disposed || currentUser?.uid != uid) return;
      final next = EconomyWallet.fromMap(
          Map<String, dynamic>.from(result['state'] as Map? ?? {}));
      if (next.revision >= economyWallet.revision) economyWallet = next;
      economyLoaded = true;
      economyError = null;
    } catch (error) {
      if (_disposed || currentUser?.uid != uid) return;
      economyError = error.toString();
    }
    notifyListeners();
  }

  Future<void> economyAction(Map<String, dynamic> data) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('سجّل الدخول لحفظ أرصدتك.');
    final result = await _nativeBridgeService.economy(data);
    if (_disposed || currentUser?.uid != uid) return;
    final next = EconomyWallet.fromMap(
        Map<String, dynamic>.from(result['state'] as Map? ?? {}));
    if (next.revision >= economyWallet.revision) economyWallet = next;
    economyLoaded = true;
    economyError = null;
    await loadCurrency();
    await loadCategoryState();
    notifyListeners();
  }

  int trophies = 0;
  int bestTrophies = 0;
  Map<String, int> _playerStats = <String, int>{};
  Map<String, int> get playerStats => Map.unmodifiable(_playerStats);
  Future<void> _progressionTail = Future<void>.value();
  Future<void>? _progressionSyncFuture;
  String? _nativeBoundUid;
  Map<String, int> _lastProgressionAcknowledged = <String, int>{};
  int streakDay = 0;
  bool claimedToday = false;
  bool dailyStreakLoaded = false;
  bool _claimingStreak = false;
  bool _dailyRewardWalletPending = false;
  bool _achievementWalletPending = false;
  bool _achievementOperation = false;
  bool claimingAchievementRewards = false;
  String? achievementRewardError;
  int get rewardWeekStart => ((streakDay.clamp(1, 30) - 1) ~/ 7) * 7 + 1;
  int get rewardWeekLength => (31 - rewardWeekStart).clamp(1, 7);
  int get rewardWeekCompleted =>
      (streakDay.clamp(1, 30) - rewardWeekStart + (claimedToday ? 1 : 0))
          .clamp(0, rewardWeekLength);

  User? get currentUser => user ?? _authService.currentUser;

  // ── Character selection ─────────────────────────────────────────────────────
  /// The chosen character index (0..7), or -1 when the player has not picked one
  /// yet. Stored natively (single source of truth read by the game engine).
  int selectedCharacterIndex = -1;

  /// Indices of characters unlocked by a one-time purchase (level/free ones are
  /// derived, not stored here).
  final Set<int> purchasedCharacters = <int>{};

  /// True once the native character state has been read at least once. Used to
  /// avoid flashing the forced picker before we know the real selection.
  bool characterStateLoaded = false;

  bool get hasChosenCharacter => selectedCharacterIndex >= 0;

  GameCharacter get selectedCharacter => CharacterCatalog.byIndex(
        selectedCharacterIndex < 0
            ? CharacterCatalog.defaultIndex
            : selectedCharacterIndex,
      );

  /// Whether [character] is available to the player given level + purchases.
  bool isCharacterUnlocked(GameCharacter character) {
    switch (character.unlock.kind) {
      case CharacterUnlockKind.free:
        return true;
      case CharacterUnlockKind.level:
        return level >= character.unlock.value;
      case CharacterUnlockKind.coins:
      case CharacterUnlockKind.gems:
        return purchasedCharacters.contains(character.index);
    }
  }

  Future<void> loadCharacterState() async {
    try {
      final state = await _nativeBridgeService.getCharacterState();
      selectedCharacterIndex = (state['selected'] as int?) ?? -1;
      purchasedCharacters
        ..clear()
        ..addAll((state['unlocked'] as List<int>? ?? const <int>[]));

      // Cross-device restore: if nothing is chosen locally but the cloud has a
      // character on file, adopt it so a returning player keeps their identity.
      if (selectedCharacterIndex < 0) {
        final uid = user?.uid;
        if (uid != null) {
          final doc = await _firestore.collection('users').doc(uid).get();
          final remoteIndex = (doc.data()?['characterIndex'] as num?)?.toInt();
          if (remoteIndex != null && remoteIndex >= 0) {
            selectedCharacterIndex = remoteIndex;
            await _nativeBridgeService.setSelectedCharacter(remoteIndex);
          }
        }
      }
    } catch (_) {
      // Keep defaults; the forced picker will run if nothing was chosen.
    } finally {
      characterStateLoaded = true;
      notifyListeners();
    }
  }

  /// Unblocks the initial gate if native or cloud character loading took longer
  /// than the safety threshold, ensuring the player is never trapped.
  void markCharacterStateLoaded() {
    if (!characterStateLoaded) {
      characterStateLoaded = true;
      notifyListeners();
    }
  }

  /// Selects an already-unlocked character. Returns false if it is still locked.
  Future<bool> selectCharacter(int index) async {
    final character = CharacterCatalog.byIndex(index);
    if (!isCharacterUnlocked(character)) return false;
    final ok = await _nativeBridgeService.setSelectedCharacter(character.index);
    if (!ok) return false;
    selectedCharacterIndex = character.index;
    notifyListeners();
    unawaited(_saveCharacterSnapshot(character.index));
    return true;
  }

  /// Buys a locked character with coins/gems, then selects it. Returns false on
  /// insufficient balance or a failed transaction.
  Future<bool> purchaseCharacter(GameCharacter character) async {
    if (!character.unlock.isPurchasable) return false;
    if (isCharacterUnlocked(character)) return true;
    final payWith =
        character.unlock.kind == CharacterUnlockKind.coins ? 'coins' : 'gems';
    final balance = payWith == 'coins' ? coins : gems;
    if (balance < character.unlock.value) return false;

    final ok = await _nativeBridgeService.unlockCharacter(
      index: character.index,
      payWith: payWith,
      cost: character.unlock.value,
    );
    if (!ok) return false;
    purchasedCharacters.add(character.index);
    await loadCurrency();
    final uid = currentUser?.uid;
    if (uid != null) {
      unawaited(_saveFullUserSnapshot(uid));
    }
    notifyListeners();
    return true;
  }

  Future<void> _saveCharacterSnapshot(int index) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        <String, dynamic>{'characterIndex': index},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  // ── Category Unlocks & Rentals ──────────────────────────────────────────────
  List<String> unlockedCategories = <String>[];
  Map<String, int> categoryRentals = <String, int>{};
  bool isVip = false;
  bool hasPermanentCategoryPass = false;
  bool hasAdFreeEntitlement = false;
  int vipExpiresAtMillis = 0;
  final Set<String> ownedStoreProducts = <String>{};
  Timer? _vipExpiryTimer;
  String? _commerceHydratedUid;
  bool get isCommerceReady =>
      currentUser != null && _commerceHydratedUid == currentUser!.uid;
  bool _restoringCommerce = false;
  Future<void> _snapshotTail = Future<void>.value();
  int _authGeneration = 0;
  bool categoryStateLoaded = false;

  bool isCategoryUnlocked(String categoryName) {
    if (economyWallet.owned.any((c) =>
        GameCategory.normalize(c) == GameCategory.normalize(categoryName))) {
      return true;
    }
    if ((economyWallet.rentals[GameCategory.normalize(categoryName)] ?? 0) >
        DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    if (hasPermanentCategoryPass ||
        (isVip && vipExpiresAtMillis > DateTime.now().millisecondsSinceEpoch)) {
      return true;
    }
    if (!CategoryCatalog.isCategoryPremium(categoryName)) return true;
    final norm = GameCategory.normalize(categoryName);
    for (final item in unlockedCategories) {
      if (GameCategory.normalize(item) == norm) return true;
    }
    final expiry =
        GameCategory.rentalExpiryMillis(categoryName, categoryRentals);
    if (expiry != null && expiry > DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    return false;
  }

  int getCategoryRemainingRentalHours(String categoryName) {
    final expiry = GameCategory.rentalExpiryMillis(categoryName, {
      ...categoryRentals,
      ...economyWallet.rentals,
    });
    if (expiry == null) return 0;
    final diffMs = expiry - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / (3600 * 1000)).ceil();
  }

  Future<void> loadCategoryState() async {
    try {
      final state = await _nativeBridgeService.getCategoryState();
      unlockedCategories = (state['unlocked'] as List<String>? ?? <String>[]);
      categoryRentals =
          (state['rentals'] as Map<String, int>? ?? <String, int>{});
      final commerce = await _nativeBridgeService.getCommerceState();
      _applyCommerceState(commerce);
    } catch (_) {
    } finally {
      categoryStateLoaded = true;
      notifyListeners();
    }
  }

  void _applyCommerceState(Map<String, dynamic> commerce) {
    _vipExpiryTimer?.cancel();
    vipExpiresAtMillis = (commerce['expiresAtMillis'] as num?)?.toInt() ?? 0;
    isVip = commerce['isVip'] == true &&
        vipExpiresAtMillis > DateTime.now().millisecondsSinceEpoch;
    hasPermanentCategoryPass = commerce['allCategories'] == true;
    hasAdFreeEntitlement = commerce['removeAds'] == true || isVip;
    final rawOwned = commerce['purchasedOneTime'];
    ownedStoreProducts
      ..clear()
      ..addAll(
          rawOwned is List ? rawOwned.map((id) => id.toString()) : <String>[]);
    if (hasPermanentCategoryPass) ownedStoreProducts.add('category_all_access');
    if (isVip) {
      _vipExpiryTimer = Timer(
        Duration(
            milliseconds:
                vipExpiresAtMillis - DateTime.now().millisecondsSinceEpoch),
        () => unawaited(loadCategoryState()),
      );
    }
  }

  Future<bool> unlockCategoryWithGems(String category,
      {int gemCost = 150}) async {
    if (gems < gemCost) return false;
    await economyAction({'action': 'own', 'category': category});
    const ok = true;
    if (ok) {
      await loadCurrency();
      await loadCategoryState();
      final uid = currentUser?.uid;
      if (uid != null) {
        unawaited(_saveFullUserSnapshot(uid));
      }
    }
    return ok;
  }

  Future<bool> rentCategoryWithAd(String category, {int hours = 24}) async {
    if (!CategoryCatalog.allowsAd(category)) return false;
    await economyAction({'action': 'ad', 'category': category});
    const ok = true;
    if (ok) {
      await loadCategoryState();
    }
    return ok;
  }

  /// Connectivity flag fed from the main app shell. Defaults to true so the
  /// first frame renders the online UI; the connectivity listener will flip it
  /// almost immediately if the device is actually offline.
  bool isOnline = true;

  /// Called by the connectivity wrapper whenever the device transitions
  /// between online and offline. When the connection comes back we eagerly
  /// re-sync remote state so balances and progress catch up automatically.
  void updateConnectivity(bool online) {
    if (online == isOnline) return;
    final wasOffline = !isOnline;
    isOnline = online;
    notifyListeners();
    if (online && wasOffline && user != null) {
      unawaited(loadCurrency());
      unawaited(loadLevelData());
      final uid = user!.uid;
      if (_commerceHydratedUid != uid) {
        unawaited(_loadAndSyncUserData(uid, _authGeneration));
      } else {
        unawaited(refreshCommerce());
      }
    }
  }

  static const streakRewards = DailyRewardService.rewards;

  /// Get the streak reward map for a specific day (1-30).
  static Map<String, int> getRewardForDay(int day) {
    return streakRewards[(day - 1).clamp(0, streakRewards.length - 1)];
  }

  /// Today's streak reward map {coins, gems}.
  Map<String, int> get todayReward =>
      getRewardForDay(streakDay > 0 ? streakDay : 1);

  String? dailyRewardError;
  bool get claimingDailyReward => _claimingStreak;

  Future<Map<String, int>?> claimDailyStreak() async {
    if (_claimingStreak) return null;
    final uid = currentUser?.uid;
    if (uid == null || _commerceHydratedUid != uid) {
      dailyRewardError = uid == null
          ? 'سجّل الدخول لاستلام مكافأتك.'
          : 'جارٍ مزامنة حسابك، حاول مجددًا بعد لحظات.';
      notifyListeners();
      return null;
    }
    final generation = _authGeneration;
    _claimingStreak = true;
    dailyRewardError = null;
    notifyListeners();
    final previousSnapshot = _snapshotTail;
    final deliveryFinished = Completer<void>();
    _snapshotTail = previousSnapshot.then((_) => deliveryFinished.future);
    try {
      await previousSnapshot;
      if (generation != _authGeneration || currentUser?.uid != uid) return null;
      _dailyRewardWalletPending = true;
      final result = await DailyRewardService(firestore: _firestore)
          .claim(
            uid: uid,
            now: DateTime.now(),
            fallbackCoins: coins,
            fallbackGems: gems,
          )
          .timeout(const Duration(seconds: 20));
      if (generation != _authGeneration || currentUser?.uid != uid) return null;
      // A retry after interrupted delivery restores the committed totals.
      final balances = await _nativeBridgeService
          .setUserCurrency(
            coins: result.balances['coins']!,
            gems: result.balances['gems']!,
            expectedUid: uid,
          )
          .timeout(const Duration(seconds: 8));
      if (generation != _authGeneration || currentUser?.uid != uid) return null;
      coins = balances['coins']!;
      gems = balances['gems']!;
      streakDay = result.day;
      claimedToday = true;
      dailyStreakLoaded = true;
      _dailyRewardWalletPending = false;
      return result.reward;
    } catch (_) {
      if (generation == _authGeneration) {
        dailyRewardError =
            'تعذّر إتمام الاستلام. تحقق من الاتصال وأعد المحاولة.';
      }
      return null;
    } finally {
      deliveryFinished.complete();
      if (generation == _authGeneration) {
        _claimingStreak = false;
        notifyListeners();
      }
    }
  }

  // ── Level / XP ──────────────────────────────────────────────────────────────
  int level = 1;
  int xp = 0;
  int xpInCurrentLevel = 0;
  int xpNeededForLevel = PlayerRank.xpNeededForLevel(1);

  void _applyProgression(Map<String, int> stats) {
    _playerStats = ProgressionService.normalize(stats);
    xp = _playerStats['xp'] ?? 0;
    level = PlayerRank.levelForXp(xp);
    xpInCurrentLevel = PlayerRank.xpIntoLevel(xp);
    xpNeededForLevel = PlayerRank.xpNeededForLevel(level);
    trophies = _playerStats['trophies'] ?? 0;
    bestTrophies = _playerStats['bestTrophies'] ?? trophies;
  }

  Future<T> _enqueueProgression<T>(Future<T> Function() action) {
    final operation = _progressionTail.then((_) => action());
    _progressionTail =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Map<String, dynamic> _publicIdentity(User account) => {
        'username': _resolvedUsername(account),
        'photoUrl': _resolvedPhotoUrl(account),
        'friendCode': friendCode,
      };

  static Map<String, int> _snapshotNumbers(dynamic raw) => raw is Map
      ? {
          for (final entry in raw.entries)
            if (entry.value is num)
              entry.key.toString(): (entry.value as num).toInt()
        }
      : <String, int>{};

  Future<void> loadLevelData() async {
    final uid = currentUser?.uid;
    final generation = _authGeneration;
    if (uid == null) return;
    await checkAndAwardXpForGames();
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (generation != _authGeneration || currentUser?.uid != uid) return;
      final data = doc.data() ?? {};

      final progress = DailyRewardProgress.fromData(data, DateTime.now());
      streakDay = progress.day;
      claimedToday = progress.claimed && !_dailyRewardWalletPending;
      dailyStreakLoaded = true;
      notifyListeners();
    } catch (e) {
      if (generation != _authGeneration || currentUser?.uid != uid) return;
      // Firestore read failed (offline/network). Retain defaults and notify
      // so UI shows day 1 rather than an endless spinner.
      streakDay = streakDay > 0 ? streakDay : 1;
      dailyStreakLoaded = true;
      notifyListeners();
    }
  }

  Future<void> checkAndAwardXpForGames() async {
    final active = _progressionSyncFuture;
    if (active != null) return active;
    final operation = _enqueueProgression<void>(() async {
      await _synchronizeProgression();
    });
    _progressionSyncFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_progressionSyncFuture, operation)) {
        _progressionSyncFuture = null;
      }
    }
  }

  Future<Map<String, dynamic>> loadAchievementState() async {
    final restored = await _runAchievementOperation(pay: false);
    return restored.$2;
  }

  Future<AchievementPayout?> claimAchievementRewards({String? key}) async {
    if (_achievementOperation) return null;
    final generation = _authGeneration;
    achievementRewardError = null;
    try {
      return (await _runAchievementOperation(pay: true, key: key)).$1;
    } catch (_) {
      if (generation != _authGeneration) return null;
      achievementRewardError =
          'تعذّر إتمام التحصيل. تحقق من الاتصال وأعد المحاولة؛ لن تُضاف الجائزة مرتين.';
      notifyListeners();
      return null;
    }
  }

  Future<(AchievementPayout, Map<String, dynamic>)> _runAchievementOperation(
      {required bool pay, String? key}) async {
    final account = currentUser;
    final uid = account?.uid;
    final generation = _authGeneration;
    if (_achievementOperation ||
        account == null ||
        uid == null ||
        !isCommerceReady) {
      throw StateError('Achievement account is not ready');
    }
    bool active() => generation == _authGeneration && currentUser?.uid == uid;
    void requireActive() {
      if (!active()) throw StateError('Achievement account changed');
    }

    _achievementOperation = true;
    claimingAchievementRewards = pay;
    notifyListeners();
    try {
      return await _enqueueProgression(() async {
        requireActive();
        if (!await _synchronizeProgression()) {
          throw StateError('Progression sync failed');
        }
        requireActive();
        final previousSnapshot = _snapshotTail;
        final deliveryFinished = Completer<void>();
        _snapshotTail = previousSnapshot.then((_) => deliveryFinished.future);
        try {
          await previousSnapshot;
          requireActive();
          final native = await _nativeBridgeService
              .getAchievements()
              .timeout(const Duration(seconds: 8));
          requireActive();
          if (pay) _achievementWalletPending = true;
          final service = AchievementRewardService(firestore: _firestore);
          final result = await (pay
                  ? service.claim(
                      uid: uid,
                      native: native,
                      key: key,
                      identity: _publicIdentity(account))
                  : service.synchronize(uid: uid, native: native))
              .timeout(const Duration(seconds: 20));
          requireActive();
          final balances = await _nativeBridgeService
              .setUserCurrency(
                coins: result.balances['coins']!,
                gems: result.balances['gems']!,
                expectedUid: uid,
              )
              .timeout(const Duration(seconds: 8));
          requireActive();
          final progression = await _nativeBridgeService
              .hydrateProgression(
                accountUid: uid,
                stats: result.stats,
                acknowledged: _lastProgressionAcknowledged,
              )
              .timeout(const Duration(seconds: 8));
          requireActive();
          if (progression['accountUid'] != uid) {
            throw StateError('Progression account changed');
          }
          await _nativeBridgeService
              .hydrateAchievementClaims(
                accountUid: uid,
                unlockedIds: result.unlockedIds,
                claimedIds: result.claimedIds,
              )
              .timeout(const Duration(seconds: 8));
          requireActive();
          coins = balances['coins']!;
          gems = balances['gems']!;
          _applyProgression(_snapshotNumbers(progression['stats']));
          _achievementWalletPending = false;
          final refreshed = await _nativeBridgeService
              .getAchievements()
              .timeout(const Duration(seconds: 8));
          requireActive();
          if (refreshed['accountUid'] != uid) {
            throw StateError('Achievement account changed');
          }
          // The committed receipts also protect the view from a stale platform read.
          for (final id in result.unlockedIds) {
            refreshed[id] = true;
          }
          for (final id in result.claimedIds) {
            refreshed['${id}_CLAIMED'] = true;
          }
          notifyListeners();
          return (result, refreshed);
        } finally {
          deliveryFinished.complete();
        }
      });
    } finally {
      if (active()) {
        _achievementOperation = false;
        claimingAchievementRewards = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _synchronizeProgression() async {
    final account = currentUser;
    if (account == null) return false;
    final uid = account.uid;
    final generation = _authGeneration;
    bool active() => currentUser?.uid == uid && generation == _authGeneration;
    try {
      if (_nativeBoundUid != uid) await _syncLegacyUser();
      if (!active()) return false;
      final snapshot = await _nativeBridgeService.getProgressionSnapshot();
      if (!active() || snapshot['accountUid'] != uid) return false;
      final nativeStats = _snapshotNumbers(snapshot['stats']);
      final contributions = _snapshotNumbers(snapshot['contributions']);
      // Native progress remains immediately visible while the network is down.
      _applyProgression(nativeStats);
      notifyListeners();
      final totals = await _progressionService.synchronize(
        uid: uid,
        deviceId: snapshot['deviceId']?.toString() ?? '',
        nativeStats: nativeStats,
        contributions: contributions,
        identity: _publicIdentity(account),
      );
      if (!active()) return false;
      final restored = await _nativeBridgeService.hydrateProgression(
        accountUid: uid,
        stats: totals,
        acknowledged: contributions,
      );
      if (!active() || restored['accountUid'] != uid) return false;
      _lastProgressionAcknowledged = contributions;
      _applyProgression(_snapshotNumbers(restored['stats']));
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('[Progression] Sync deferred: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _onAuthChanged(User? nextUser) async {
    final generation = ++_authGeneration;
    authStateLoaded = true;
    final previousUser = user;

    final isDifferentUser = previousUser != null &&
        nextUser != null &&
        previousUser.uid != nextUser.uid;
    user = nextUser;

    if (nextUser != null) {
      if (isDifferentUser) {
        _resetSessionState();
        await _nativeBridgeService.resetLegacyUser();
      }
      if (generation != _authGeneration) return;
      await _loadAndSyncUserData(nextUser.uid, generation);
      if (generation != _authGeneration) return;
      unawaited(syncPublicProfile());
    } else {
      _resetSessionState();
      await _nativeBridgeService.resetLegacyUser();
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _runBusy(
        () => _authService.signInWithEmail(email: email, password: password));
  }

  Future<void> register(String email, String password, String username) async {
    await _runBusy(
      () => _authService.registerWithEmail(
        email: email,
        password: password,
        username: username,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    await _runBusy(_authService.signInWithGoogle);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runBusy(() => _authService.sendPasswordResetEmail(email));
  }

  Future<void> updateUsername(String username) async {
    await _authService.updateUsername(username);
    await _syncLegacyUser();
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await checkAndAwardXpForGames();
      await _saveFullUserSnapshot(uid);
    }
    await _runBusy(_authService.signOut);
    _resetSessionState();
    await _nativeBridgeService.resetLegacyUser();
    notifyListeners();
  }

  Future<void> deleteAccount({String? password}) async {
    final deletedUid = currentUser?.uid;
    await _runBusy(
      () => _authService.deleteCurrentAccount(password: password),
    );
    try {
      await _nativeBridgeService.resetLocalProgress(accountUid: deletedUid);
    } catch (_) {
      // Account deletion already succeeded remotely; local cleanup is best-effort.
    }
    _resetSessionState();
    notifyListeners();
  }

  Future<void> openAuthenticatedLanding() async {
    final currentUser = user;
    if (currentUser == null) return;
    await _syncLegacyUser();
    await _nativeBridgeService.launchLegacyGame();
  }

  Future<void> openOfflineGame() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchOfflineGame();
  }

  Future<void> openMainChallenge() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchMainChallenge();
  }

  Future<void> openStats() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchStats();
  }

  Future<void> openAchievements() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchAchievements();
  }

  Future<void> openStore() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchStore();
  }

  Future<void> openNativeSettings() async {
    await _nativeBridgeService.launchNativeSettings();
  }

  String get friendCode {
    final uid = currentUser?.uid;
    if (uid == null || uid.isEmpty) return '';
    final normalized =
        uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (normalized.isEmpty) return '';
    return normalized.length > 10 ? normalized.substring(0, 10) : normalized;
  }

  Future<void> openSpeedBattle({String? matchMode, String? friendCode}) async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchSpeedBattle(
      matchMode: matchMode,
      friendCode: friendCode,
    );
  }

  Future<void> openRandomMatch() async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchRandomMatch();
  }

  Future<void> openFriendChallenge(String friendCode) async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchFriendChallenge(friendCode: friendCode);
  }

  Future<void> loadCurrency() async {
    final uid = currentUser?.uid;
    final generation = _authGeneration;
    unawaited(loadEconomy());
    try {
      final data = await _nativeBridgeService.getUserCurrency();
      if (_disposed ||
          generation != _authGeneration ||
          currentUser?.uid != uid) {
        return;
      }
      coins = data['coins'] ?? 0;
      gems = data['gems'] ?? 0;
      if (uid != null) {
        unawaited(_saveCurrencySnapshot(uid));
      }
      unawaited(loadCategoryState());
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> grantCampaignReward({
    required String claimId,
    required int coinsReward,
    required int gemsReward,
    required int xpReward,
  }) async {
    final currencyGranted = await grantCampaignCurrency(
      coinsReward: coinsReward,
      gemsReward: gemsReward,
      claimId: claimId,
    );
    final xpGranted =
        await grantCampaignXp(xpReward: xpReward, claimId: claimId);
    return currencyGranted && xpGranted;
  }

  Future<bool> grantCampaignCurrency({
    required int coinsReward,
    required int gemsReward,
    String? claimId,
  }) async {
    final uid = currentUser?.uid;
    final generation = _authGeneration;
    if (uid == null) return false;
    if (coinsReward <= 0 && gemsReward <= 0) return true;
    try {
      late final Map<String, int> balances;
      if (claimId != null) {
        if (_commerceHydratedUid != uid) return false;
        final cloudBalance =
            await CampaignCurrencyService(firestore: _firestore).grant(
          uid: uid,
          claimId: claimId,
          coins: coinsReward,
          gems: gemsReward,
          fallbackCoins: coins,
          fallbackGems: gems,
        );
        if (generation != _authGeneration || currentUser?.uid != uid) {
          return false;
        }
        balances = await _nativeBridgeService.setUserCurrency(
          coins: cloudBalance['coins']!,
          gems: cloudBalance['gems']!,
          expectedUid: uid,
        );
      } else {
        balances = await _nativeBridgeService.grantCurrency(
          coins: coinsReward,
          gems: gemsReward,
        );
      }
      if (generation != _authGeneration || currentUser?.uid != uid) {
        return false;
      }
      coins = balances['coins'] ?? (coins + coinsReward);
      gems = balances['gems'] ?? (gems + gemsReward);
      if (claimId == null) unawaited(_saveCurrencySnapshot(uid));
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> grantRewardCurrency({
    required int coinsReward,
    required int gemsReward,
  }) async {
    if (coinsReward <= 0 && gemsReward <= 0) return true;
    try {
      final balances = await _nativeBridgeService.grantCurrency(
        coins: coinsReward,
        gems: gemsReward,
      );
      coins = balances['coins'] ?? (coins + coinsReward);
      gems = balances['gems'] ?? (gems + gemsReward);
      final uid = currentUser?.uid;
      if (uid != null) {
        unawaited(_saveCurrencySnapshot(uid));
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> grantCampaignXp({required int xpReward, String? claimId}) async {
    final account = currentUser;
    final uid = account?.uid;
    final generation = _authGeneration;
    if (uid == null || account == null) return false;
    if (xpReward <= 0) return true;
    if (claimId == null || claimId.isEmpty) return false;
    try {
      return await _enqueueProgression<bool>(() async {
        bool active() =>
            generation == _authGeneration && currentUser?.uid == uid;
        final synced = await _synchronizeProgression();
        if (!synced || !active()) return false;
        final totals = await _progressionService.grantCampaignXp(
          uid: uid,
          claimId: claimId,
          identity: _publicIdentity(account),
        );
        if (!active()) return false;
        final restored = await _nativeBridgeService.hydrateProgression(
          accountUid: uid,
          stats: totals,
          acknowledged: _lastProgressionAcknowledged,
        );
        if (!active() || restored['accountUid'] != uid) return false;
        _applyProgression(_snapshotNumbers(restored['stats']));
        notifyListeners();
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncLegacyUser() async {
    final account = currentUser;
    final generation = _authGeneration;
    if (account == null) return;

    await _nativeBridgeService.syncLegacyUser(
      uid: account.uid,
      username: _resolvedUsername(account),
      photoUrl: _resolvedPhotoUrl(account),
    );
    if (generation == _authGeneration && currentUser?.uid == account.uid) {
      _nativeBoundUid = account.uid;
    }
  }

  Future<void> _loadAndSyncUserData(String uid, int generation) async {
    bool isActive() => generation == _authGeneration && currentUser?.uid == uid;
    try {
      // Account binding also works offline and must precede any wallet/stat
      // reads, otherwise a failed cloud read could expose the previous account.
      await _syncLegacyUser().timeout(const Duration(seconds: 3));
      if (!isActive()) return;
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));
      final data = doc.data();
      if (!isActive()) return;

      // Bind the native account before reading its verified entitlements.
      await _syncLegacyUser().timeout(const Duration(seconds: 3));
      if (!isActive()) return;
      final commerce = await _nativeBridgeService.getCommerceState().timeout(
          const Duration(seconds: 3),
          onTimeout: () => <String, dynamic>{});
      if (!isActive()) return;
      _applyCommerceState(commerce);
      final rawRemoteIds = data?['appliedCommerceDeliveryIds'];
      final remoteDeliveryIds = rawRemoteIds is List
          ? rawRemoteIds.whereType<String>().toSet()
          : <String>{};

      if (data != null && data.isNotEmpty) {
        coins = (data['coins'] as num?)?.toInt() ?? 0;
        gems = (data['gems'] as num?)?.toInt() ?? 0;

        final rawCats = data['unlockedCategories'];
        unlockedCategories = rawCats is List
            ? rawCats.map((e) => e.toString()).toList()
            : <String>[];

        selectedCharacterIndex =
            (data['characterIndex'] as num?)?.toInt() ?? -1;
        purchasedCharacters.clear();
        final rawChars = data['purchasedCharacters'];
        if (rawChars is List) {
          for (final c in rawChars) {
            final val = (c as num?)?.toInt();
            if (val != null) purchasedCharacters.add(val);
          }
        }

        _applyProgression(ProgressionService.readStats(data));
      } else {
        // حساب جديد تماماً: قيم افتراضية نظيفة خاصة به
        coins = 500;
        gems = 10;
        unlockedCategories = <String>[];
        selectedCharacterIndex = -1;
        purchasedCharacters.clear();
        _applyProgression(<String, int>{});
      }

      // Reconcile native grants committed just before an interrupted cloud save.
      final pendingGrants = commerce['pendingSnapshotGrants'];
      if (pendingGrants is List) {
        final recovered = <String>{};
        for (final pending in pendingGrants.whereType<Map>()) {
          final deliveryId = pending['deliveryId']?.toString() ?? '';
          if (deliveryId.isEmpty ||
              remoteDeliveryIds.contains(deliveryId) ||
              !recovered.add(deliveryId)) {
            continue;
          }
          coins += (pending['coins'] as num?)?.toInt() ?? 0;
          gems += (pending['gems'] as num?)?.toInt() ?? 0;
        }
      }

      await _syncLegacyUser().timeout(const Duration(seconds: 3));
      if (!isActive()) return;
      await _nativeBridgeService
          .hydrateCommerceWallet(
            accountUid: uid,
            coins: coins,
            gems: gems,
            deliveryIds: remoteDeliveryIds.toList(),
          )
          .timeout(const Duration(seconds: 3), onTimeout: () => true);

      if (!isActive()) return;
      try {
        await _nativeBridgeService
            .setCategoryState(
              unlocked: unlockedCategories,
              isVip: isVip,
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}

      try {
        await _nativeBridgeService
            .setCharacterState(
              selected: selectedCharacterIndex,
              unlocked: purchasedCharacters.toList(),
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}

      if (!isActive()) return;
      _commerceHydratedUid = uid;
      // Restore permanent achievement receipts before home reads its badge.
      final remoteClaims = data?['claimedAchievementIds'];
      final remoteUnlocks = data?['unlockedAchievementIds'];
      if (remoteClaims is List || remoteUnlocks is List) {
        try {
          await _nativeBridgeService
              .hydrateAchievementClaims(
                accountUid: uid,
                claimedIds: remoteClaims is List
                    ? remoteClaims.whereType<String>()
                    : const <String>[],
                unlockedIds: remoteUnlocks is List
                    ? remoteUnlocks.whereType<String>()
                    : const <String>[],
              )
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // The achievements screen retries this restore before enabling claims.
        }
      }
      if (!isActive()) return;
      try {
        await checkAndAwardXpForGames().timeout(const Duration(seconds: 3));
      } catch (_) {}
      if (!isActive()) return;
      unawaited(_saveFullUserSnapshot(uid));

      // Restore only after the account wallet and delivery ledger are hydrated.
      // An already-used receipt must never credit a restored wallet again.
      unawaited(_restoreAccountCommerce(uid));

      categoryStateLoaded = true;
      characterStateLoaded = true;
      notifyListeners();
    } catch (e) {
      if (!isActive()) return;
      debugPrint('[AppState] Error loading user data: $e');
      try {
        await checkAndAwardXpForGames().timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!isActive()) return;
      try {
        await loadCurrency().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await loadCategoryState().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await loadCharacterState().timeout(const Duration(seconds: 2));
      } catch (_) {}
    } finally {
      if (isActive()) {
        if (!categoryStateLoaded) categoryStateLoaded = true;
        if (!characterStateLoaded) characterStateLoaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> _restoreAccountCommerce(String uid) async {
    if (_restoringCommerce || _commerceHydratedUid != uid) return;
    _restoringCommerce = true;
    try {
      if (currentUser?.uid != uid) return;
      final restored = await _nativeBridgeService.restorePurchases();
      if (currentUser?.uid != uid) return;
      if (restored) {
        await loadCategoryState();
        await loadCurrency();
        await _saveFullUserSnapshot(uid);
      }
    } catch (_) {
      // Keep the verified, expiry-bound local entitlement while offline.
    } finally {
      _restoringCommerce = false;
    }
  }

  Future<void> refreshCommerce() async {
    final uid = currentUser?.uid;
    await loadCategoryState();
    if (uid != null && _commerceHydratedUid == uid) {
      await _restoreAccountCommerce(uid);
    }
  }

  Future<void> _saveFullUserSnapshot(String uid) {
    _snapshotTail = _snapshotTail.then((_) => _writeFullUserSnapshot(uid));
    return _snapshotTail;
  }

  Future<void> _writeFullUserSnapshot(String uid) async {
    try {
      // An interrupted reward delivery must not be erased by an older wallet.
      if (_dailyRewardWalletPending || _achievementWalletPending) return;
      if (currentUser?.uid != uid || _commerceHydratedUid != uid) return;
      final commerce = await _nativeBridgeService.getCommerceState();
      if (currentUser?.uid != uid ||
          _commerceHydratedUid != uid ||
          commerce['accountUid'] != uid ||
          commerce['walletAccountUid'] != uid) {
        return;
      }
      final rawDeliveryIds = commerce['appliedDeliveryIds'];
      final deliveryIds = rawDeliveryIds is List
          ? rawDeliveryIds.whereType<String>().toList()
          : <String>[];
      final currentCoins = (commerce['walletCoins'] as num?)?.toInt() ?? coins;
      final currentGems = (commerce['walletGems'] as num?)?.toInt() ?? gems;
      await _firestore.collection('users').doc(uid).set(
        <String, dynamic>{
          'coins': currentCoins,
          'gems': currentGems,
          'unlockedCategories': unlockedCategories,
          'characterIndex': selectedCharacterIndex,
          'purchasedCharacters': purchasedCharacters.toList(),
          'currencyUpdatedAt': FieldValue.serverTimestamp(),
          'appliedCommerceDeliveryIds': deliveryIds,
        },
        SetOptions(merge: true),
      );
      if (currentUser?.uid == uid && deliveryIds.isNotEmpty) {
        await _nativeBridgeService.confirmCommerceSnapshot(deliveryIds,
            accountUid: uid);
      }
    } catch (e) {
      debugPrint('[AppState] Failed to save full user snapshot: $e');
    }
  }

  Future<void> _saveCurrencySnapshot(String uid) async {
    await _saveFullUserSnapshot(uid);
  }

  Future<void> syncPublicProfile({
    int? level,
    int? trophies,
  }) async {
    // Only the progression transaction publishes totals; callers cannot
    // accidentally overwrite a newer trophy loss with an older screen value.
    await checkAndAwardXpForGames();
  }

  Future<void> _runBusy(Future<dynamic> Function() action) async {
    try {
      isBusy = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _vipExpiryTimer?.cancel();
    NativeBridgeService.removePurchaseDeliveredListener(_onPurchaseDelivered);
    super.dispose();
  }

  String _resolvedUsername(User user) {
    final candidates = <String?>[
      user.displayName,
      user.email?.split('@').first,
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isEmpty) continue;
      final lowered = normalized.toLowerCase();
      if (lowered == 'guest' || lowered == 'player') continue;
      return normalized;
    }

    return 'لاعب';
  }

  String? _resolvedPhotoUrl(User user) {
    final authPhoto = user.photoURL?.trim();
    if (authPhoto != null && authPhoto.isNotEmpty) {
      return authPhoto;
    }
    return null;
  }

  void _resetSessionState() {
    economyWallet = const EconomyWallet();
    economyLoaded = false;
    economyError = null;
    _economyLoading = null;
    coins = 0;
    gems = 0;
    trophies = 0;
    streakDay = 0;
    claimedToday = false;
    dailyStreakLoaded = false;
    _claimingStreak = false;
    dailyRewardError = null;
    _dailyRewardWalletPending = false;
    _achievementWalletPending = false;
    _achievementOperation = false;
    claimingAchievementRewards = false;
    achievementRewardError = null;
    level = 1;
    xp = 0;
    xpInCurrentLevel = 0;
    xpNeededForLevel = PlayerRank.xpNeededForLevel(1);
    bestTrophies = 0;
    _playerStats = <String, int>{};
    _nativeBoundUid = null;
    _progressionSyncFuture = null;
    _lastProgressionAcknowledged = <String, int>{};
    selectedCharacterIndex = -1;
    purchasedCharacters.clear();
    characterStateLoaded = false;
    unlockedCategories.clear();
    categoryRentals.clear();
    _vipExpiryTimer?.cancel();
    _commerceHydratedUid = null;
    isVip = false;
    vipExpiresAtMillis = 0;
    hasPermanentCategoryPass = false;
    hasAdFreeEntitlement = false;
    ownedStoreProducts.clear();
    categoryStateLoaded = false;
  }
}
