import '../core/utils/date_utils.dart';

class Question {
  const Question({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.questionText,
    required this.correctAnswer,
    required this.options,
    this.explanation,
    this.mediaUrl,
    required this.points,
    required this.difficulty,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String type;
  final String questionText;
  final String correctAnswer;
  final List<String> options;
  final String? explanation;
  final String? mediaUrl;
  final int points;
  final String difficulty;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool isCorrect(String answer) =>
      answer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id']?.toString() ?? '',
    categoryId: json['categoryId']?.toString() ?? '',
    type: json['type']?.toString() ?? 'multiple_choice',
    questionText: json['questionText']?.toString() ?? '',
    correctAnswer: json['correctAnswer']?.toString() ?? '',
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    explanation: json['explanation']?.toString(),
    mediaUrl: json['mediaUrl']?.toString(),
    points: (json['points'] as num?)?.toInt() ?? 100,
    difficulty: json['difficulty']?.toString() ?? 'easy',
    isActive: json['isActive'] != false,
    createdAt: ChallengeDateUtils.parse(json['createdAt']),
    updatedAt: ChallengeDateUtils.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'type': type,
    'questionText': questionText,
    'correctAnswer': correctAnswer,
    'options': options,
    'explanation': explanation,
    'mediaUrl': mediaUrl,
    'points': points,
    'difficulty': difficulty,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Question copyWith({
    String? id,
    String? categoryId,
    String? type,
    String? questionText,
    String? correctAnswer,
    List<String>? options,
    String? explanation,
    String? mediaUrl,
    int? points,
    String? difficulty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      questionText: questionText ?? this.questionText,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      explanation: explanation ?? this.explanation,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      points: points ?? this.points,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
