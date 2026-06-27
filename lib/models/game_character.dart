import 'package:flutter/material.dart';

/// How a character is obtained.
enum CharacterUnlockKind {
  /// Available from the start, no requirement.
  free,

  /// Unlocks automatically once the player reaches [CharacterUnlock.value].
  level,

  /// Bought once for [CharacterUnlock.value] coins.
  coins,

  /// Bought once for [CharacterUnlock.value] gems.
  gems,
}

@immutable
class CharacterUnlock {
  const CharacterUnlock(this.kind, [this.value = 0]);

  final CharacterUnlockKind kind;

  /// Required level (for [CharacterUnlockKind.level]) or the price
  /// (for [CharacterUnlockKind.coins] / [CharacterUnlockKind.gems]).
  final int value;

  bool get isFree => kind == CharacterUnlockKind.free;
  bool get isPurchasable =>
      kind == CharacterUnlockKind.coins || kind == CharacterUnlockKind.gems;
  bool get isLevelGated => kind == CharacterUnlockKind.level;
}

/// One of the eight playable contestant characters. The [index] matches the
/// native game order (see `GameOfflineContestantsController.CHARACTER_NAMES`),
/// so it is what gets stored/sent to the legacy engine for slot 0 (the human).
@immutable
class GameCharacter {
  const GameCharacter({
    required this.index,
    required this.id,
    required this.nameAr,
    required this.tagAr,
    required this.isFemale,
    required this.color,
    required this.unlock,
  });

  final int index;
  final String id;
  final String nameAr;
  final String tagAr;
  final bool isFemale;
  final Color color;
  final CharacterUnlock unlock;

  /// Flutter asset for the character face (copied from the native `emote_*`).
  String get asset => 'assets/characters/$id.png';
}

/// The catalog of the eight starter characters and how each is unlocked.
/// Omar and Sarah are free; the rest are gated by level or a one-time purchase.
class CharacterCatalog {
  CharacterCatalog._();

  static const List<GameCharacter> all = <GameCharacter>[
    GameCharacter(
      index: 0,
      id: 'khaled',
      nameAr: 'خالد',
      tagAr: 'المنافس الهادئ',
      isFemale: false,
      color: Color(0xFF38BDF8),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 4),
    ),
    GameCharacter(
      index: 1,
      id: 'omar',
      nameAr: 'عمر',
      tagAr: 'البداية المثالية',
      isFemale: false,
      color: Color(0xFF34D399),
      unlock: CharacterUnlock(CharacterUnlockKind.free),
    ),
    GameCharacter(
      index: 2,
      id: 'fahad',
      nameAr: 'فهد',
      tagAr: 'سريع البديهة',
      isFemale: false,
      color: Color(0xFFFACC15),
      unlock: CharacterUnlock(CharacterUnlockKind.coins, 12000),
    ),
    GameCharacter(
      index: 3,
      id: 'mazen',
      nameAr: 'مازن',
      tagAr: 'المثابر',
      isFemale: false,
      color: Color(0xFFF97316),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 8),
    ),
    GameCharacter(
      index: 4,
      id: 'mahmoud',
      nameAr: 'محمود',
      tagAr: 'الخبير',
      isFemale: false,
      color: Color(0xFFA78BFA),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 300),
    ),
    GameCharacter(
      index: 5,
      id: 'ellen',
      nameAr: 'إيلين',
      tagAr: 'الذكية',
      isFemale: true,
      color: Color(0xFFF472B6),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 15),
    ),
    GameCharacter(
      index: 6,
      id: 'sarah',
      nameAr: 'سارة',
      tagAr: 'البداية المثالية',
      isFemale: true,
      color: Color(0xFF22D3EE),
      unlock: CharacterUnlock(CharacterUnlockKind.free),
    ),
    GameCharacter(
      index: 7,
      id: 'talia',
      nameAr: 'تاليا',
      tagAr: 'النجمة المميّزة',
      isFemale: true,
      color: Color(0xFFEF4444),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 800),
    ),
  ];

  /// The default selection for a brand-new player (Omar).
  static const int defaultIndex = 1;

  static GameCharacter byIndex(int index) {
    if (index < 0 || index >= all.length) return all[defaultIndex];
    return all[index];
  }

  static GameCharacter? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Characters that are free from the very first launch.
  static List<GameCharacter> get freeCharacters =>
      all.where((c) => c.unlock.isFree).toList(growable: false);
}
