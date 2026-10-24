import '../core/utils/date_utils.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.dateKey,
    required this.questionIds,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String dateKey;
  final List<String> questionIds;
  final bool isActive;
  final DateTime? createdAt;

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
    id: json['id']?.toString() ?? '',
    dateKey: json['dateKey']?.toString() ?? '',
    questionIds: (json['questionIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    isActive: json['isActive'] != false,
    createdAt: ChallengeDateUtils.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateKey': dateKey,
    'questionIds': questionIds,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
  };

  DailyChallenge copyWith({
    String? id,
    String? dateKey,
    List<String>? questionIds,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DailyChallenge(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      questionIds: questionIds ?? this.questionIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
