class GameCategory {
  const GameCategory({
    required this.name,
    this.isPremium = false,
    this.gemCost = 150,
    this.tag = '',
  });

  final String name;
  final bool isPremium;
  final int gemCost;
  final String tag;

  String get assetPath {
    final clean = name.trim();
    if (clean == 'كأس العالم') return 'assets/categories/كأس العالم.png';
    if (clean == 'أنمي' || clean == 'انمي') return 'assets/categories/الأنمي.png';
    return 'assets/categories/$clean.png';
  }

  static String normalize(String s) {
    return s
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  bool isUnlocked({
    required List<String> permanentlyUnlocked,
    required Map<String, int> activeRentals,
    bool isVip = false,
  }) {
    if (!isPremium || isVip) return true;
    final norm = normalize(name);
    for (final item in permanentlyUnlocked) {
      if (normalize(item) == norm) return true;
    }
    final expiry = activeRentals[norm];
    if (expiry != null && expiry > DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    return false;
  }

  int remainingRentalHours(Map<String, int> activeRentals) {
    final norm = normalize(name);
    final expiry = activeRentals[norm];
    if (expiry == null) return 0;
    final diffMs = expiry - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / (3600 * 1000)).ceil();
  }
}

class CategoryCatalog {
  CategoryCatalog._();

  static const List<GameCategory> premiumCategories = <GameCategory>[
    GameCategory(name: 'أنمي', isPremium: true, tag: 'شائع'),
    GameCategory(name: 'سبيس تون', isPremium: true, tag: 'ذكريات'),
    GameCategory(name: 'مسلسل Friends', isPremium: true, tag: 'ترند'),
    GameCategory(name: 'أفلام أجنبية', isPremium: true, tag: 'سينما'),
    GameCategory(name: 'أفلام عربية', isPremium: true, tag: 'سينما'),
    GameCategory(name: 'مسلسلات أجنبية', isPremium: true, tag: 'دراما'),
    GameCategory(name: 'مسلسلات عربية', isPremium: true, tag: 'دراما'),
    GameCategory(name: 'خمن الصورة', isPremium: true, tag: 'بصري'),
    GameCategory(name: 'خمن الأغنية', isPremium: true, tag: 'صوتي'),
    GameCategory(name: 'خمن الأكلة', isPremium: true, tag: 'بصري'),
    GameCategory(name: 'خمن الاسم', isPremium: true, tag: 'تحدي'),
    GameCategory(name: 'خمن المدينة او الدولة', isPremium: true, tag: 'جغرافيا'),
    GameCategory(name: 'زووم', isPremium: true, tag: 'دقة'),
    GameCategory(name: 'ركز شوي', isPremium: true, tag: 'ذكاء'),
    GameCategory(name: 'وضح شوي', isPremium: true, tag: 'ذكاء'),
    GameCategory(name: 'سيارات', isPremium: true, tag: 'سرعة'),
    GameCategory(name: 'كأس العالم', isPremium: true, tag: 'رياضة'),
    GameCategory(name: 'فنون وسينما', isPremium: true, tag: 'ثقافة'),
    GameCategory(name: 'فيروز', isPremium: true, tag: 'طرب'),
    GameCategory(name: 'كلثوميات', isPremium: true, tag: 'طرب'),
  ];

  static const List<GameCategory> coreFreeCategories = <GameCategory>[
    GameCategory(name: 'معلومات عامة'),
    GameCategory(name: 'تاريخ'),
    GameCategory(name: 'جغرافيا'),
    GameCategory(name: 'رياضة'),
    GameCategory(name: 'دين واسلاميات'),
    GameCategory(name: 'علوم وفضاء'),
    GameCategory(name: 'ألغاز'),
    GameCategory(name: 'أمثال'),
    GameCategory(name: 'تقنية'),
    GameCategory(name: 'جسم الإنسان'),
    GameCategory(name: 'حيوانات'),
    GameCategory(name: 'نباتات'),
    GameCategory(name: 'دول'),
    GameCategory(name: 'عواصم'),
    GameCategory(name: 'عملات'),
    GameCategory(name: 'لغات'),
    GameCategory(name: 'لغة وادب'),
    GameCategory(name: 'صحة'),
    GameCategory(name: 'طعام وشراب'),
    GameCategory(name: 'سياحة وسفر'),
    GameCategory(name: 'سيرة ذاتية'),
    GameCategory(name: 'قصص الأنبياء'),
    GameCategory(name: 'اختراعات'),
    GameCategory(name: 'منوعات'),
  ];

  static bool isCategoryPremium(String category) {
    final norm = GameCategory.normalize(category);
    for (final cat in premiumCategories) {
      if (GameCategory.normalize(cat.name) == norm) {
        return true;
      }
    }
    return false;
  }
}
