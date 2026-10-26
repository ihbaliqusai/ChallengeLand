import 'package:challenge_land/models/game_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free catalog and ad restrictions match the economy access policy', () {
    expect(CategoryCatalog.coreFreeCategories, hasLength(8));
    expect(CategoryCatalog.allowsAd('رياضة'), isTrue);
    for (final name in [
      'الأنيمي',
      'مسلسل Friends',
      'سبيس تون',
      'أفلام عربية'
    ]) {
      expect(CategoryCatalog.isCategoryPremium(name), isTrue);
      expect(CategoryCatalog.allowsAd(name), isFalse);
    }
    for (final category in CategoryCatalog.coreFreeCategories) {
      expect(CategoryCatalog.isCategoryPremium(category.name), isFalse);
      expect(CategoryCatalog.allowsAd(category.name), isFalse);
    }
  });

  test('new categories are properly integrated into CategoryCatalog', () {
    expect(CategoryCatalog.premiumCategories, hasLength(55));
    const newCategories = [
      'دوري أبطال أوروبا',
      'NBA',
      'بنات وبس',
      'باب الحارة',
      'مسلسلات تركية',
      'دراما خليجية',
      'دراما سورية',
      'دراما مصرية',
      'Game Of Thrones',
      'Breaking Bad',
      'Harry Potter',
      'Pokémon',
      'Demon Slayer',
      'Hunter × Hunter',
      'One Piece',
      'Attack on Titan',
      'Naruto',
    ];
    for (final name in newCategories) {
      expect(CategoryCatalog.isCategoryPremium(name), isTrue, reason: name);
      final cat = GameCategory(name: name, isPremium: true);
      expect(cat.assetPath, 'assets/categories/$name.png');
    }
    expect(GameCategory.normalize('Pokémon'), 'pokemon');
    expect(GameCategory.normalize('Hunter × Hunter'), 'hunter x hunter');
    expect(GameCategory.normalize('Hunter x Hunter'), 'hunter x hunter');
    expect(CategoryCatalog.allowsAd('دوري أبطال أوروبا'), isTrue);
    expect(CategoryCatalog.allowsAd('NBA'), isTrue);
    expect(CategoryCatalog.allowsAd('بنات وبس'), isTrue);
    expect(CategoryCatalog.allowsAd('باب الحارة'), isFalse);
    expect(CategoryCatalog.allowsAd('One Piece'), isFalse);
    expect(CategoryCatalog.allowsAd('Naruto'), isFalse);
  });
  const aliases = ['أنمي', 'الأنمي', 'انمي', 'الانمي'];

  test('anime store and question labels share the same canonical category', () {
    for (final label in aliases) {
      expect(GameCategory.normalize(' $label '), 'انمي');
      expect(CategoryCatalog.isCategoryPremium(label), isTrue);
    }
    expect(GameCategory.normalize(' الأفلام العربية '), 'الافلام العربيه');
    expect(GameCategory.normalize('أفلام عربية'), 'افلام عربيه');
    expect(CategoryCatalog.isCategoryPremium('معلومات عامة'), isTrue);
    expect(CategoryCatalog.isCategoryPremium('جغرافيا'), isFalse);
  });

  for (final label in ['أنمي', 'الأنمي']) {
    final category = GameCategory(
      name: label,
      isPremium: CategoryCatalog.isCategoryPremium(label),
    );

    test('$label remains locked without an account purchase or active rental',
        () {
      expect(category.isUnlocked(permanentlyUnlocked: [], activeRentals: {}),
          isFalse);
      expect(
          category.isUnlocked(
            permanentlyUnlocked: ['سيارات'],
            activeRentals: {
              'سيارات': DateTime.now()
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch
            },
          ),
          isFalse);
    });

    test('$label honours purchases saved under any existing anime spelling',
        () {
      for (final savedLabel in aliases) {
        expect(
            category.isUnlocked(
              permanentlyUnlocked: [savedLabel],
              activeRentals: {},
            ),
            isTrue,
            reason: savedLabel);
      }
    });

    test('$label honours rentals saved under raw and legacy normalized keys',
        () {
      final expiry =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
      for (final savedKey in aliases) {
        final rentals = {savedKey: expiry};
        expect(
            category.isUnlocked(
              permanentlyUnlocked: [],
              activeRentals: rentals,
            ),
            isTrue,
            reason: savedKey);
        expect(category.remainingRentalHours(rentals), 2, reason: savedKey);
        expect(GameCategory.rentalExpiryMillis(label, rentals), expiry);
      }
    });

    test('$label expired rentals do not grant access', () {
      final expired = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      expect(
          category.isUnlocked(
            permanentlyUnlocked: [],
            activeRentals: {'الانمي': expired},
          ),
          isFalse);
      expect(category.remainingRentalHours({'الانمي': expired}), 0);
    });
  }

  test('duplicate saved aliases preserve the longest valid rental', () {
    final shortExpiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final longExpiry =
        DateTime.now().add(const Duration(hours: 4)).millisecondsSinceEpoch;
    expect(
        GameCategory.rentalExpiryMillis('الأنمي', {
          'انمي': shortExpiry,
          'الانمي': longExpiry,
        }),
        longExpiry);
  });
}
