import 'package:challenge_land/models/game_session.dart';
import 'package:challenge_land/models/question.dart';
import 'package:challenge_land/models/room.dart';
import 'package:challenge_land/models/room_player.dart';
import 'package:challenge_land/models/player_role.dart';
import 'package:challenge_land/models/team.dart';
import 'package:challenge_land/models/user_profile.dart';

DateTime sampleNow() => DateTime.utc(2026, 1, 2, 3, 4, 5);

UserProfile sampleUserProfile({
  String uid = 'player-1',
  String username = 'لاعب الاختبار',
}) {
  final now = sampleNow();
  return UserProfile(
    uid: uid,
    username: username,
    usernameLower: username.toLowerCase(),
    photoUrl: 'https://example.com/avatar.png',
    email: 'player@example.com',
    isGuest: true,
    level: 5,
    xp: 720,
    coins: 180,
    trophies: 64,
    energy: 90,
    rating: 1210,
    wins: 9,
    losses: 3,
    totalGames: 12,
    correctAnswers: 80,
    wrongAnswers: 25,
    bestCategoryId: 'general',
    createdAt: now,
    updatedAt: now,
    lastSeenAt: now,
  );
}

Question sampleQuestion({String id = 'question-1'}) {
  final now = sampleNow();
  return Question(
    id: id,
    categoryId: 'general',
    type: 'multiple_choice',
    questionText: 'ما عاصمة الأردن؟',
    correctAnswer: 'عمّان',
    options: const ['عمّان', 'إربد', 'العقبة', 'الزرقاء'],
    explanation: 'عمّان هي عاصمة الأردن.',
    mediaUrl: null,
    points: 100,
    difficulty: 'easy',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

GameSession sampleGameSession({
  String id = 'session-1',
  String playerId = 'player-1',
  String status = 'active',
}) {
  final now = sampleNow();
  return GameSession(
    id: id,
    mode: 'quick_1v1',
    roomId: 'room-1',
    playerIds: [playerId, 'bot-arena'],
    questionIds: const ['question-1', 'question-2'],
    currentQuestionIndex: 0,
    status: status,
    playerScores: {playerId: 150, 'bot-arena': 90},
    teamScores: const {'blue': 150, 'gold': 90},
    timerSeconds: 15,
    startedAt: now,
    finishedAt: status == 'finished'
        ? now.add(const Duration(minutes: 3))
        : null,
    winnerId: status == 'finished' ? playerId : null,
    winningTeamId: status == 'finished' ? 'blue' : null,
  );
}

RoomPlayer sampleRoomPlayer({
  String uid = 'player-1',
  String username = 'لاعب الاختبار',
  bool isHost = true,
}) {
  return RoomPlayer(
    uid: uid,
    username: username,
    photoUrl: null,
    teamId: 'blue',
    isHost: isHost,
    isReady: true,
    score: 120,
    joinedAt: sampleNow(),
  );
}

Team sampleTeam({
  String id = 'blue',
  String name = 'الفريق الأزرق',
  String color = '#2563EB',
  String emoji = '🔵',
  int score = 120,
}) {
  return Team(
    id: id,
    name: name,
    color: color,
    emoji: emoji,
    playerIds: const ['player-1'],
    score: score,
  );
}

Room sampleRoom({String id = 'room-1'}) {
  final now = sampleNow();
  return Room(
    id: id,
    code: 'ABC234',
    name: 'غرفة الاختبار',
    hostId: 'player-1',
    mode: 'teams2v2',
    gameType: GameType.teams2v2,
    questionCount: 5,
    maxPlayers: 4,
    roundDuration: 60,
    totalRounds: 5,
    currentRound: 0,
    phase: GamePhase.lobby,
    status: 'waiting',
    players: [sampleRoomPlayer()],
    teams: [
      sampleTeam(),
      sampleTeam(
        id: 'gold',
        name: 'الفريق الذهبي',
        color: '#EAB308',
        emoji: '🟡',
        score: 80,
      ),
    ],
    gameSessionId: null,
    createdAt: now,
    updatedAt: now,
  );
}
