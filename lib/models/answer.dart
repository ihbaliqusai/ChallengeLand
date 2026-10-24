import '../core/utils/date_utils.dart';

class Answer {
  const Answer({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.uid,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.score,
    required this.remainingTime,
    required this.answeredAt,
  });

  final String id;
  final String sessionId;
  final String questionId;
  final String uid;
  final String selectedAnswer;
  final bool isCorrect;
  final int score;
  final int remainingTime;
  final DateTime answeredAt;

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
    id: json['id']?.toString() ?? '',
    sessionId: json['sessionId']?.toString() ?? '',
    questionId: json['questionId']?.toString() ?? '',
    uid: json['uid']?.toString() ?? '',
    selectedAnswer: json['selectedAnswer']?.toString() ?? '',
    isCorrect: json['isCorrect'] == true,
    score: (json['score'] as num?)?.toInt() ?? 0,
    remainingTime: (json['remainingTime'] as num?)?.toInt() ?? 0,
    answeredAt:
        ChallengeDateUtils.parse(json['answeredAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'questionId': questionId,
    'uid': uid,
    'selectedAnswer': selectedAnswer,
    'isCorrect': isCorrect,
    'score': score,
    'remainingTime': remainingTime,
    'answeredAt': answeredAt.toIso8601String(),
  };

  Answer copyWith({
    String? id,
    String? sessionId,
    String? questionId,
    String? uid,
    String? selectedAnswer,
    bool? isCorrect,
    int? score,
    int? remainingTime,
    DateTime? answeredAt,
  }) {
    return Answer(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      uid: uid ?? this.uid,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      score: score ?? this.score,
      remainingTime: remainingTime ?? this.remainingTime,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }
}
