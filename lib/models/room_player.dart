import '../core/utils/date_utils.dart';
import 'player_role.dart';

class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.username,
    this.photoUrl,
    this.teamId,
    required this.isHost,
    required this.isReady,
    required this.score,
    this.role = PlayerRole.guesser,
    this.personalScore = 0,
    this.correctGuesses = 0,
    this.skipsUsed = 0,
    this.joinedAt,
  });

  final String uid;
  final String username;
  final String? photoUrl;
  final String? teamId;
  final bool isHost;
  final bool isReady;

  // نقاط الجلسة الكلية (للوحة المتصدرين)
  final int score;

  // الدور الحالي في هذه الجولة
  final PlayerRole role;

  // النقاط الشخصية المكتسبة كمُوصِف أو مُخمِّن (تُفصل عن نقاط الفريق)
  final int personalScore;

  // عدد مرات الإجابة الصحيحة كمُخمِّن
  final int correctGuesses;

  // عدد مرات التخطي كمُوصِف
  final int skipsUsed;

  final DateTime? joinedAt;

  // ===== Computed =====

  bool get isDescriber => role == PlayerRole.describer;
  bool get isGuesser => role == PlayerRole.guesser;
  bool get isSpectator => role == PlayerRole.spectator;
  bool get isActiveInRound => role.isActiveInRound;

  // ===== Serialization =====

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    uid: json['uid']?.toString() ?? '',
    username: json['username']?.toString() ?? 'لاعب',
    photoUrl: json['photoUrl']?.toString(),
    teamId: json['teamId']?.toString(),
    isHost: json['isHost'] == true,
    isReady: json['isReady'] != false,
    score: (json['score'] as num?)?.toInt() ?? 0,
    role: _parseRole(json['role']?.toString()),
    personalScore: (json['personalScore'] as num?)?.toInt() ?? 0,
    correctGuesses: (json['correctGuesses'] as num?)?.toInt() ?? 0,
    skipsUsed: (json['skipsUsed'] as num?)?.toInt() ?? 0,
    joinedAt: ChallengeDateUtils.parse(json['joinedAt']),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'photoUrl': photoUrl,
    'teamId': teamId,
    'isHost': isHost,
    'isReady': isReady,
    'score': score,
    'role': role.name,
    'personalScore': personalScore,
    'correctGuesses': correctGuesses,
    'skipsUsed': skipsUsed,
    'joinedAt': joinedAt?.toIso8601String(),
  };

  RoomPlayer copyWith({
    String? uid,
    String? username,
    String? photoUrl,
    String? teamId,
    bool? isHost,
    bool? isReady,
    int? score,
    PlayerRole? role,
    int? personalScore,
    int? correctGuesses,
    int? skipsUsed,
    DateTime? joinedAt,
  }) {
    return RoomPlayer(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      teamId: teamId ?? this.teamId,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      score: score ?? this.score,
      role: role ?? this.role,
      personalScore: personalScore ?? this.personalScore,
      correctGuesses: correctGuesses ?? this.correctGuesses,
      skipsUsed: skipsUsed ?? this.skipsUsed,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  RoomPlayer addPersonalPoints(int points) =>
      copyWith(personalScore: personalScore + points, score: score + points);

  static PlayerRole _parseRole(String? s) {
    switch (s) {
      case 'host':
        return PlayerRole.host;
      case 'describer':
        return PlayerRole.describer;
      case 'guesser':
        return PlayerRole.guesser;
      case 'spectator':
        return PlayerRole.spectator;
      case 'judge':
        return PlayerRole.judge;
      default:
        return PlayerRole.guesser;
    }
  }
}
