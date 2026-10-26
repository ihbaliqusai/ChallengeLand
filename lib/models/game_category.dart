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
    if (clean == 'أنمي' || clean == 'انمي') {
      return 'assets/categories/الأنمي.png';
    }
    return 'assets/categories/$clean.png';
  }

  static String normalize(String s) {
    final normalized = s
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('é', 'e')
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    // The store uses "أنمي" while the question pool uses "الأنمي".
    return const ['الانمي', 'الانيمي', 'انيمي'].contains(normalized)
        ? 'انمي'
        : normalized;
  }

  static int? rentalExpiryMillis(String category, Map<String, int> rentals) {
    final normalized = normalize(category);
    int? latestExpiry;
    for (final rental in rentals.entries) {
      if (normalize(rental.key) == normalized &&
          (latestExpiry == null || rental.value > latestExpiry)) {
        latestExpiry = rental.value;
      }
    }
    return latestExpiry;
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
    final expiry = rentalExpiryMillis(name, activeRentals);
    if (expiry != null && expiry > DateTime.now().millisecondsSinceEpoch) {
      return true;
    }
    return false;
  }

  int remainingRentalHours(Map<String, int> activeRentals) {
    final expiry = rentalExpiryMillis(name, activeRentals);
    if (expiry == null) return 0;
    final diffMs = expiry - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / (3600 * 1000)).ceil();
  }
}

class CategoryCatalog {
  CategoryCatalog._();

  static const List<GameCategory> premiumCategories = [
    GameCategory(name: 'أنمي', isPremium: true),
    GameCategory(name: 'سبيس تون', isPremium: true),
    GameCategory(name: 'مسلسل Friends', isPremium: true),
    GameCategory(name: 'أفلام أجنبية', isPremium: true),
    GameCategory(name: 'أفلام عربية', isPremium: true),
    GameCategory(name: 'مسلسلات أجنبية', isPremium: true),
    GameCategory(name: 'مسلسلات عربية', isPremium: true),
    GameCategory(name: 'خمن الصورة', isPremium: true),
    GameCategory(name: 'خمن الأغنية', isPremium: true),
    GameCategory(name: 'خمن الأكلة', isPremium: true),
    GameCategory(name: 'خمن الاسم', isPremium: true),
    GameCategory(name: 'خمن المدينة او الدولة', isPremium: true),
    GameCategory(name: 'زووم', isPremium: true),
    GameCategory(name: 'ركز شوي', isPremium: true),
    GameCategory(name: 'وضح شوي', isPremium: true),
    GameCategory(name: 'سيارات', isPremium: true),
    GameCategory(name: 'كأس العالم', isPremium: true),
    GameCategory(name: 'فنون وسينما', isPremium: true),
    GameCategory(name: 'فيروز', isPremium: true),
    GameCategory(name: 'كلثوميات', isPremium: true),
    GameCategory(name: 'معلومات عامة', isPremium: true),
    GameCategory(name: 'تاريخ', isPremium: true),
    GameCategory(name: 'رياضة', isPremium: true),
    GameCategory(name: 'لاعبين كرة قدم', isPremium: true),
    GameCategory(name: 'مسيرة لاعب', isPremium: true),
    GameCategory(name: 'علوم وفضاء', isPremium: true),
    GameCategory(name: 'ألغاز', isPremium: true),
    GameCategory(name: 'أمثال', isPremium: true),
    GameCategory(name: 'تقنية', isPremium: true),
    GameCategory(name: 'جسم الإنسان', isPremium: true),
    GameCategory(name: 'نباتات', isPremium: true),
    GameCategory(name: 'لغات', isPremium: true),
    GameCategory(name: 'صحة', isPremium: true),
    GameCategory(name: 'طعام وشراب', isPremium: true),
    GameCategory(name: 'سياحة وسفر', isPremium: true),
    GameCategory(name: 'سيرة ذاتية', isPremium: true),
    GameCategory(name: 'قصص الأنبياء', isPremium: true),
    GameCategory(name: 'منوعات', isPremium: true),
    GameCategory(name: 'دوري أبطال أوروبا', isPremium: true),
    GameCategory(name: 'NBA', isPremium: true),
    GameCategory(name: 'بنات وبس', isPremium: true),
    GameCategory(name: 'باب الحارة', isPremium: true),
    GameCategory(name: 'مسلسلات تركية', isPremium: true),
    GameCategory(name: 'دراما خليجية', isPremium: true),
    GameCategory(name: 'دراما سورية', isPremium: true),
    GameCategory(name: 'دراما مصرية', isPremium: true),
    GameCategory(name: 'Game Of Thrones', isPremium: true),
    GameCategory(name: 'Breaking Bad', isPremium: true),
    GameCategory(name: 'Harry Potter', isPremium: true),
    GameCategory(name: 'Pokémon', isPremium: true),
    GameCategory(name: 'Demon Slayer', isPremium: true),
    GameCategory(name: 'Hunter × Hunter', isPremium: true),
    GameCategory(name: 'One Piece', isPremium: true),
    GameCategory(name: 'Attack on Titan', isPremium: true),
    GameCategory(name: 'Naruto', isPremium: true),
  ];

  static const List<GameCategory> coreFreeCategories = [
    GameCategory(name: 'جغرافيا'),
    GameCategory(name: 'حيوانات'),
    GameCategory(name: 'دين واسلاميات'),
    GameCategory(name: 'عواصم'),
    GameCategory(name: 'دول'),
    GameCategory(name: 'اختراعات'),
    GameCategory(name: 'عملات'),
    GameCategory(name: 'لغة وادب'),
  ];

  static bool allowsAd(String category) {
    final name = GameCategory.normalize(category);
    if (!isCategoryPremium(category)) return false;
    return !const [
      'أنمي',
      'مسلسل Friends',
      'مسلسلات أجنبية',
      'مسلسلات عربية',
      'أفلام أجنبية',
      'أفلام عربية',
      'سبيس تون',
      'باب الحارة',
      'Game Of Thrones',
      'Breaking Bad',
      'Harry Potter',
      'Pokémon',
      'Demon Slayer',
      'Hunter × Hunter',
      'One Piece',
      'Attack on Titan',
      'Naruto',
    ].any((value) => GameCategory.normalize(value) == name);
  }

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
