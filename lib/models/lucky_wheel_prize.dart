enum LuckyWheelPrizeKind { keys, tickets, coins, gems, character, chest }

/// This order is shared with the server's six equally likely wheel prizes.
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
  });

  final LuckyWheelPrize prize;
  final Map<String, int> grants;
  final bool newlyGranted;
  final int? characterIndex;
  final bool compensation;
  final bool usedFreeSpin;

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
    );
  }
}
