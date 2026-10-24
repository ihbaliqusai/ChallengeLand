enum ChallengeCardType {
  describe, // وصف
  act, // تمثيل
  letter, // حرف
  question, // سؤال
  link, // رابط
}

enum ChallengeDifficulty {
  easy, // سهل
  medium, // متوسط
  hard, // صعب
}

class ChallengeCard {
  const ChallengeCard({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.difficulty,
    required this.points,
    required this.mainContent,
    this.tabooWords = const [],
    this.validAnswers = const [],
    this.linkWords = const [],
    this.linkAnswer,
    this.hint,
    this.isActive = true,
  });

  final String id;
  final ChallengeCardType type;
  final String categoryId;
  final String categoryName;
  final ChallengeDifficulty difficulty;
  final int points;

  // الحقل الرئيسي: الكلمة (وصف/تمثيل) أو السؤال أو "اذكر شيئاً..." (حرف)
  final String mainContent;

  // للوصف فقط: الكلمات الممنوع ذكرها
  final List<String> tabooWords;

  // للسؤال والحرف: الإجابات المقبولة (أول عنصر = الإجابة الكنونية)
  final List<String> validAnswers;

  // للرابط فقط: الكلمات الأربع
  final List<String> linkWords;

  // للرابط فقط: الرابط المشترك
  final String? linkAnswer;

  final String? hint;
  final bool isActive;

  // ===== Static Maps =====

  static const Map<String, String> categoryNames = {
    'movies_tv': 'أفلام وتلفزيون',
    'sports': 'رياضة',
    'arabic_culture': 'ثقافة عربية',
    'food': 'أكل',
    'celebrities': 'مشاهير',
    'geography': 'جغرافيا',
    'science': 'علوم',
    'puzzles': 'ألغاز',
  };

  static const Map<String, String> categoryEmojis = {
    'movies_tv': '🎬',
    'sports': '⚽',
    'arabic_culture': '🕌',
    'food': '🍽️',
    'celebrities': '⭐',
    'geography': '🌍',
    'science': '🔬',
    'puzzles': '🧩',
  };

  static const Map<String, String> typeNamesAr = {
    'describe': 'وصف',
    'act': 'تمثيل',
    'letter': 'حرف',
    'question': 'سؤال',
    'link': 'رابط',
  };

  static const Map<String, String> typeEmojis = {
    'describe': '💬',
    'act': '🎭',
    'letter': '🔤',
    'question': '❓',
    'link': '🔗',
  };

  // ===== Computed Properties =====

  String get typeNameAr => typeNamesAr[type.name] ?? type.name;
  String get typeEmoji => typeEmojis[type.name] ?? '🎯';
  String get categoryEmoji => categoryEmojis[categoryId] ?? '📌';

  String get difficultyNameAr {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 'سهل';
      case ChallengeDifficulty.medium:
        return 'متوسط';
      case ChallengeDifficulty.hard:
        return 'صعب';
    }
  }

  int get difficultyStars {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 1;
      case ChallengeDifficulty.medium:
        return 2;
      case ChallengeDifficulty.hard:
        return 3;
    }
  }

  // ===== Answer Validation =====

  // للسؤال والحرف: هل الإجابة صحيحة؟
  bool isCorrectAnswer(String answer) {
    if (validAnswers.isEmpty) return false;
    final normalized = _normalize(answer);
    return validAnswers.any((va) => _normalize(va) == normalized);
  }

  // للرابط: هل الرابط صحيح؟
  bool isCorrectLinkAnswer(String answer) {
    if (linkAnswer == null || linkAnswer!.isEmpty) return false;
    return _normalize(answer) == _normalize(linkAnswer!);
  }

  // تطبيع النص العربي: إزالة التشكيل وتوحيد الحروف
  String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        // توحيد أشكال الألف
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        // توحيد التاء المربوطة والهاء
        .replaceAll(RegExp(r'[ةه]'), 'ه')
        // توحيد الياء
        .replaceAll(RegExp(r'[يى]'), 'ي')
        // إزالة التشكيل
        .replaceAll(RegExp(r'[ً-ٟ]'), '')
        // تقليص المسافات
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ===== Serialization =====

  factory ChallengeCard.fromJson(Map<String, dynamic> json) {
    return ChallengeCard(
      id: json['id']?.toString() ?? '',
      type: _parseType(json['type']?.toString() ?? ''),
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      difficulty: _parseDifficulty(json['difficulty']?.toString() ?? ''),
      points: (json['points'] as num?)?.toInt() ?? 2,
      mainContent: json['mainContent']?.toString() ?? '',
      tabooWords: _parseStringList(json['tabooWords']),
      validAnswers: _parseStringList(json['validAnswers']),
      linkWords: _parseStringList(json['linkWords']),
      linkAnswer: json['linkAnswer']?.toString(),
      hint: json['hint']?.toString(),
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'difficulty': difficulty.name,
    'points': points,
    'mainContent': mainContent,
    'tabooWords': tabooWords,
    'validAnswers': validAnswers,
    'linkWords': linkWords,
    'linkAnswer': linkAnswer,
    'hint': hint,
    'isActive': isActive,
  };

  ChallengeCard copyWith({
    String? id,
    ChallengeCardType? type,
    String? categoryId,
    String? categoryName,
    ChallengeDifficulty? difficulty,
    int? points,
    String? mainContent,
    List<String>? tabooWords,
    List<String>? validAnswers,
    List<String>? linkWords,
    String? linkAnswer,
    String? hint,
    bool? isActive,
  }) {
    return ChallengeCard(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      mainContent: mainContent ?? this.mainContent,
      tabooWords: tabooWords ?? this.tabooWords,
      validAnswers: validAnswers ?? this.validAnswers,
      linkWords: linkWords ?? this.linkWords,
      linkAnswer: linkAnswer ?? this.linkAnswer,
      hint: hint ?? this.hint,
      isActive: isActive ?? this.isActive,
    );
  }

  // ===== Private Helpers =====

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    return (raw as List<dynamic>)
        .map((e) => e.toString())
        .toList(growable: false);
  }

  static ChallengeCardType _parseType(String s) {
    switch (s) {
      case 'describe':
        return ChallengeCardType.describe;
      case 'act':
        return ChallengeCardType.act;
      case 'letter':
        return ChallengeCardType.letter;
      case 'question':
        return ChallengeCardType.question;
      case 'link':
        return ChallengeCardType.link;
      default:
        return ChallengeCardType.question;
    }
  }

  static ChallengeDifficulty _parseDifficulty(String s) {
    switch (s) {
      case 'easy':
        return ChallengeDifficulty.easy;
      case 'medium':
        return ChallengeDifficulty.medium;
      case 'hard':
        return ChallengeDifficulty.hard;
      default:
        return ChallengeDifficulty.easy;
    }
  }
}
