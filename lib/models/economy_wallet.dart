class EconomyWallet {
  const EconomyWallet(
      {this.dailyKeys = 0,
      this.keys = 0,
      this.dailyHearts = 0,
      this.hearts = 0,
      this.tickets = 0,
      this.wheelSpins = 0,
      this.categoryVouchers = 0,
      this.rentalVouchers = 0,
      this.claimedVipExpiry = 0,
      this.nextResetMillis = 0,
      this.streak = 0,
      this.revision = 0,
      this.welcomeGrantedAt = 0,
      this.weekPlayDays = 0,
      this.weekCorrect = 0,
      this.weekRewardClaimed = false,
      this.nextFreeWheelSpinMillis = 0,
      this.lastFreeWheelSpinMillis = 0,
      this.wheelClaimedToday,
      this.wheelCharacterIndex,
      this.hasWheelCharacterPreview = false,
      this.wheelCatalogVersion = 1,
      this.rewardLog = const [],
      this.owned = const [],
      this.rentals = const {},
      this.adPermits = const {},
      this.adRewardCounts = const {},
      this.adRewardLimits = const {'keys': 2, 'hearts': 2, 'tickets': 2},
      this.offers = const {},
      this.rentalPrices = const {}});
  final int dailyKeys,
      keys,
      dailyHearts,
      hearts,
      tickets,
      wheelSpins,
      categoryVouchers,
      rentalVouchers,
      claimedVipExpiry,
      nextResetMillis,
      nextFreeWheelSpinMillis,
      lastFreeWheelSpinMillis,
      streak,
      revision;
  final int welcomeGrantedAt, weekPlayDays, weekCorrect;
  final bool weekRewardClaimed;
  final bool? wheelClaimedToday;
  final int? wheelCharacterIndex;
  final bool hasWheelCharacterPreview;
  final int wheelCatalogVersion;
  final List<Map<String, dynamic>> rewardLog;
  final List<String> owned;
  final Map<String, int> rentals, adPermits;
  final Map<String, int> adRewardCounts, adRewardLimits;
  final Map<String, dynamic> offers, rentalPrices;
  int get totalKeys => dailyKeys + keys;
  int get totalHearts => dailyHearts + hearts;
  bool get isWheelFreeAvailable {
    if (nextFreeWheelSpinMillis > 0) {
      return DateTime.now().millisecondsSinceEpoch >= nextFreeWheelSpinMillis;
    }
    if (wheelClaimedToday != null) {
      return !wheelClaimedToday!;
    }
    return true;
  }
  int remainingAdRewards(String resource) =>
      ((adRewardLimits[resource] ?? 0) - (adRewardCounts[resource] ?? 0))
          .clamp(0, 2147483647);
  factory EconomyWallet.fromMap(Map<String, dynamic> map) {
    int count(String key) => (map[key] as num?)?.toInt() ?? 0;
    Map<String, int> ints(String key) => map[key] is Map
        ? Map<String, dynamic>.from(map[key] as Map)
            .map((k, v) => MapEntry(k, (v as num).toInt()))
        : {};
    return EconomyWallet(
        dailyKeys: count('dailyKeys'),
        keys: count('keys'),
        dailyHearts: count('dailyHearts'),
        hearts: count('hearts'),
        tickets: count('tickets'),
        wheelSpins: count('wheelSpins').clamp(0, 2147483647),
        categoryVouchers: count('categoryVouchers'),
        rentalVouchers: count('rentalVouchers'),
        claimedVipExpiry: count('claimedVipExpiry'),
        nextResetMillis: count('nextResetMillis'),
        nextFreeWheelSpinMillis: count('nextFreeWheelSpinMillis'),
        lastFreeWheelSpinMillis: count('lastFreeWheelSpinMillis'),
        streak: count('streak'),
        revision: count('revision'),
        welcomeGrantedAt: count('welcomeGrantedAt'),
        weekPlayDays: (map['weekDays'] as List? ?? []).length,
        weekCorrect: count('weekCorrect'),
        weekRewardClaimed: map['weekRewardClaimed'] == true,
        wheelClaimedToday: map['wheelClaimedToday'] is bool
            ? map['wheelClaimedToday'] as bool
            : null,
        wheelCharacterIndex: (map['wheelCharacterIndex'] as num?)?.toInt(),
        hasWheelCharacterPreview: map.containsKey('wheelCharacterIndex'),
        wheelCatalogVersion: (map['wheelCatalogVersion'] as num?)?.toInt() ?? 1,
        rewardLog: (map['rewardLog'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        owned: (map['owned'] as List? ?? []).whereType<String>().toList(),
        rentals: ints('rentals'),
        adPermits: ints('adPermits'),
        adRewardCounts: ints('adRewardCounts'),
        adRewardLimits: map['adRewardLimits'] is Map
            ? ints('adRewardLimits')
            : const {'keys': 2, 'hearts': 2, 'tickets': 2},
        offers: Map<String, dynamic>.from(map['offers'] as Map? ?? {}),
        rentalPrices:
            Map<String, dynamic>.from(map['rentalPrices'] as Map? ?? {}));
  }
}
