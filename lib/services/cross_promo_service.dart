import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../widgets/currency_reward_overlay.dart';
import 'native_bridge_service.dart';

enum CrossPromoClaimResult {
  success,
  notInstalled,
  alreadyClaimed,
  failed,
}

class CrossPromoService extends ChangeNotifier {
  CrossPromoService({NativeBridgeService? bridge})
      : _bridge = bridge ?? NativeBridgeService() {
    _init();
  }

  final NativeBridgeService _bridge;

  // ── Target App Information (Millionaire 2024) ──────────────────────────────
  static const String millionairePackage = 'net.androidgaming.millionaire2024';
  static const String millionaireStoreUrl =
      'https://play.google.com/store/apps/details?id=net.androidgaming.millionaire2024';
  static const String millionaireTitle = 'تحدي المليون';
  static const String millionaireSubtitle = 'لعبة أسئلة ومعلومات عامة';
  static const String millionaireRating = '4.8';
  static const String millionaireDownloads = '+100 ألف';

  // ── Reward Information (80 Gems for Download) ──────────────────────────────
  static const int downloadRewardGems = 80;

  // ── Sister App Information (ChallengeLand) ─────────────────────────────────
  static const String challengeLandPackage = 'com.qi7bali.landchallengeonline';
  static const String challengeLandStoreUrl =
      'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline';

  static const String _prefsKeyLastPromoDismissed = 'cross_promo.millionaire.last_dismissed';
  static const String _prefsKeyPromoClicks = 'cross_promo.millionaire.clicks';
  static const String _prefsKeyRewardClaimed = 'cross_promo.millionaire.reward_claimed';

  bool _isMillionaireInstalled = false;
  bool _checkedStatus = false;
  bool _isRewardClaimed = false;
  bool _isClaiming = false;

  bool get isMillionaireInstalled => _isMillionaireInstalled;
  bool get checkedStatus => _checkedStatus;
  bool get isRewardClaimed => _isRewardClaimed;
  bool get isClaiming => _isClaiming;

  Future<void> _init() async {
    await checkRewardClaimed();
    await checkInstallation();
  }

  Future<bool> checkInstallation() async {
    try {
      final installed = await _bridge.isAppInstalled(millionairePackage);
      _isMillionaireInstalled = installed;
      _checkedStatus = true;
      notifyListeners();
      return installed;
    } catch (_) {
      _isMillionaireInstalled = false;
      _checkedStatus = true;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkRewardClaimed({String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool claimed = prefs.getBool(_prefsKeyRewardClaimed) ?? false;

      if (!claimed && uid != null && uid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists && doc.data()?['claimedMillionaireDownloadReward'] == true) {
            claimed = true;
            await prefs.setBool(_prefsKeyRewardClaimed, true);
          }
        } catch (_) {}
      }

      if (_isRewardClaimed != claimed) {
        _isRewardClaimed = claimed;
        notifyListeners();
      }
      return claimed;
    } catch (_) {
      return _isRewardClaimed;
    }
  }

  Future<CrossPromoClaimResult> claimDownloadReward(BuildContext context) async {
    if (_isClaiming) return CrossPromoClaimResult.failed;
    _isClaiming = true;
    notifyListeners();

    try {
      final appState = context.read<AppState>();
      final uid = appState.currentUser?.uid;

      final alreadyClaimed = await checkRewardClaimed(uid: uid);
      if (alreadyClaimed) {
        _isClaiming = false;
        notifyListeners();
        return CrossPromoClaimResult.alreadyClaimed;
      }

      final isInstalled = await checkInstallation();
      if (!isInstalled) {
        _isClaiming = false;
        notifyListeners();
        return CrossPromoClaimResult.notInstalled;
      }

      final success = await appState.grantRewardCurrency(
        coinsReward: 0,
        gemsReward: downloadRewardGems,
      );

      if (!success) {
        _isClaiming = false;
        notifyListeners();
        return CrossPromoClaimResult.failed;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyRewardClaimed, true);

      if (uid != null && uid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'claimedMillionaireDownloadReward': true,
            'claimedMillionaireDownloadRewardGems': downloadRewardGems,
            'claimedMillionaireDownloadRewardAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[CrossPromoService] Failed to record claim in firestore: $e');
        }
      }

      _isRewardClaimed = true;
      _isClaiming = false;
      notifyListeners();

      if (context.mounted) {
        showCurrencyRewardOverlay(
          context,
          coins: 0,
          gems: downloadRewardGems,
        );
      }

      return CrossPromoClaimResult.success;
    } catch (e) {
      debugPrint('[CrossPromoService] Claim error: $e');
      _isClaiming = false;
      notifyListeners();
      return CrossPromoClaimResult.failed;
    }
  }

  Future<String?> openMillionaireApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clicks = prefs.getInt(_prefsKeyPromoClicks) ?? 0;
      await prefs.setInt(_prefsKeyPromoClicks, clicks + 1);

      final result = await _bridge.launchAppOrPlayStore(
        packageName: millionairePackage,
        playStoreUrl: millionaireStoreUrl,
      );
      // Re-verify installation status after launch attempt
      checkInstallation();
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> markDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefsKeyLastPromoDismissed,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<bool> shouldShowAutoPromo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_prefsKeyLastPromoDismissed) ?? 0;
      if (lastTime == 0) return true;
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
      final difference = DateTime.now().difference(lastDate);
      // Show at most once every 2 days if dismissed
      return difference.inHours >= 48;
    } catch (_) {
      return false;
    }
  }
}
