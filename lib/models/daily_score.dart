import '../core/utils/date_utils.dart';

class DailyScore {
  const DailyScore({
    required this.id,
    required this.uid,
    required this.username,
    required this.dateKey,
    required this.score,
    required this.correctAnswers,
    required this.timeSpentSeconds,
    this.submittedAt,
  });

  final String id;
  final String uid;
  final String username;
  final String dateKey;
  final int score;
  final int correctAnswers;
  final int timeSpentSeconds;
  final DateTime? submittedAt;

  factory DailyScore.fromJson(Map<String, dynamic> json) => DailyScore(
    id: json['id']?.toString() ?? '',
    uid: json['uid']?.toString() ?? '',
    username: json['username']?.toString() ?? 'لاعب',
    dateKey: json['dateKey']?.toString() ?? '',
    score: (json['score'] as num?)?.toInt() ?? 0,
    correctAnswers: (json['correctAnswers'] as num?)?.toInt() ?? 0,
    timeSpentSeconds: (json['timeSpentSeconds'] as num?)?.toInt() ?? 0,
    submittedAt: ChallengeDateUtils.parse(json['submittedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'username': username,
    'dateKey': dateKey,
    'score': score,
    'correctAnswers': correctAnswers,
    'timeSpentSeconds': timeSpentSeconds,
    'submittedAt': submittedAt?.toIso8601String(),
  };

  DailyScore copyWith({
    String? id,
    String? uid,
    String? username,
    String? dateKey,
    int? score,
    int? correctAnswers,
    int? timeSpentSeconds,
    DateTime? submittedAt,
  }) {
    return DailyScore(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      dateKey: dateKey ?? this.dateKey,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
