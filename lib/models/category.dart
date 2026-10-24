import '../core/utils/date_utils.dart';

class Category {
  const Category({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.iconUrl,
    required this.color,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String? iconUrl;
  final String color;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? '',
    titleAr: json['titleAr']?.toString() ?? '',
    titleEn: json['titleEn']?.toString() ?? '',
    iconUrl: json['iconUrl']?.toString(),
    color: json['color']?.toString() ?? '#2563EB',
    isActive: json['isActive'] != false,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    createdAt: ChallengeDateUtils.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'iconUrl': iconUrl,
    'color': color,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'createdAt': createdAt?.toIso8601String(),
  };

  Category copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    String? iconUrl,
    String? color,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      iconUrl: iconUrl ?? this.iconUrl,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
