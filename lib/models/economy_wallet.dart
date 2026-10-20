class EconomyWallet {
  const EconomyWallet(
      {this.dailyKeys = 0,
      this.keys = 0,
      this.dailyHearts = 0,
      this.hearts = 0,
      this.tickets = 0,
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
      this.rewardLog = const [],
      this.owned = const [],
      this.rentals = const {},
      this.adPermits = const {},
      this.offers = const {},
      this.rentalPrices = const {}});
  final int dailyKeys,
      keys,
      dailyHearts,
      hearts,
      tickets,
      categoryVouchers,
      rentalVouchers,
      claimedVipExpiry,
      nextResetMillis,
      streak,
      revision;
  final int welcomeGrantedAt, weekPlayDays, weekCorrect;
  final bool weekRewardClaimed;
  final List<Map<String, dynamic>> rewardLog;
  final List<String> owned;
  final Map<String, int> rentals, adPermits;
  final Map<String, dynamic> offers, rentalPrices;
  int get totalKeys => dailyKeys + keys;
  int get totalHearts => dailyHearts + hearts;
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
        categoryVouchers: count('categoryVouchers'),
        rentalVouchers: count('rentalVouchers'),
        claimedVipExpiry: count('claimedVipExpiry'),
        nextResetMillis: count('nextResetMillis'),
        streak: count('streak'),
        revision: count('revision'),
        welcomeGrantedAt: count('welcomeGrantedAt'),
        weekPlayDays: (map['weekDays'] as List? ?? []).length,
        weekCorrect: count('weekCorrect'),
        weekRewardClaimed: map['weekRewardClaimed'] == true,
        rewardLog: (map['rewardLog'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        owned: (map['owned'] as List? ?? []).whereType<String>().toList(),
        rentals: ints('rentals'),
        adPermits: ints('adPermits'),
        offers: Map<String, dynamic>.from(map['offers'] as Map? ?? {}),
        rentalPrices:
            Map<String, dynamic>.from(map['rentalPrices'] as Map? ?? {}));
  }
}
