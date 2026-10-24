import '../core/utils/date_utils.dart';

class GameSession {
  const GameSession({
    required this.id,
    required this.mode,
    this.roomId,
    required this.playerIds,
    required this.questionIds,
    required this.currentQuestionIndex,
    required this.status,
    required this.playerScores,
    required this.teamScores,
    required this.timerSeconds,
    this.startedAt,
    this.finishedAt,
    this.winnerId,
    this.winningTeamId,
  });

  final String id;
  final String mode;
  final String? roomId;
  final List<String> playerIds;
  final List<String> questionIds;
  final int currentQuestionIndex;
  final String status;
  final Map<String, int> playerScores;
  final Map<String, int> teamScores;
  final int timerSeconds;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? winnerId;
  final String? winningTeamId;

  bool get isFinished => status == 'finished';

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id']?.toString() ?? '',
    mode: json['mode']?.toString() ?? 'quick_1v1',
    roomId: json['roomId']?.toString(),
    playerIds: (json['playerIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    questionIds: (json['questionIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    currentQuestionIndex: (json['currentQuestionIndex'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'waiting',
    playerScores: _intMap(json['playerScores']),
    teamScores: _intMap(json['teamScores']),
    timerSeconds: (json['timerSeconds'] as num?)?.toInt() ?? 15,
    startedAt: ChallengeDateUtils.parse(json['startedAt']),
    finishedAt: ChallengeDateUtils.parse(json['finishedAt']),
    winnerId: json['winnerId']?.toString(),
    winningTeamId: json['winningTeamId']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'roomId': roomId,
    'playerIds': playerIds,
    'questionIds': questionIds,
    'currentQuestionIndex': currentQuestionIndex,
    'status': status,
    'playerScores': playerScores,
    'teamScores': teamScores,
    'timerSeconds': timerSeconds,
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'winnerId': winnerId,
    'winningTeamId': winningTeamId,
  };

  GameSession copyWith({
    String? id,
    String? mode,
    String? roomId,
    List<String>? playerIds,
    List<String>? questionIds,
    int? currentQuestionIndex,
    String? status,
    Map<String, int>? playerScores,
    Map<String, int>? teamScores,
    int? timerSeconds,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? winnerId,
    String? winningTeamId,
  }) {
    return GameSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      roomId: roomId ?? this.roomId,
      playerIds: playerIds ?? this.playerIds,
      questionIds: questionIds ?? this.questionIds,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      status: status ?? this.status,
      playerScores: playerScores ?? this.playerScores,
      teamScores: teamScores ?? this.teamScores,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      winnerId: winnerId ?? this.winnerId,
      winningTeamId: winningTeamId ?? this.winningTeamId,
    );
  }

  static Map<String, int> _intMap(dynamic source) {
    if (source is! Map) return const {};
    return source.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }
}
