/// Display catalog only. Prices come from Google Play and rewards are verified
/// against the authoritative server catalog before delivery.
enum StoreProductKind {
  gems,
  coins,
  bundle,
  subscription,
  categoryPass,
  resource
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.coins = 0,
    this.gems = 0,
    this.keys = 0,
    this.tickets = 0,
    this.hearts = 0,
    this.oneTime = false,
    this.featured = false,
    this.badge = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final StoreProductKind kind;
  final int coins;
  final int gems;
  final int keys;
  final int tickets;
  final int hearts;
  final bool oneTime;
  final bool featured;
  final String badge;
}

class CoinExchange {
  const CoinExchange(
      {required this.id, required this.coins, required this.gemCost});
  final String id;
  final int coins;
  final int gemCost;
}

abstract final class StoreCatalog {
  static const products = <StoreProduct>[
    StoreProduct(
        id: 'resources_3_each',
        title: 'باقة اللعب',
        subtitle: '3 مفاتيح + 3 تذاكر + 3 قلوب إضافية',
        kind: StoreProductKind.resource,
        keys: 3,
        tickets: 3,
        hearts: 3),
    StoreProduct(
        id: 'resources_10_each',
        title: 'باقة اللعب الكبيرة',
        subtitle: '10 مفاتيح + 10 تذاكر + 10 قلوب إضافية',
        kind: StoreProductKind.resource,
        keys: 10,
        tickets: 10,
        hearts: 10),
    StoreProduct(
        id: 'keys_1',
        title: 'مفتاح واحد',
        subtitle: 'مفتاح إضافي مقابل مشاهدة إعلان',
        kind: StoreProductKind.resource,
        keys: 1),
    StoreProduct(
        id: 'hearts_1',
        title: 'قلب واحد',
        subtitle: 'محاولة إضافية مقابل مشاهدة إعلان',
        kind: StoreProductKind.resource,
        hearts: 1),
    StoreProduct(
        id: 'tickets_1',
        title: 'تذكرة واحدة',
        subtitle: 'تذكرة تصنيف مقابل مشاهدة إعلان',
        kind: StoreProductKind.resource,
        tickets: 1),
    StoreProduct(
        id: 'keys_10',
        title: '10 مفاتيح',
        subtitle: '10 مفاتيح إضافية محفوظة لدخول التحديات',
        kind: StoreProductKind.resource,
        keys: 10),
    StoreProduct(
        id: 'hearts_10',
        title: '10 قلوب',
        subtitle: '10 قلوب إضافية محفوظة لتحدي المراحل',
        kind: StoreProductKind.resource,
        hearts: 10),
    StoreProduct(
        id: 'tickets_10',
        title: '10 تذاكر',
        subtitle: '10 تذاكر لفتح أي تصنيف لمباراة واحدة',
        kind: StoreProductKind.resource,
        tickets: 10),
    StoreProduct(
        id: 'pack_starter',
        title: 'بداية المغامرة',
        subtitle: 'جواهر وعملات لبداية مريحة • مرة واحدة لكل حساب',
        kind: StoreProductKind.bundle,
        coins: 10000,
        gems: 100,
        oneTime: true,
        featured: true,
        badge: 'باقة البداية'),
    StoreProduct(
        id: 'pack_value',
        title: 'عدة المستكشف',
        subtitle: 'افتح فئاتك المفضلة وطوّر مجموعتك',
        kind: StoreProductKind.bundle,
        coins: 35000,
        gems: 600,
        featured: true,
        badge: 'باقة متوازنة'),
    StoreProduct(
        id: 'pack_champion',
        title: 'خزينة الأبطال',
        subtitle: 'مجموعة كبيرة لمغامراتك القادمة',
        kind: StoreProductKind.bundle,
        coins: 100000,
        gems: 1800,
        badge: 'الخزينة الكبرى'),
    StoreProduct(
        id: 'gems_80',
        title: 'كيس الجواهر',
        subtitle: 'شحنة صغيرة لاختيارك القادم',
        kind: StoreProductKind.gems,
        gems: 80),
    StoreProduct(
        id: 'gems_500',
        title: 'صندوق الجواهر',
        subtitle: 'خيارات أكثر للفئات والشخصيات',
        kind: StoreProductKind.gems,
        gems: 500),
    StoreProduct(
        id: 'gems_1200',
        title: 'خزينة الجواهر',
        subtitle: 'رصيد كبير لتوسيع مجموعتك',
        kind: StoreProductKind.gems,
        gems: 1200),
    StoreProduct(
        id: 'coins_5000',
        title: 'كيس العملات',
        subtitle: 'عملات مباشرة دون تحويل الجواهر',
        kind: StoreProductKind.coins,
        coins: 5000),
    StoreProduct(
        id: 'coins_25000',
        title: 'صندوق العملات',
        subtitle: 'جهّز رصيدك للشخصيات والمغامرات',
        kind: StoreProductKind.coins,
        coins: 25000),
    StoreProduct(
        id: 'coins_100000',
        title: 'خزينة العملات',
        subtitle: 'أكبر حزمة عملات مباشرة',
        kind: StoreProductKind.coins,
        coins: 100000),
    StoreProduct(
        id: 'vip_monthly',
        title: 'عضوية نادي الأبطال',
        subtitle:
            '100 جوهرة + 1000 قطعة + 3 مفاتيح وتذاكر وقلوب مع كل مزايا VIP',
        kind: StoreProductKind.subscription,
        coins: 1000,
        gems: 100,
        keys: 3,
        tickets: 3,
        hearts: 3,
        featured: true,
        badge: 'عضوية الأبطال VIP'),
    StoreProduct(
        id: 'category_all_access',
        title: 'مكتبة الفئات الكاملة',
        subtitle: 'فتح دائم للفئات المميزة • دفعة واحدة',
        kind: StoreProductKind.categoryPass,
        oneTime: true,
        badge: 'امتلاك دائم'),
  ];

  static const coinExchanges = <CoinExchange>[
    CoinExchange(id: 'exchange_1500', coins: 1500, gemCost: 15),
    CoinExchange(id: 'exchange_6000', coins: 6000, gemCost: 55),
    CoinExchange(id: 'exchange_14000', coins: 14000, gemCost: 120),
    CoinExchange(id: 'exchange_35000', coins: 35000, gemCost: 290),
    CoinExchange(id: 'exchange_90000', coins: 90000, gemCost: 700),
  ];

  static String canonicalId(String id) {
    final normalized = id.replaceAll('_', '').toLowerCase();
    if (normalized == 'vippass') return 'vip_monthly';
    for (final product in products) {
      if (product.id.replaceAll('_', '') == normalized) return product.id;
    }
    return id;
  }

  static StoreProduct? byId(String id) {
    final canonical = canonicalId(id);
    for (final product in products) {
      if (product.id == canonical) return product;
    }
    return null;
  }
}
