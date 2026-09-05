import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge_service.dart';

class CrossPromoService extends ChangeNotifier {
  CrossPromoService({NativeBridgeService? bridge})
      : _bridge = bridge ?? NativeBridgeService();

  final NativeBridgeService _bridge;

  // ── Target App Information (Millionaire 2024) ──────────────────────────────
  static const String millionairePackage = 'net.androidgaming.millionaire2024';
  static const String millionaireStoreUrl =
      'https://play.google.com/store/apps/details?id=net.androidgaming.millionaire2024';
  static const String millionaireTitle = 'تحدي المليون';
  static const String millionaireSubtitle = 'لعبة أسئلة ومعلومات عامة';
  static const String millionaireRating = '4.8';
  static const String millionaireDownloads = '+100';

  // ── Sister App Information (ChallengeLand) ─────────────────────────────────
  static const String challengeLandPackage = 'com.qi7bali.landchallengeonline';
  static const String challengeLandStoreUrl =
      'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline';

  static const String _prefsKeyLastPromoDismissed = 'cross_promo.millionaire.last_dismissed';
  static const String _prefsKeyPromoClicks = 'cross_promo.millionaire.clicks';

  bool _isMillionaireInstalled = false;
  bool _checkedStatus = false;

  bool get isMillionaireInstalled => _isMillionaireInstalled;
  bool get checkedStatus => _checkedStatus;

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
