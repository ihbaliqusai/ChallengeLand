enum LuckyWheelPrizeKind { keys, tickets, coins, gems, character, chest }

/// Stable receipt identifiers shared with the server's wheel catalogs.
class LuckyWheelPrize {
  const LuckyWheelPrize({
    required this.id,
    required this.kind,
    required this.title,
    required this.amount,
    required this.assetPath,
    required this.index,
  });

  final String id;
  final LuckyWheelPrizeKind kind;
  final String title;
  final int amount;
  final String assetPath;
  final int index;

  static const currentCatalogVersion = 2;
  static const eligibleCharacterIndices = <int>[2, 4, 7, 9, 11, 12, 14, 15];
  static const characterCompensationGems = 100;
  static const chestContents = <String, int>{
    'coins': 1000,
    'gems': 20,
    'keys': 2,
    'tickets': 2,
  };

  /// Each displayed slot has its own chance, including quantity variants.
  double get probability => 1 / catalog.length;
  double get probabilityPercent => probability * 100;
  static double kindProbability(LuckyWheelPrizeKind kind) => catalog
      .where((prize) => prize.kind == kind)
      .fold(0.0, (total, prize) => total + prize.probability);

  Map<String, int> get grants => switch (kind) {
        LuckyWheelPrizeKind.keys => {'keys': amount},
        LuckyWheelPrizeKind.tickets => {'tickets': amount},
        LuckyWheelPrizeKind.coins => {'coins': amount},
        LuckyWheelPrizeKind.gems => {'gems': amount},
        LuckyWheelPrizeKind.chest => chestContents,
        LuckyWheelPrizeKind.character => const {},
      };

  String get displayTitle => switch (kind) {
        LuckyWheelPrizeKind.keys => amount == 1 ? 'مفتاح واحد' : 'مفتاحان',
        LuckyWheelPrizeKind.tickets => amount == 1 ? 'تذكرة واحدة' : 'تذكرتان',
        LuckyWheelPrizeKind.coins => '$amount نقود',
        LuckyWheelPrizeKind.gems => '$amount جوهرة',
        LuckyWheelPrizeKind.character => 'شخصية جديدة',
        LuckyWheelPrizeKind.chest => 'صندوق الحظ',
      };

  static const catalog = <LuckyWheelPrize>[
    LuckyWheelPrize(
        id: 'keys',
        kind: LuckyWheelPrizeKind.keys,
        title: 'مفتاح',
        amount: 1,
        assetPath: 'assets/home/keys.png',
        index: 0),
    LuckyWheelPrize(
        id: 'tickets',
        kind: LuckyWheelPrizeKind.tickets,
        title: 'تذكرة',
        amount: 1,
        assetPath: 'assets/home/tickets.png',
        index: 1),
    LuckyWheelPrize(
        id: 'coins',
        kind: LuckyWheelPrizeKind.coins,
        title: 'نقود',
        amount: 500,
        assetPath: 'assets/home/coins.webp',
        index: 2),
    LuckyWheelPrize(
        id: 'gems',
        kind: LuckyWheelPrizeKind.gems,
        title: 'جواهر',
        amount: 10,
        assetPath: 'assets/home/gems.webp',
        index: 3),
    LuckyWheelPrize(
        id: 'character',
        kind: LuckyWheelPrizeKind.character,
        title: 'شخصية',
        amount: 1,
        assetPath: 'assets/characters/fahad.png',
        index: 4),
    LuckyWheelPrize(
        id: 'chest',
        kind: LuckyWheelPrizeKind.chest,
        title: 'صندوق الحظ',
        amount: 1,
        assetPath: 'assets/ui/box1.png',
        index: 5),
    LuckyWheelPrize(
        id: 'keys_2',
        kind: LuckyWheelPrizeKind.keys,
        title: 'مفتاح',
        amount: 2,
        assetPath: 'assets/home/keys.png',
        index: 6),
    LuckyWheelPrize(
        id: 'tickets_2',
        kind: LuckyWheelPrizeKind.tickets,
        title: 'تذكرة',
        amount: 2,
        assetPath: 'assets/home/tickets.png',
        index: 7),
    LuckyWheelPrize(
        id: 'coins_250',
        kind: LuckyWheelPrizeKind.coins,
        title: 'نقود',
        amount: 250,
        assetPath: 'assets/home/coins.webp',
        index: 8),
    LuckyWheelPrize(
        id: 'coins_1000',
        kind: LuckyWheelPrizeKind.coins,
        title: 'نقود',
        amount: 1000,
        assetPath: 'assets/home/coins.webp',
        index: 9),
    LuckyWheelPrize(
        id: 'gems_5',
        kind: LuckyWheelPrizeKind.gems,
        title: 'جواهر',
        amount: 5,
        assetPath: 'assets/home/gems.webp',
        index: 10),
    LuckyWheelPrize(
        id: 'gems_20',
        kind: LuckyWheelPrizeKind.gems,
        title: 'جواهر',
        amount: 20,
        assetPath: 'assets/home/gems.webp',
        index: 11),
  ];

  static LuckyWheelPrize byId(String id) =>
      catalog.firstWhere((prize) => prize.id == id,
          orElse: () => throw FormatException('Unknown wheel prize', id));
}

class LuckyWheelSpin {
  const LuckyWheelSpin({
    required this.prize,
    required this.grants,
    required this.newlyGranted,
    this.characterIndex,
    this.compensation = false,
    this.usedFreeSpin = true,
    this.catalogVersion = LuckyWheelPrize.currentCatalogVersion,
  });

  final LuckyWheelPrize prize;
  final Map<String, int> grants;
  final bool newlyGranted;
  final int? characterIndex;
  final bool compensation;
  final bool usedFreeSpin;
  final int catalogVersion;

  factory LuckyWheelSpin.fromMap(Map<String, dynamic> map) {
    final rawGrants = map['grants'];
    return LuckyWheelSpin(
      prize: LuckyWheelPrize.byId(map['prizeId']?.toString() ?? ''),
      grants: Map.unmodifiable({
        if (rawGrants is Map)
          for (final entry in rawGrants.entries)
            if (entry.value is num)
              entry.key.toString(): (entry.value as num).toInt(),
      }),
      newlyGranted: map['newlyGranted'] == true,
      characterIndex: (map['characterIndex'] as num?)?.toInt(),
      compensation: map['compensation'] == true,
      usedFreeSpin: map['usedFreeSpin'] != false,
      catalogVersion: (map['catalogVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
