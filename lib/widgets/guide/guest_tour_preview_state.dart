import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/economy_wallet.dart';
import '../../models/game_category.dart';
import '../../models/game_character.dart';
import '../../models/store_catalog.dart';
import '../../services/ad_service.dart';
import '../../services/cross_promo_service.dart';
import '../../services/in_app_purchase_service.dart';

/// Unknown account or platform operations fail closed instead of reaching a real
/// service through a delegate. These objects never construct those services.
mixin _ReadOnlyGuestPreview on ChangeNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Guest tour preview is read-only: ${invocation.memberName}');
}

/// An isolated display snapshot, not a guest account or a persisted wallet.
/// Provide it only below the tour's preview pages; authentication must use the
/// original AppState outside this subtree.
class GuestTourPreviewState extends ChangeNotifier
    with _ReadOnlyGuestPreview
    implements AppState {
  GuestTourPreviewState({
    this.demoCoins = 1200,
    this.demoGems = 20,
    this.demoLevel = 1,
    this.demoCharacterIndex = CharacterCatalog.defaultIndex,
  });

  static const displayNotice = 'عرض تعريفي — الأرصدة للشرح فقط';
  final int demoCoins, demoGems, demoLevel, demoCharacterIndex;

  /// Illustrative in-game offers match the current resource definitions in
  /// functions/src/economy.js. They are never used to authorize a transaction.
  static const resourceOfferExamples = <String, dynamic>{
    'keys_1': {'resource': 'keys', 'amount': 1, 'coins': 700, 'gems': 7},
    'keys_3': {'resource': 'keys', 'amount': 3, 'coins': 1800, 'gems': 18},
    'hearts_1': {'resource': 'hearts', 'amount': 1, 'coins': 600, 'gems': 6},
    'hearts_3': {'resource': 'hearts', 'amount': 3, 'coins': 1500, 'gems': 15},
    'tickets_1': {'resource': 'tickets', 'amount': 1, 'coins': 900, 'gems': 9},
    'tickets_3': {
      'resource': 'tickets',
      'amount': 3,
      'coins': 2400,
      'gems': 24
    },
    'play_bundle': {
      'grants': {'keys': 3, 'hearts': 3, 'tickets': 3},
      'coins': 5100,
      'gems': 51,
    },
    'play_bundle_large': {
      'grants': {'keys': 10, 'hearts': 10, 'tickets': 10},
      'coins': 16000,
      'gems': 160,
    },
  };

  static const wallet = EconomyWallet(
    dailyKeys: 3,
    dailyHearts: 3,
    tickets: 3,
    offers: resourceOfferExamples,
    rentalPrices: {
      'day': {'days': 1, 'coins': 1500, 'gems': 15},
      'week': {'days': 7, 'coins': 4500, 'gems': 45},
      'month': {'days': 30, 'coins': 9000, 'gems': 90},
    },
  );

  @override
  User? get user => null;
  @override
  User? get currentUser => null;
  @override
  bool get authStateLoaded => true;
  @override
  bool get isAccountReady => true;
  @override
  bool get isBusy => false;
  @override
  String? get error => null;
  @override
  int get coins => demoCoins;
  @override
  int get gems => demoGems;
  @override
  EconomyWallet get economyWallet => wallet;
  @override
  bool get economyLoaded => true;
  @override
  String? get economyError => null;
  @override
  int get level => demoLevel;
  @override
  int get xp => 0;
  @override
  int get xpInCurrentLevel => 0;
  @override
  int get xpNeededForLevel => 100;
  @override
  int get trophies => 0;
  @override
  int get bestTrophies => 0;
  @override
  Map<String, int> get playerStats => const {};
  @override
  bool get isOnline => true;
  @override
  bool get characterStateLoaded => true;
  @override
  bool get categoryStateLoaded => true;
  @override
  int get selectedCharacterIndex => demoCharacterIndex;
  @override
  bool get hasChosenCharacter => true;
  @override
  GameCharacter get selectedCharacter =>
      CharacterCatalog.byIndex(demoCharacterIndex);
  @override
  Set<int> get purchasedCharacters => const {};
  @override
  bool isCharacterUnlocked(GameCharacter character) =>
      character.unlock.isFree ||
      (character.unlock.isLevelGated && character.unlock.value <= demoLevel);
  @override
  List<String> get unlockedCategories => const [];
  @override
  Map<String, int> get categoryRentals => const {};
  @override
  bool get isVip => false;
  @override
  bool get hasPermanentCategoryPass => false;
  @override
  bool get hasAdFreeEntitlement => false;
  @override
  int get vipExpiresAtMillis => 0;
  @override
  Set<String> get ownedStoreProducts => const {};

  /// Display data is complete. This is not checkout authorization: all payment
  /// and wallet operations below remain disabled, and no user is signed in.
  @override
  bool get isCommerceReady => true;
  @override
  bool isCategoryUnlocked(String categoryName) =>
      !CategoryCatalog.isCategoryPremium(categoryName);
  @override
  int getCategoryRemainingRentalHours(String categoryName) => 0;
  @override
  bool get canClaimVipBonus => false;
  @override
  int get streakDay => 1;
  @override
  bool get claimedToday => false;
  @override
  bool get dailyStreakLoaded => true;
  @override
  bool get claimingDailyReward => false;
  @override
  bool get spinningLuckyWheel => false;
  @override
  bool get hasPendingLuckyWheelSpin => false;
  @override
  bool get isLuckyWheelFreeAvailable => false;
  @override
  bool get canSpinLuckyWheel => false;
  @override
  int get purchasedWheelSpins => 0;
  @override
  Map<String, int> get todayReward => const {'coins': 0, 'gems': 0};

  // Refreshes do not read native preferences, cloud data, or authentication.
  @override
  Future<void> loadCurrency() async {}
  @override
  Future<void> loadEconomy() async {}
  @override
  Future<void> loadCategoryState() async {}
  @override
  Future<void> loadCharacterState() async {}
  @override
  Future<void> loadLevelData() async {}
  @override
  Future<void> refreshCommerce() async {}
  @override
  Future<void> refreshWheelPurchases() async {}

  @override
  Future<void> economyAction(Map<String, dynamic> data) async =>
      throw StateError('هذه معاينة تعريفية؛ لا يمكن إنفاق الرصيد خلالها.');
  @override
  Future<bool> selectCharacter(int index) async => false;
  @override
  Future<bool> purchaseCharacter(GameCharacter character) async => false;
  @override
  Future<bool> unlockCategoryWithGems(String category,
          {int gemCost = 150}) async =>
      false;
  @override
  Future<bool> rentCategoryWithAd(String category, {int hours = 24}) async =>
      false;
  @override
  Future<bool> claimAdResource(String resource) async => false;
  @override
  Future<bool> claimVipBonus() async => false;
  @override
  Future<Map<String, int>?> claimDailyStreak() async => null;
}

/// Labels are intentionally non-monetary: the tour never invents a Play price.
class GuestTourPreviewPurchases extends ChangeNotifier
    with _ReadOnlyGuestPreview
    implements InAppPurchaseService {
  static AppProductDetails _details(StoreProduct product) => AppProductDetails(
        id: product.id,
        title: product.title,
        description: product.subtitle,
        price: 'معاينة',
        billingPeriod:
            product.kind == StoreProductKind.subscription ? 'P1M' : '',
        available: false,
      );

  @override
  Map<String, AppProductDetails> get products => Map.unmodifiable({
        for (final product in StoreCatalog.products)
          product.id: _details(product),
      });
  @override
  bool get hasProducts => true;
  @override
  bool get isAvailable => true;
  @override
  bool get isLoading => false;
  @override
  bool get isRestoring => false;
  @override
  bool get isPurchasing => false;
  @override
  String get error => '';
  @override
  PurchaseFlowStatus get status => PurchaseFlowStatus.idle;
  @override
  String? get activeProductId => null;
  @override
  String get statusMessage => '';
  @override
  VoidCallback? get onPurchaseCompleted => null;
  @override
  AppProductDetails? getProductDetails(String productId) {
    final product = StoreCatalog.byId(productId);
    return product == null ? null : _details(product);
  }

  @override
  String getExplanation(String productId) =>
      'عرض تعريفي؛ يظهر السعر الفعلي في المتجر بعد تسجيل الدخول.';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> loadProducts() async {}
  @override
  Future<bool> buyProduct(String productId) async => false;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  Future<bool> manageSubscriptions() async => false;
  @override
  void addDeliveryListener(void Function(String) listener) {}
  @override
  void removeDeliveryListener(void Function(String) listener) {}
}

class GuestTourPreviewAds extends ChangeNotifier
    with _ReadOnlyGuestPreview
    implements AdService {
  @override
  bool get canWatchAd => false;
  @override
  int get watchesLeft => AdService.maxDailyWatches;
  @override
  int get watchesToday => 0;
  @override
  bool get privacyOptionsRequired => false;
  @override
  bool get hasClaimedDailyPowerUp => false;
  @override
  bool get canClaimDailyPowerUp => false;
  @override
  Duration get cooldownRemaining => Duration.zero;
  @override
  Future<void> initialize() async {}
  @override
  Future<Map<String, int>?> showRewardedAd() async => null;
  @override
  Future<bool> showActionRewardedAd() async => false;
  @override
  Future<bool> claimDailyPowerUp() async => false;
  @override
  Future<FormError?> showPrivacyOptionsForm() async => null;
  @override
  void showInterstitialAd() {}
}

class GuestTourPreviewSettings extends ChangeNotifier
    with _ReadOnlyGuestPreview
    implements AppSettings {
  @override
  bool get loading => false;
  @override
  bool get isArabic => true;
  @override
  String get languageCode => 'ar';
  @override
  Locale get locale => const Locale('ar');
  @override
  bool get sfx => false;
  @override
  bool get music => false;
  @override
  bool get haptic => false;
  @override
  bool get hapticAvailable => false;
  @override
  bool get notifications => false;
  @override
  bool get systemNotifications => false;
  @override
  bool get dialogs => true;
  @override
  Future<bool> playHaptic({String style = 'light', bool force = false}) async =>
      false;
  @override
  Future<void> load() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> setSfx(bool value) async {}
  @override
  Future<void> setMusic(bool value) async {}
  @override
  Future<bool> setHaptic(bool value) async => false;
  @override
  Future<void> setNotifications(bool value) async {}
  @override
  Future<void> refreshNotificationStatus() async {}
  @override
  Future<void> setDialogs(bool value) async {}
  @override
  Future<void> setLanguage(String value) async {}
  @override
  Future<void> openNotificationSettings() async {}
}

/// Avoid lazy construction of the real promo provider inside a store preview.
class GuestTourPreviewPromo extends ChangeNotifier
    with _ReadOnlyGuestPreview
    implements CrossPromoService {
  @override
  bool get isMillionaireInstalled => false;
  @override
  bool get checkedStatus => true;
  @override
  bool get isRewardClaimed => false;
  @override
  bool get isClaiming => false;
  @override
  Future<bool> checkInstallation() async => false;
  @override
  Future<bool> checkRewardClaimed({String? uid}) async => false;
  @override
  Future<CrossPromoClaimResult> claimDownloadReward(
          BuildContext context) async =>
      CrossPromoClaimResult.failed;
  @override
  Future<String?> openMillionaireApp() async => null;
  @override
  Future<void> markDismissed() async {}
  @override
  Future<bool> shouldShowAutoPromo() async => false;
}
