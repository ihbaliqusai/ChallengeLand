import 'challenge_card.dart';
import 'player_role.dart';

/// الحالة الحية للغرفة من Firebase Realtime Database.
/// الهيكل في RTDB:
///   /rooms/{roomId}/state        → LiveRoomState.state fields
///   /rooms/{roomId}/players/{uid} → PlayerLiveState
///   /rooms/{roomId}/answers/{uid} → AnswerState
///   /rooms/{roomId}/currentCard   → ChallengeCard
///   /rooms/{roomId}/hostUid       → String
class LiveRoomState {
  const LiveRoomState({
    required this.phase,
    required this.currentRound,
    required this.roundDuration,
    this.currentDescriber,
    this.roundStartedAt,
    this.players = const {},
    this.answers = const {},
    this.currentCard,
    this.hostUid,
  });

  final GamePhase phase;
  final int currentRound;
  final int roundDuration;
  final String? currentDescriber;
  final int? roundStartedAt; // epoch ms (ServerValue.timestamp)

  final Map<String, PlayerLiveState> players;
  final Map<String, AnswerState> answers;
  final ChallengeCard? currentCard;
  final String? hostUid;

  bool get isRoundActive =>
      phase == GamePhase.describing || phase == GamePhase.guessing;

  int get onlineCount => players.values.where((p) => p.isOnline).length;
  int get readyCount => players.values.where((p) => p.isReady).length;

  factory LiveRoomState.fromRtdbMap(Map<String, dynamic> map) {
    final stateMap = _asMap(map['state']);
    final playersMap = _asMap(map['players']);
    final answersMap = _asMap(map['answers']);
    final cardMap = _asMap(map['currentCard']);

    return LiveRoomState(
      phase: GamePhaseX.fromString(stateMap['phase']?.toString() ?? 'lobby'),
      currentRound: (stateMap['currentRound'] as num?)?.toInt() ?? 0,
      roundDuration: (stateMap['roundDuration'] as num?)?.toInt() ?? 60,
      currentDescriber: stateMap['currentDescriber']?.toString(),
      roundStartedAt: (stateMap['roundStartedAt'] as num?)?.toInt(),
      players: playersMap.map(
        (uid, val) => MapEntry(uid, PlayerLiveState.fromRtdbMap(_asMap(val))),
      ),
      answers: answersMap.map(
        (uid, val) => MapEntry(uid, AnswerState.fromRtdbMap(_asMap(val))),
      ),
      currentCard: cardMap.isEmpty ? null : ChallengeCard.fromJson(cardMap),
      hostUid: map['hostUid']?.toString(),
    );
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  LiveRoomState copyWith({
    GamePhase? phase,
    int? currentRound,
    int? roundDuration,
    String? currentDescriber,
    int? roundStartedAt,
    Map<String, PlayerLiveState>? players,
    Map<String, AnswerState>? answers,
    ChallengeCard? currentCard,
    String? hostUid,
  }) {
    return LiveRoomState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      roundDuration: roundDuration ?? this.roundDuration,
      currentDescriber: currentDescriber ?? this.currentDescriber,
      roundStartedAt: roundStartedAt ?? this.roundStartedAt,
      players: players ?? this.players,
      answers: answers ?? this.answers,
      currentCard: currentCard ?? this.currentCard,
      hostUid: hostUid ?? this.hostUid,
    );
  }
}

/// حضور اللاعب الفوري في الجلسة.
class PlayerLiveState {
  const PlayerLiveState({
    required this.isOnline,
    required this.isReady,
    required this.lastSeen,
  });

  final bool isOnline;
  final bool isReady;
  final int lastSeen; // epoch ms

  factory PlayerLiveState.fromRtdbMap(Map<String, dynamic> map) {
    return PlayerLiveState(
      isOnline: map['isOnline'] == true,
      isReady: map['isReady'] == true,
      lastSeen: (map['lastSeen'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toRtdbMap() => {
    'isOnline': isOnline,
    'isReady': isReady,
    'lastSeen': lastSeen,
  };
}

/// إجابة لاعب على البطاقة الحالية.
class AnswerState {
  const AnswerState({
    required this.uid,
    required this.text,
    required this.submittedAt,
    this.isCorrect,
  });

  final String uid;
  final String text;
  final int submittedAt; // epoch ms
  final bool? isCorrect; // null = لم يُحكم عليها بعد

  bool get isPending => isCorrect == null;

  factory AnswerState.fromRtdbMap(Map<String, dynamic> map) {
    return AnswerState(
      uid: map['uid']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      submittedAt: (map['submittedAt'] as num?)?.toInt() ?? 0,
      isCorrect: map['isCorrect'] as bool?,
    );
  }

  Map<String, dynamic> toRtdbMap() => {
    'uid': uid,
    'text': text,
    'submittedAt': submittedAt,
    'isCorrect': isCorrect,
  };
}
