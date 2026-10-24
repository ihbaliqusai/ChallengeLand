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

/// A playable contestant character. The [index] matches the
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
    this.assetExtension = 'png',
    this.bioAr = '',
    this.quoteAr = '',
    this.speed = 85,
    this.knowledge = 85,
    this.focus = 85,
    this.confidence = 85,
  });

  final int index;
  final String id;
  final String nameAr;
  final String tagAr;
  final bool isFemale;
  final Color color;
  final CharacterUnlock unlock;
  final String assetExtension;
  final String bioAr;
  final String quoteAr;
  final int speed;
  final int knowledge;
  final int focus;
  final int confidence;

  /// Flutter asset for the character face (copied from the native `emote_*`).
  String get asset => 'assets/characters/$id.$assetExtension';

  /// Flutter asset for the full-body character portrait.
  String get fullBodyAsset =>
      'assets/characters/contestant_$id.$assetExtension';
}

/// The character catalog and how each character is unlocked.
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
      bioAr:
          'منافس بارد الأعصاب وذو تركيز فولاذي، يحسب كل خطوة بحذر ويفكر مليًا قبل الضغط.',
      quoteAr: 'الهدوء والتركيز هما نصف الفوز في التحدي.',
      speed: 78,
      knowledge: 92,
      focus: 96,
      confidence: 86,
    ),
    GameCharacter(
      index: 1,
      id: 'omar',
      nameAr: 'عمر',
      tagAr: 'البداية المثالية',
      isFemale: false,
      color: Color(0xFF34D399),
      unlock: CharacterUnlock(CharacterUnlockKind.free),
      bioAr:
          'شاب طموح يتمتع بحماس متقد وتوازن متكامل بين مختلف مجالات الثقافة والمعرفة.',
      quoteAr: 'التحدي هو طريقي نحو قمة المليون!',
      speed: 88,
      knowledge: 86,
      focus: 85,
      confidence: 90,
    ),
    GameCharacter(
      index: 2,
      id: 'fahad',
      nameAr: 'فهد',
      tagAr: 'سريع البديهة',
      isFemale: false,
      color: Color(0xFFFACC15),
      unlock: CharacterUnlock(CharacterUnlockKind.coins, 12000),
      bioAr:
          'صاحب ردود أفعال صاعقة وبديهة متقدة، يتألق في اللحظات الحاسمة وضغط ثواني الوقت.',
      quoteAr: 'السرعة الذكية تصنع الفارق دائمًا.',
      speed: 98,
      knowledge: 82,
      focus: 80,
      confidence: 94,
    ),
    GameCharacter(
      index: 3,
      id: 'mazen',
      nameAr: 'مازن',
      tagAr: 'المثابر',
      isFemale: false,
      color: Color(0xFFF97316),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 8),
      bioAr:
          'متحدٍ لا يعرف الاستسلام، يحول كل عثرة إلى دافع أكبر لتحقيق النصر في الجولات الصعبة.',
      quoteAr: 'الإصرار هو المفتاح لكل سؤال صعب.',
      speed: 82,
      knowledge: 88,
      focus: 94,
      confidence: 88,
    ),
    GameCharacter(
      index: 4,
      id: 'mahmoud',
      nameAr: 'محمود',
      tagAr: 'الخبير',
      isFemale: false,
      color: Color(0xFFA78BFA),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 300),
      bioAr:
          'موسوعة ثقافية شاملة وخبير مخضرم بالأسئلة الدقيقة ومجالات العلوم والتاريخ.',
      quoteAr: 'المعرفة العميقة قوة لا تُقهر.',
      speed: 80,
      knowledge: 98,
      focus: 95,
      confidence: 92,
    ),
    GameCharacter(
      index: 5,
      id: 'ellen',
      nameAr: 'إلين',
      tagAr: 'الذكية',
      isFemale: true,
      color: Color(0xFFF472B6),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 15),
      bioAr:
          'تعتمد على التحليل المنطقي وسرعة استبعاد الإجابات الخاطئة بكفاءة استثنائية.',
      quoteAr: 'الذكاء الحقيقي هو كيف تقرأ الخيارات.',
      speed: 90,
      knowledge: 95,
      focus: 92,
      confidence: 88,
    ),
    GameCharacter(
      index: 6,
      id: 'sarah',
      nameAr: 'سارة',
      tagAr: 'البداية المثالية',
      isFemale: true,
      color: Color(0xFF22D3EE),
      unlock: CharacterUnlock(CharacterUnlockKind.free),
      bioAr:
          'متسابقة سريعة الملاحظة ونشيطة، تدخل كل منافسة بروح عالية وعزيمة متقدة.',
      quoteAr: 'جاهزة لكل سؤال ولكل منافس بقوة!',
      speed: 86,
      knowledge: 88,
      focus: 86,
      confidence: 92,
    ),
    GameCharacter(
      index: 7,
      id: 'talia',
      nameAr: 'تاليا',
      tagAr: 'النجمة المميّزة',
      isFemale: true,
      color: Color(0xFFEF4444),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 800),
      bioAr:
          'نجمة واثقة محبوبة الجماهير، تبهر الجميع بحضورها الطاغي وسيطرتها على أجواء التحدي.',
      quoteAr: 'الأضواء والمنصة مكان ولدت لأجله.',
      speed: 92,
      knowledge: 92,
      focus: 90,
      confidence: 99,
    ),
    GameCharacter(
      index: 8,
      id: 'layan',
      nameAr: 'ليان',
      tagAr: 'حارسة التراث',
      isFemale: true,
      color: Color(0xFFEB718C),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 20),
      assetExtension: 'webp',
      bioAr:
          'شغوفة بالتراث والحكايات الشعبية، تجمع بين ذاكرة قوية وحضور هادئ، وتتألق في أسئلة التاريخ والثقافة.',
      quoteAr: 'في كل حكاية معرفة تستحق أن نكتشفها.',
      speed: 84,
      knowledge: 96,
      focus: 91,
      confidence: 93,
    ),
    GameCharacter(
      index: 9,
      id: 'rashid',
      nameAr: 'راشد',
      tagAr: 'صاحب الحكمة',
      isFemale: false,
      color: Color(0xFFDAAD6A),
      unlock: CharacterUnlock(CharacterUnlockKind.coins, 18000),
      assetExtension: 'webp',
      bioAr:
          'قارئ نهم ومنافس متزن، يربط المعلومات ببعضها ويعتمد على التحليل والتروي للوصول إلى الإجابة المناسبة.',
      quoteAr: 'فكّر بهدوء، فالإجابة تبدأ بفهم السؤال.',
      speed: 82,
      knowledge: 95,
      focus: 96,
      confidence: 91,
    ),
    GameCharacter(
      index: 10,
      id: 'jana',
      nameAr: 'جنى',
      tagAr: 'صديقة الطبيعة',
      isFemale: true,
      color: Color(0xFF8ACE82),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 12),
      assetExtension: 'webp',
      bioAr:
          'محبة للطبيعة والعلوم، تلاحظ التفاصيل الصغيرة وتستمتع باكتشاف أسرار النباتات والحيوانات والعالم من حولها.',
      quoteAr: 'الفضول بذرة المعرفة، وكل سؤال فرصة للنمو.',
      speed: 87,
      knowledge: 93,
      focus: 94,
      confidence: 88,
    ),
    GameCharacter(
      index: 11,
      id: 'yazan',
      nameAr: 'يزن',
      tagAr: 'روح الإصرار',
      isFemale: false,
      color: Color(0xFF64C7B3),
      unlock: CharacterUnlock(CharacterUnlockKind.coins, 22000),
      assetExtension: 'webp',
      bioAr:
          'متسابق متفائل ومتمسك بجذوره، يخوض التحديات بإصرار ويحوّل كل جولة صعبة إلى فرصة جديدة للتقدم.',
      quoteAr: 'بالعزيمة والمعرفة نصل أبعد مما نتخيل.',
      speed: 91,
      knowledge: 90,
      focus: 92,
      confidence: 97,
    ),
    GameCharacter(
      index: 12,
      id: 'nour',
      nameAr: 'ريناد',
      tagAr: 'ملهمة الأمل',
      isFemale: true,
      color: Color(0xFF73C5EB),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 450),
      assetExtension: 'webp',
      bioAr:
          'رحالة محبة للثقافات والفنون، تحمل روحاً إيجابية وذاكرة غنية بالتجارب وتواجه المنافسة بابتسامة وثقة.',
      quoteAr: 'كل معرفة جديدة تفتح لنا نافذة أمل.',
      speed: 89,
      knowledge: 95,
      focus: 90,
      confidence: 96,
    ),
    GameCharacter(
      index: 13,
      id: 'zaid',
      nameAr: 'زيد',
      tagAr: 'روح الفريق',
      isFemale: false,
      color: Color(0xFFEC7865),
      unlock: CharacterUnlock(CharacterUnlockKind.level, 25),
      assetExtension: 'webp',
      bioAr:
          'مشجع حماسي وصاحب روح رياضية، يثق بفريقه ويحافظ على تركيزه في اللحظات الحاسمة ويحتفل بكل تقدم.',
      quoteAr: 'التعاون يصنع القوة، والإصرار يصنع الفوز.',
      speed: 94,
      knowledge: 87,
      focus: 93,
      confidence: 98,
    ),
    GameCharacter(
      index: 14,
      id: 'salman',
      nameAr: 'سلمان',
      tagAr: 'المبدع التقني',
      isFemale: false,
      color: Color(0xFF4ED8AA),
      unlock: CharacterUnlock(CharacterUnlockKind.gems, 650),
      assetExtension: 'webp',
      bioAr:
          'شغوف بالتقنية والابتكار، سريع في التقاط الأفكار ويحب حل الألغاز واستكشاف أحدث المعارف العلمية.',
      quoteAr: 'لكل تحدٍّ فكرة ذكية تنتظر من يكتشفها.',
      speed: 95,
      knowledge: 96,
      focus: 92,
      confidence: 94,
    ),
    GameCharacter(
      index: 15,
      id: 'adam',
      nameAr: 'آدم',
      tagAr: 'البطل الرياضي',
      isFemale: false,
      color: Color(0xFFFFAA56),
      unlock: CharacterUnlock(CharacterUnlockKind.coins, 16000),
      assetExtension: 'webp',
      bioAr:
          'رياضي نشيط ومحب للمنافسة، يجمع بين سرعة الاستجابة والانضباط، ويؤمن بأن التدريب والمثابرة أساس النجاح.',
      quoteAr: 'درّب عقلك كما تدرّب مهارتك، واستعد للتحدي.',
      speed: 97,
      knowledge: 85,
      focus: 94,
      confidence: 95,
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
