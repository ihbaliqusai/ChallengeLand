import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_character.dart';
import '../models/game_category.dart';
import '../services/auth_service.dart';
import '../services/native_bridge_service.dart';
import 'player_rank.dart';
import 'trophy_league.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthService authService,
    required NativeBridgeService nativeBridgeService,
  })  : _authService = authService,
        _nativeBridgeService = nativeBridgeService {
    NativeBridgeService.addPurchaseDeliveredListener(_onPurchaseDelivered);
    _initLocalVip();
    _authSubscription = _authService.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _initLocalVip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('is_vip_subscriber') == true) {
        isVip = true;
        notifyListeners();
      }
      final catState = await _nativeBridgeService.getCategoryState();
      if (catState['isVip'] == true) {
        isVip = true;
        await prefs.setBool('is_vip_subscriber', true);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onPurchaseDelivered(String productId) {
    final clean = productId.replaceAll('_', '').toLowerCase();
    final isVipProduct = clean.contains('vip') || clean == 'noads';
    if (isVipProduct) {
      isVip = true;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('is_vip_subscriber', true);
      }).catchError((_) {});
    }
    loadCurrency();
    loadCategoryState().then((_) {
      if (isVipProduct || isVip) {
        final uid = currentUser?.uid;
        if (uid != null) {
          unawaited(_saveFullUserSnapshot(uid));
        }
      }
    });
    notifyListeners();
  }

  final AuthService _authService;
  final NativeBridgeService _nativeBridgeService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  User? user;
  bool isBusy = false;
  String? error;
  int coins = 0;
  int gems = 0;
  int trophies = 0;
  int streakDay = 0;
  bool claimedToday = false;
  bool _claimingStreak = false;

  User? get currentUser => user ?? FirebaseAuth.instance.currentUser;

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
  bool categoryStateLoaded = false;

  bool isCategoryUnlocked(String categoryName) {
    if (isVip) return true;
    if (!CategoryCatalog.isCategoryPremium(categoryName)) return true;
    final norm = GameCategory.normalize(categoryName);
    for (final item in unlockedCategories) {
      if (GameCategory.normalize(item) == norm) return true;
    }
    final expiry = categoryRentals[norm];
    if (expiry != null && expiry > DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    return false;
  }

  int getCategoryRemainingRentalHours(String categoryName) {
    final norm = GameCategory.normalize(categoryName);
    final expiry = categoryRentals[norm];
    if (expiry == null) return 0;
    final diffMs = expiry - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / (3600 * 1000)).ceil();
  }

  Future<void> loadCategoryState() async {
    try {
      final state = await _nativeBridgeService.getCategoryState();
      unlockedCategories = (state['unlocked'] as List<String>? ?? <String>[]);
      categoryRentals = (state['rentals'] as Map<String, int>? ?? <String, int>{});
      final nativeVip = state['isVip'] == true;
      final prefs = await SharedPreferences.getInstance();
      final prefsVip = prefs.getBool('is_vip_subscriber') == true;

      if (nativeVip || prefsVip || isVip) {
        isVip = true;
        await prefs.setBool('is_vip_subscriber', true);
        if (!nativeVip) {
          await _nativeBridgeService.setCategoryState(
            unlocked: unlockedCategories,
            isVip: true,
          );
        }
      } else {
        isVip = false;
      }
    } catch (_) {
    } finally {
      categoryStateLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> unlockCategoryWithGems(String category, {int gemCost = 150}) async {
    if (gems < gemCost) return false;
    final ok = await _nativeBridgeService.unlockCategoryPermanently(category, gemCost: gemCost);
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
    final ok = await _nativeBridgeService.rentCategory(category, hours: hours);
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
    }
  }

  static const List<Map<String, int>> _kStreakRewards = [
    {'coins': 100, 'gems': 0},
    {'coins': 150, 'gems': 0},
    {'coins': 200, 'gems': 1},
    {'coins': 250, 'gems': 0},
    {'coins': 300, 'gems': 1},
    {'coins': 400, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 300, 'gems': 1},
    {'coins': 350, 'gems': 1},
    {'coins': 400, 'gems': 2},
    {'coins': 450, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 600, 'gems': 3},
    {'coins': 800, 'gems': 5},
    {'coins': 400, 'gems': 2},
    {'coins': 450, 'gems': 2},
    {'coins': 500, 'gems': 3},
    {'coins': 550, 'gems': 3},
    {'coins': 600, 'gems': 4},
    {'coins': 700, 'gems': 4},
    {'coins': 1000, 'gems': 7},
    {'coins': 600, 'gems': 3},
    {'coins': 650, 'gems': 4},
    {'coins': 700, 'gems': 4},
    {'coins': 750, 'gems': 5},
    {'coins': 800, 'gems': 5},
    {'coins': 900, 'gems': 6},
    {'coins': 1000, 'gems': 7},
    {'coins': 1200, 'gems': 8},
    {'coins': 2000, 'gems': 15},
  ];

  /// Returns the reward {coins, gems} if claimed, or null if already claimed / error.
  Future<Map<String, int>?> claimDailyStreak() async {
    if (claimedToday || _claimingStreak) return null;
    _claimingStreak = true;
    notifyListeners();

    final uid = user?.uid;
    if (uid == null) {
      _claimingStreak = false;
      notifyListeners();
      return null;
    }

    final day = streakDay > 0 ? streakDay : 1;
    final reward =
        _kStreakRewards[(day - 1).clamp(0, _kStreakRewards.length - 1)];
    final rewardCoins = reward['coins'] ?? 0;
    final rewardGems = reward['gems'] ?? 0;

    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'streakDay': day,
          'lastStreakClaimDate': Timestamp.fromDate(DateTime.now()),
        },
        SetOptions(merge: true),
      );

      final balances = await _nativeBridgeService.grantCurrency(
        coins: rewardCoins,
        gems: rewardGems,
      );

      coins = balances['coins'] ?? (coins + rewardCoins);
      gems = balances['gems'] ?? (gems + rewardGems);
      unawaited(_saveCurrencySnapshot(uid));
      claimedToday = true;
      streakDay = day;
    } catch (_) {
      _claimingStreak = false;
      notifyListeners();
      return null;
    }

    _claimingStreak = false;
    notifyListeners();
    return reward;
  }

  // ── Level / XP ──────────────────────────────────────────────────────────────
  int level = 1;
  int xp = 0;
  int xpInCurrentLevel = 0;
  int xpNeededForLevel = 100;
  int _lastKnownGamesPlayed = -1;
  int _lastKnownWins = -1;
  bool _checkingXp = false;

  static int _computeLevel(int totalXp) {
    return PlayerRank.levelForXp(totalXp);
  }

  static int _computeXpInLevel(int totalXp) {
    return PlayerRank.xpIntoLevel(totalXp);
  }

  Future<void> loadLevelData() async {
    final uid = user?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      xp = (data['xp'] as num?)?.toInt() ?? 0;
      _lastKnownGamesPlayed =
          (data['lastKnownGamesPlayed'] as num?)?.toInt() ?? -1;
      _lastKnownWins = (data['lastKnownWins'] as num?)?.toInt() ?? -1;
      level = _computeLevel(xp);
      xpInCurrentLevel = _computeXpInLevel(xp);
      xpNeededForLevel = PlayerRank.xpNeededForLevel(level);
      trophies = (data['trophies'] as num?)?.toInt() ?? 0;

      // Streak data
      final lastClaimTs = data['lastStreakClaimDate'] as Timestamp?;
      final savedStreakDay = (data['streakDay'] as num?)?.toInt() ?? 0;
      if (lastClaimTs == null) {
        streakDay = 1;
        claimedToday = false;
      } else {
        final lastClaim = lastClaimTs.toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastDay =
            DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 0) {
          streakDay = savedStreakDay.clamp(1, 30);
          claimedToday = true;
        } else if (diff == 1) {
          streakDay =
              savedStreakDay >= 30 ? 1 : (savedStreakDay + 1).clamp(1, 30);
          claimedToday = false;
        } else {
          // Streak broken — reset to day 1
          streakDay = 1;
          claimedToday = false;
        }
      }
      notifyListeners();
    } catch (e) {
      // Firestore read failed (offline/network). Retain defaults and notify
      // so UI shows day 1 rather than an endless spinner.
      streakDay = streakDay > 0 ? streakDay : 1;
      notifyListeners();
    }
    unawaited(checkAndAwardXpForGames());
  }

  Future<void> checkAndAwardXpForGames() async {
    if (_checkingXp) return;
    _checkingXp = true;
    final uid = user?.uid;
    if (uid == null) {
      _checkingXp = false;
      return;
    }
    try {
      final stats = await _nativeBridgeService.getPlayerStats();
      final gamesPlayed = stats['gamesPlayed'] ?? 0;
      final wins = stats['wins'] ?? 0;
      final nativeXp = stats['xp'] ?? xp;
      final effectiveXp = nativeXp > xp ? nativeXp : xp;
      final computedLevel = _computeLevel(effectiveXp);
      final computedTrophies = TrophyProgression.computeTrophies(stats);
      final statsChanged =
          gamesPlayed != _lastKnownGamesPlayed || wins != _lastKnownWins;
      final xpChanged = xp != effectiveXp;
      final levelChanged = level != computedLevel;
      final trophiesChanged = trophies != computedTrophies;

      _lastKnownGamesPlayed = gamesPlayed;
      _lastKnownWins = wins;
      xp = effectiveXp;
      level = computedLevel;
      xpInCurrentLevel = _computeXpInLevel(effectiveXp);
      xpNeededForLevel = PlayerRank.xpNeededForLevel(level);
      trophies = computedTrophies;

      if (xpChanged || levelChanged || trophiesChanged) {
        notifyListeners();
      }

      if (statsChanged || xpChanged || levelChanged || trophiesChanged) {
        await _firestore.collection('users').doc(uid).set(
          {
            'xp': xp,
            'level': level,
            'trophies': trophies,
            'lastKnownGamesPlayed': gamesPlayed,
            'lastKnownWins': wins,
          },
          SetOptions(merge: true),
        );
        await _syncPublicProfile(
          level: level,
          trophies: trophies,
        );
      }
    } catch (_) {
    } finally {
      _checkingXp = false;
    }
  }

  Future<void> _onAuthChanged(User? nextUser) async {
    final previousUser = user;
    if (nextUser == null && previousUser != null) {
      await _saveFullUserSnapshot(previousUser.uid);
    }

    final isDifferentUser = previousUser != null && nextUser != null && previousUser.uid != nextUser.uid;
    user = nextUser;

    if (nextUser != null) {
      if (isDifferentUser) {
        _resetSessionState();
        await _nativeBridgeService.resetLegacyUser();
      }
      await _loadAndSyncUserData(nextUser.uid);
      unawaited(_syncPublicProfile());
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

  Future<void> updateUsername(String username) async {
    await _authService.updateUsername(username);
    await _syncLegacyUser();
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await _saveFullUserSnapshot(uid);
    }
    await _runBusy(_authService.signOut);
    _resetSessionState();
    await _nativeBridgeService.resetLegacyUser();
    notifyListeners();
  }

  Future<void> deleteAccount({String? password}) async {
    await _runBusy(
      () => _authService.deleteCurrentAccount(password: password),
    );
    try {
      await _nativeBridgeService.resetLocalProgress();
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
    final normalized = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
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

  Future<void> openFriendChallenge(String friendCode) async {
    await _syncLegacyUser();
    await _nativeBridgeService.launchFriendChallenge(friendCode: friendCode);
  }

  Future<void> loadCurrency() async {
    try {
      final data = await _nativeBridgeService.getUserCurrency();
      coins = data['coins'] ?? 0;
      gems = data['gems'] ?? 0;
      final uid = currentUser?.uid;
      if (uid != null) {
        unawaited(_saveCurrencySnapshot(uid));
      }
      unawaited(loadCategoryState());
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> grantCampaignReward({
    required int coinsReward,
    required int gemsReward,
    required int xpReward,
  }) async {
    final currencyGranted = await grantCampaignCurrency(
      coinsReward: coinsReward,
      gemsReward: gemsReward,
    );
    final xpGranted = await grantCampaignXp(xpReward: xpReward);
    return currencyGranted && xpGranted;
  }

  Future<bool> grantCampaignCurrency({
    required int coinsReward,
    required int gemsReward,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (coinsReward <= 0 && gemsReward <= 0) return true;
    try {
      final balances = await _nativeBridgeService.grantCurrency(
        coins: coinsReward,
        gems: gemsReward,
      );
      coins = balances['coins'] ?? (coins + coinsReward);
      gems = balances['gems'] ?? (gems + gemsReward);
      unawaited(_saveCurrencySnapshot(uid));
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

  Future<bool> grantCampaignXp({required int xpReward}) async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (xpReward <= 0) return true;
    try {
      final nextXp = xp + xpReward;
      final nextLevel = _computeLevel(nextXp);
      xp = nextXp;
      level = nextLevel;
      xpInCurrentLevel = _computeXpInLevel(nextXp);
      xpNeededForLevel = PlayerRank.xpNeededForLevel(nextLevel);
      await _firestore.collection('users').doc(uid).set(
        {
          'xp': nextXp,
          'level': nextLevel,
        },
        SetOptions(merge: true),
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncLegacyUser() async {
    final currentUser = user;
    if (currentUser == null) return;

    await _nativeBridgeService.syncLegacyUser(
      uid: currentUser.uid,
      username: _resolvedUsername(currentUser),
      photoUrl: _resolvedPhotoUrl(currentUser),
    );
  }

  Future<void> _loadAndSyncUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();

      final nativeCat = await _nativeBridgeService.getCategoryState();
      final nativeIsVip = nativeCat['isVip'] == true;
      final prefs = await SharedPreferences.getInstance();
      final prefsIsVip = prefs.getBool('is_vip_subscriber') == true;

      if (data != null && data.isNotEmpty) {
        coins = (data['coins'] as num?)?.toInt() ?? 0;
        gems = (data['gems'] as num?)?.toInt() ?? 0;

        final rawCats = data['unlockedCategories'];
        unlockedCategories = rawCats is List
            ? rawCats.map((e) => e.toString()).toList()
            : <String>[];

        final firestoreIsVip = data['isVip'] == true;
        isVip = firestoreIsVip || nativeIsVip || prefsIsVip || isVip;

        if (isVip) {
          await prefs.setBool('is_vip_subscriber', true);
          if (!firestoreIsVip) {
            unawaited(_saveFullUserSnapshot(uid));
          }
        }

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

        xp = (data['xp'] as num?)?.toInt() ?? 0;
        level = _computeLevel(xp);
        xpInCurrentLevel = _computeXpInLevel(xp);
        xpNeededForLevel = PlayerRank.xpNeededForLevel(level);
        trophies = (data['trophies'] as num?)?.toInt() ?? 0;
        _lastKnownGamesPlayed =
            (data['lastKnownGamesPlayed'] as num?)?.toInt() ?? -1;
        _lastKnownWins = (data['lastKnownWins'] as num?)?.toInt() ?? -1;
      } else {
        // حساب جديد تماماً: قيم افتراضية نظيفة خاصة به
        coins = 500;
        gems = 10;
        unlockedCategories = <String>[];
        isVip = nativeIsVip || prefsIsVip || isVip;
        if (isVip) {
          await prefs.setBool('is_vip_subscriber', true);
        }
        selectedCharacterIndex = -1;
        purchasedCharacters.clear();
        xp = 0;
        level = 1;
        xpInCurrentLevel = 0;
        xpNeededForLevel = PlayerRank.xpNeededForLevel(1);
        trophies = 0;
        await _saveFullUserSnapshot(uid);
      }

      await _syncLegacyUser();
      await _nativeBridgeService.setUserCurrency(coins: coins, gems: gems);
      await _nativeBridgeService.setCategoryState(
        unlocked: unlockedCategories,
        isVip: isVip,
      );
      await _nativeBridgeService.setCharacterState(
        selected: selectedCharacterIndex,
        unlocked: purchasedCharacters.toList(),
      );

      categoryStateLoaded = true;
      characterStateLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Error loading user data: $e');
      await loadCurrency();
      await loadCategoryState();
      await loadCharacterState();
    }
  }

  Future<void> _saveFullUserSnapshot(String uid) async {
    try {
      final currentCoins = coins;
      final currentGems = gems;
      await _firestore.collection('users').doc(uid).set(
        <String, dynamic>{
          'coins': currentCoins,
          'gems': currentGems,
          'unlockedCategories': unlockedCategories,
          'isVip': isVip,
          'characterIndex': selectedCharacterIndex,
          'purchasedCharacters': purchasedCharacters.toList(),
          'xp': xp,
          'level': level,
          'trophies': trophies,
          'currencyUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[AppState] Failed to save full user snapshot: $e');
    }
  }

  Future<void> _saveCurrencySnapshot(String uid) async {
    await _saveFullUserSnapshot(uid);
  }

  Future<void> _syncPublicProfile({
    int? level,
    int? trophies,
  }) async {
    final currentUser = user;
    if (currentUser == null) return;

    try {
      await _firestore.collection('public_profiles').doc(currentUser.uid).set(
        <String, dynamic>{
          'uid': currentUser.uid,
          'username': _resolvedUsername(currentUser),
          'photoUrl': _resolvedPhotoUrl(currentUser),
          'level': level ?? this.level,
          'trophies': trophies ?? this.trophies,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'friendCode': friendCode,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep gameplay responsive if Firestore is temporarily unavailable.
    }
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
    _authSubscription?.cancel();
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
    coins = 0;
    gems = 0;
    trophies = 0;
    streakDay = 0;
    claimedToday = false;
    level = 1;
    xp = 0;
    xpInCurrentLevel = 0;
    xpNeededForLevel = PlayerRank.xpNeededForLevel(1);
    _lastKnownGamesPlayed = -1;
    _lastKnownWins = -1;
    selectedCharacterIndex = -1;
    purchasedCharacters.clear();
    characterStateLoaded = false;
    unlockedCategories.clear();
    categoryRentals.clear();
    // Do NOT wipe isVip if user has active VIP on device
    categoryStateLoaded = false;
  }
}
