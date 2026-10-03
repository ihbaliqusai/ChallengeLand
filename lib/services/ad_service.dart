import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService extends ChangeNotifier {
  // ── Production AdMob ad unit IDs (publisher ca-app-pub-2427194500639575) ─────
  static const bool _useDemoUnits =
      kDebugMode && bool.fromEnvironment('ADMOB_USE_DEMO_UNITS');
  static const String _rewardedId = _useDemoUnits
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-2427194500639575/9695234568';
  static const String _interstitialId = _useDemoUnits
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-2427194500639575/4367895424';

  // ── Reward config ────────────────────────────────────────────────────────────
  static const int rewardCoins = 100;
  static const int rewardGems = 5;
  static const int maxDailyWatches = 5;
  static const int dailyPowerUpGoal = 5;
  static const Duration cooldown = Duration(hours: 1);
  static const String _prefsWatchesToday = 'ads.watchesToday';
  static const String _prefsLastWatchAt = 'ads.lastWatchAtMillis';
  static const String _prefsNextAvailableAt = 'ads.nextAvailableAtMillis';
  static const String _prefsBonusClaimedAt = 'ads.bonusClaimedAtMillis';

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _rewardedLoading = false;
  bool _interstitialLoading = false;
  bool _rewardedShowing = false;
  bool _adsAllowed = false;
  bool _disposed = false;
  Future<void>? _initialization;
  Completer<bool>? _rewardedLoad;
  Timer? _rewardedRetry;
  Timer? _interstitialRetry;
  SharedPreferences? _prefs;
  bool _privacyOptionsRequired = false;

  int _watchesToday = 0;
  DateTime? _lastWatchDate;
  DateTime? _nextAvailableAt;
  DateTime? _bonusClaimedAt;

  bool get canWatchAd {
    _resetIfNewDay();
    if (_watchesToday >= maxDailyWatches) {
      return false;
    }
    if (_nextAvailableAt != null &&
        DateTime.now().isBefore(_nextAvailableAt!)) {
      return false;
    }
    return true;
  }

  bool get privacyOptionsRequired => _privacyOptionsRequired;

  int get watchesLeft {
    _resetIfNewDay();
    return (maxDailyWatches - _watchesToday).clamp(0, maxDailyWatches);
  }

  int get watchesToday {
    _resetIfNewDay();
    return _watchesToday;
  }

  bool get hasClaimedDailyPowerUp {
    _resetIfNewDay();
    return _isSameDay(_bonusClaimedAt, DateTime.now());
  }

  bool get canClaimDailyPowerUp {
    _resetIfNewDay();
    return _watchesToday >= dailyPowerUpGoal && !hasClaimedDailyPowerUp;
  }

  Duration get cooldownRemaining {
    if (_nextAvailableAt == null) return Duration.zero;
    final remaining = _nextAvailableAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<bool> claimDailyPowerUp() async {
    _resetIfNewDay();
    if (!canClaimDailyPowerUp) {
      return false;
    }
    _bonusClaimedAt = DateTime.now();
    await _persistState();
    notifyListeners();
    return true;
  }

  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _initialization ??=
        _initialize().catchError((Object error, StackTrace stack) {
      _initialization = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _restoreState();
    // Opt-in diagnostics for local debug builds; release builds ignore this.
    if (kDebugMode) {
      const testDeviceIds = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');
      if (testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds:
                testDeviceIds.split(',').map((id) => id.trim()).toList(),
          ),
        );
      }
    }
    await MobileAds.instance.initialize();
    if (_disposed) return;
    await _refreshConsent();
    await _loadAdsIfAllowed();
  }

  Future<FormError?> showPrivacyOptionsForm() async {
    final completer = Completer<FormError?>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!completer.isCompleted) {
        completer.complete(error);
      }
    });
    _privacyOptionsRequired = await _resolvePrivacyOptionsRequirement();
    await _loadAdsIfAllowed();
    notifyListeners();
    return completer.future;
  }

  Future<bool> _loadRewarded() async {
    if (_disposed || !_adsAllowed) return false;
    if (_rewardedAd != null) return true;
    if (_rewardedLoading) return _rewardedLoad!.future;
    _rewardedRetry?.cancel();
    _rewardedLoading = true;
    final pending = _rewardedLoad = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: _rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              ad.dispose();
              return;
            }
            _rewardedAd = ad;
            _rewardedLoading = false;
            if (kDebugMode) debugPrint('[AdMob] Rewarded loaded: $_rewardedId');
            if (!pending.isCompleted) pending.complete(true);
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            if (_disposed) return;
            debugPrint('[AdMob] Rewarded load failed: $error');
            _rewardedLoading = false;
            if (!pending.isCompleted) pending.complete(false);
            _rewardedRetry = Timer(const Duration(seconds: 30), _loadRewarded);
          },
        ),
      );
    } catch (error) {
      debugPrint('[AdMob] Rewarded request failed: $error');
      _rewardedLoading = false;
      if (!pending.isCompleted) pending.complete(false);
    }
    return pending.future;
  }

  Future<void> _refreshConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            debugPrint(
                '[AdMob] Consent form: ${error.errorCode}: ${error.message}');
          }
        });
        _privacyOptionsRequired = await _resolvePrivacyOptionsRequirement();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (FormError error) async {
        debugPrint(
            '[AdMob] Consent update: ${error.errorCode}: ${error.message}');
        _privacyOptionsRequired = await _resolvePrivacyOptionsRequirement();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    await completer.future;
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadAdsIfAllowed() async {
    if (_disposed) return;
    _adsAllowed = await ConsentInformation.instance.canRequestAds();
    if (_disposed) return;
    if (_adsAllowed) {
      unawaited(_loadRewarded());
      _loadInterstitial();
    } else {
      debugPrint('[AdMob] Ad requests blocked by consent status.');
    }
  }

  void _loadInterstitial() {
    if (_disposed ||
        !_adsAllowed ||
        _interstitialLoading ||
        _interstitialAd != null) {
      return;
    }
    _interstitialRetry?.cancel();
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitialAd = ad;
          _interstitialLoading = false;
          if (kDebugMode) {
            debugPrint('[AdMob] Interstitial loaded: $_interstitialId');
          }
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          if (_disposed) return;
          debugPrint('[AdMob] Interstitial load failed: $error');
          _interstitialLoading = false;
          _interstitialRetry =
              Timer(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Returns {coins, gems} on success, null if cancelled/unavailable.
  Future<Map<String, int>?> showRewardedAd() async {
    if (!canWatchAd) return null;
    final earned = await _showRewarded(recordWatch: true);
    return earned ? {'coins': rewardCoins, 'gems': rewardGems} : null;
  }

  /// Shows a rewarded ad for specific actions (such as renting a category or revival)
  /// without being constrained by the daily coin claim faucet cooldown.
  Future<bool> showActionRewardedAd() => _showRewarded(recordWatch: false);

  Future<bool> _showRewarded({required bool recordWatch}) async {
    if (_disposed || _rewardedShowing) return false;
    _rewardedShowing = true;
    try {
      await initialize().timeout(const Duration(seconds: 20));
      if (_disposed) return false;
      await _loadAdsIfAllowed();
      // Share an in-flight preload and wait for it instead of failing on tap.
      final loaded = await _loadRewarded()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      final ad = _rewardedAd;
      if (!loaded ||
          ad == null ||
          _disposed ||
          !_foreground ||
          (recordWatch && !canWatchAd)) {
        return false;
      }

      final completer = Completer<bool>();
      var earned = false;
      _rewardedAd = null;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          unawaited(_loadRewarded());
          if (!completer.isCompleted) completer.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          debugPrint('[AdMob] Rewarded show failed: $error');
          a.dispose();
          unawaited(_loadRewarded());
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      try {
        await ad.show(
          onUserEarnedReward: (_, __) {
            if (earned || _disposed) return;
            earned = true;
            if (recordWatch) _recordWatch();
          },
        );
      } catch (error) {
        debugPrint('[AdMob] Rewarded presentation failed: $error');
        ad.dispose();
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(false);
      }
      return await completer.future;
    } on TimeoutException {
      return false;
    } catch (error) {
      debugPrint('[AdMob] Rewarded initialization failed: $error');
      return false;
    } finally {
      _rewardedShowing = false;
    }
  }

  /// Shows an interstitial ad (no reward). Fire-and-forget.
  void showInterstitialAd() {
    if (_disposed || !_foreground) return;
    final ad = _interstitialAd;
    if (ad == null) return;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );

    ad.show();
  }

  void _recordWatch() {
    _resetIfNewDay();
    _watchesToday++;
    _lastWatchDate = DateTime.now();
    _nextAvailableAt = DateTime.now().add(cooldown);
    unawaited(_persistState());
    notifyListeners();
  }

  void _resetIfNewDay() {
    final now = DateTime.now();
    var shouldPersist = false;
    if (_lastWatchDate != null) {
      final last = _lastWatchDate!;
      if (last.year != now.year ||
          last.month != now.month ||
          last.day != now.day) {
        final hadState = _watchesToday != 0 || _nextAvailableAt != null;
        _watchesToday = 0;
        _nextAvailableAt = null;
        shouldPersist = shouldPersist || hadState;
      }
    }
    if (_bonusClaimedAt != null && !_isSameDay(_bonusClaimedAt, now)) {
      _bonusClaimedAt = null;
      shouldPersist = true;
    }
    if (shouldPersist) {
      unawaited(_persistState());
    }
  }

  void _restoreState() {
    final prefs = _prefs;
    if (prefs == null) return;

    _watchesToday = prefs.getInt(_prefsWatchesToday) ?? 0;
    final lastWatchAtMillis = prefs.getInt(_prefsLastWatchAt);
    final nextAvailableAtMillis = prefs.getInt(_prefsNextAvailableAt);
    final bonusClaimedAtMillis = prefs.getInt(_prefsBonusClaimedAt);

    if (lastWatchAtMillis != null && lastWatchAtMillis > 0) {
      _lastWatchDate = DateTime.fromMillisecondsSinceEpoch(lastWatchAtMillis);
    }
    if (nextAvailableAtMillis != null && nextAvailableAtMillis > 0) {
      _nextAvailableAt =
          DateTime.fromMillisecondsSinceEpoch(nextAvailableAtMillis);
    }
    if (bonusClaimedAtMillis != null && bonusClaimedAtMillis > 0) {
      _bonusClaimedAt =
          DateTime.fromMillisecondsSinceEpoch(bonusClaimedAtMillis);
    }

    _resetIfNewDay();
    notifyListeners();
  }

  Future<void> _persistState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setInt(_prefsWatchesToday, _watchesToday);
    if (_lastWatchDate == null) {
      await prefs.remove(_prefsLastWatchAt);
    } else {
      await prefs.setInt(
        _prefsLastWatchAt,
        _lastWatchDate!.millisecondsSinceEpoch,
      );
    }

    if (_nextAvailableAt == null) {
      await prefs.remove(_prefsNextAvailableAt);
    } else {
      await prefs.setInt(
        _prefsNextAvailableAt,
        _nextAvailableAt!.millisecondsSinceEpoch,
      );
    }

    if (_bonusClaimedAt == null) {
      await prefs.remove(_prefsBonusClaimedAt);
    } else {
      await prefs.setInt(
        _prefsBonusClaimedAt,
        _bonusClaimedAt!.millisecondsSinceEpoch,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rewardedRetry?.cancel();
    _interstitialRetry?.cancel();
    final pending = _rewardedLoad;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return false;
    }
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<bool> _resolvePrivacyOptionsRequirement() async {
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }
}
