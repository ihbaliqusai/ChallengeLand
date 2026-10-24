import '../core/utils/date_utils.dart';
import 'player_role.dart';
import 'room_player.dart';
import 'team.dart';

class Room {
  const Room({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    required this.mode,
    required this.gameType,
    required this.questionCount,
    required this.maxPlayers,
    required this.roundDuration,
    required this.totalRounds,
    required this.currentRound,
    required this.phase,
    required this.status,
    required this.players,
    required this.teams,
    this.currentDescriber,
    this.currentTeamDescribingId,
    this.gameSessionId,
    this.createdAt,
    this.updatedAt,
  });

  // ── الهوية ──
  final String id;
  final String code;
  final String name;
  final String hostId;

  // ── نوع اللعبة ──
  final String mode; // للتوافق مع Firestore القديم
  final GameType gameType; // النوع المنظّم للمنطق

  // ── إعدادات الجولات ──
  final int questionCount;
  final int maxPlayers;
  final int roundDuration; // ثواني لكل جولة وصف (default 60)
  final int totalRounds; // عدد جولات اللعبة (default 5)
  final int currentRound; // الجولة الحالية (0 = لم تبدأ، 1..N)

  // ── حالة اللعبة ──
  final GamePhase phase;
  final String status; // 'waiting' | 'active' | 'finished'

  // ── اللاعبون والفرق ──
  final List<RoomPlayer> players;
  final List<Team> teams;

  // ── الدور الحالي ──
  final String? currentDescriber; // uid المُوصِف الحالي
  final String? currentTeamDescribingId; // id الفريق الذي يصف الآن

  final String? gameSessionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ===== Computed =====

  bool get isFull => players.length >= maxPlayers;
  bool get isWaiting => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';
  bool get isInLobby => phase == GamePhase.lobby;
  bool get isGameOver => phase == GamePhase.gameOver;
  bool get isLastRound => currentRound >= totalRounds;

  int get playerCount => players.length;
  int get readyCount => players.where((p) => p.isReady).length;
  bool get allReady => playerCount > 0 && readyCount == playerCount;

  RoomPlayer? get host => players.cast<RoomPlayer?>().firstWhere(
    (p) => p?.uid == hostId,
    orElse: () => null,
  );

  RoomPlayer? get describerPlayer => currentDescriber == null
      ? null
      : players.cast<RoomPlayer?>().firstWhere(
          (p) => p?.uid == currentDescriber,
          orElse: () => null,
        );

  Team? get describingTeam => currentTeamDescribingId == null
      ? null
      : teams.cast<Team?>().firstWhere(
          (t) => t?.id == currentTeamDescribingId,
          orElse: () => null,
        );

  Team? get guessingTeam => currentTeamDescribingId == null || teams.length < 2
      ? null
      : teams.cast<Team?>().firstWhere(
          (t) => t?.id != currentTeamDescribingId,
          orElse: () => null,
        );

  // نسبة تقدم اللعبة (0.0 → 1.0)
  double get progressFraction =>
      totalRounds == 0 ? 0 : currentRound / totalRounds;

  // ===== Serialization =====

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    hostId: json['hostId']?.toString() ?? '',
    mode: json['mode']?.toString() ?? 'quick1v1',
    gameType: GameTypeX.fromString(json['gameType']?.toString() ?? ''),
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 5,
    maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 2,
    roundDuration: (json['roundDuration'] as num?)?.toInt() ?? 60,
    totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 5,
    currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
    phase: GamePhaseX.fromString(json['phase']?.toString() ?? 'lobby'),
    status: json['status']?.toString() ?? 'waiting',
    players: (json['players'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoomPlayer.fromJson)
        .toList(growable: false),
    teams: (json['teams'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Team.fromJson)
        .toList(growable: false),
    currentDescriber: json['currentDescriber']?.toString(),
    currentTeamDescribingId: json['currentTeamDescribingId']?.toString(),
    gameSessionId: json['gameSessionId']?.toString(),
    createdAt: ChallengeDateUtils.parse(json['createdAt']),
    updatedAt: ChallengeDateUtils.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'hostId': hostId,
    'mode': mode,
    'gameType': gameType.name,
    'questionCount': questionCount,
    'maxPlayers': maxPlayers,
    'roundDuration': roundDuration,
    'totalRounds': totalRounds,
    'currentRound': currentRound,
    'phase': phase.name,
    'status': status,
    'players': players.map((p) => p.toJson()).toList(),
    'teams': teams.map((t) => t.toJson()).toList(),
    'currentDescriber': currentDescriber,
    'currentTeamDescribingId': currentTeamDescribingId,
    'gameSessionId': gameSessionId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? hostId,
    String? mode,
    GameType? gameType,
    int? questionCount,
    int? maxPlayers,
    int? roundDuration,
    int? totalRounds,
    int? currentRound,
    GamePhase? phase,
    String? status,
    List<RoomPlayer>? players,
    List<Team>? teams,
    String? currentDescriber,
    String? currentTeamDescribingId,
    String? gameSessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCurrentDescriber = false,
    bool clearCurrentTeamDescribingId = false,
    bool clearGameSessionId = false,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      mode: mode ?? this.mode,
      gameType: gameType ?? this.gameType,
      questionCount: questionCount ?? this.questionCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      roundDuration: roundDuration ?? this.roundDuration,
      totalRounds: totalRounds ?? this.totalRounds,
      currentRound: currentRound ?? this.currentRound,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      players: players ?? this.players,
      teams: teams ?? this.teams,
      currentDescriber: clearCurrentDescriber
          ? null
          : currentDescriber ?? this.currentDescriber,
      currentTeamDescribingId: clearCurrentTeamDescribingId
          ? null
          : currentTeamDescribingId ?? this.currentTeamDescribingId,
      gameSessionId: clearGameSessionId
          ? null
          : gameSessionId ?? this.gameSessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ===== Factory helpers =====

  static Room createNew({
    required String id,
    required String code,
    required String name,
    required String hostId,
    required GameType gameType,
    int roundDuration = 60,
    int totalRounds = 5,
    int questionCount = 10,
  }) {
    return Room(
      id: id,
      code: code,
      name: name,
      hostId: hostId,
      mode: gameType.name,
      gameType: gameType,
      questionCount: questionCount,
      maxPlayers: gameType.maxPlayers,
      roundDuration: roundDuration,
      totalRounds: totalRounds,
      currentRound: 0,
      phase: GamePhase.lobby,
      status: 'waiting',
      players: const [],
      teams: gameType.isTeamMode
          ? [Team.fromPreset(0), Team.fromPreset(1)]
          : const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
