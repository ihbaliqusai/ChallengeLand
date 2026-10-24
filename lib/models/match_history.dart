import '../core/utils/date_utils.dart';

class MatchHistory {
  const MatchHistory({
    required this.id,
    required this.uid,
    required this.mode,
    required this.score,
    required this.opponentName,
    required this.result,
    required this.correctAnswers,
    required this.wrongAnswers,
    this.playedAt,
  });

  final String id;
  final String uid;
  final String mode;
  final int score;
  final String opponentName;
  final String result;
  final int correctAnswers;
  final int wrongAnswers;
  final DateTime? playedAt;

  factory MatchHistory.fromJson(Map<String, dynamic> json) => MatchHistory(
    id: json['id']?.toString() ?? '',
    uid: json['uid']?.toString() ?? '',
    mode: json['mode']?.toString() ?? 'quick_1v1',
    score: (json['score'] as num?)?.toInt() ?? 0,
    opponentName: json['opponentName']?.toString() ?? 'منافس',
    result: json['result']?.toString() ?? 'draw',
    correctAnswers: (json['correctAnswers'] as num?)?.toInt() ?? 0,
    wrongAnswers: (json['wrongAnswers'] as num?)?.toInt() ?? 0,
    playedAt: ChallengeDateUtils.parse(json['playedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'mode': mode,
    'score': score,
    'opponentName': opponentName,
    'result': result,
    'correctAnswers': correctAnswers,
    'wrongAnswers': wrongAnswers,
    'playedAt': playedAt?.toIso8601String(),
  };

  MatchHistory copyWith({
    String? id,
    String? uid,
    String? mode,
    int? score,
    String? opponentName,
    String? result,
    int? correctAnswers,
    int? wrongAnswers,
    DateTime? playedAt,
  }) {
    return MatchHistory(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      mode: mode ?? this.mode,
      score: score ?? this.score,
      opponentName: opponentName ?? this.opponentName,
      result: result ?? this.result,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      playedAt: playedAt ?? this.playedAt,
    );
  }
}
