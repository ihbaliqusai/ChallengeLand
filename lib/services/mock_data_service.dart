import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_config.dart';
import '../core/utils/date_utils.dart';
import '../models/category.dart';
import '../models/challenge_card.dart';
import '../models/daily_challenge.dart';
import '../models/player_role.dart';
import '../models/game_session.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_history.dart';
import '../models/question.dart';
import '../models/room.dart';
import '../models/room_player.dart';
import '../models/team.dart';
import '../models/user_profile.dart';

class MockDataService {
  MockDataService({Uuid? uuid, Random? random})
    : _uuid = uuid ?? const Uuid(),
      _random = random ?? Random();

  final Uuid _uuid;
  final Random _random;

  UserProfile getMockUser({String? uid, String username = 'لاعب التحدي'}) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'mock-${_uuid.v4()}',
      username: username,
      usernameLower: username.toLowerCase(),
      photoUrl: null,
      email: null,
      isGuest: true,
      level: 4,
      xp: 620,
      coins: 340,
      trophies: 50,
      energy: 82,
      rating: 1135,
      wins: 8,
      losses: 4,
      totalGames: 12,
      correctAnswers: 74,
      wrongAnswers: 31,
      bestCategoryId: 'general',
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
    );
  }

  Future<List<Category>> getSampleCategories() async {
    final text = await rootBundle.loadString(
      'assets/sample_data/sample_categories.json',
    );
    final list = jsonDecode(text) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<List<Question>> getSampleQuestions({
    String? categoryId,
    int? limit,
  }) async {
    final text = await rootBundle.loadString(
      'assets/sample_data/sample_questions.json',
    );
    final list = jsonDecode(text) as List<dynamic>;
    var questions = list
        .whereType<Map<String, dynamic>>()
        .map(Question.fromJson)
        .where((question) => question.isActive)
        .toList();
    if (categoryId != null) {
      questions = questions
          .where((question) => question.categoryId == categoryId)
          .toList();
    }
    questions.shuffle(_random);
    return questions.take(limit ?? questions.length).toList(growable: false);
  }

  Future<List<LeaderboardEntry>> getMockLeaderboard({
    String period = 'all',
  }) async {
    final names = [
      'نور',
      'مازن',
      'ليان',
      'سارة',
      'عمر',
      'جود',
      'راكان',
      'هيا',
      'مالك',
      'تالا',
      'زيد',
      'رنا',
      'سيف',
      'ريم',
      'كنان',
    ];
    return List.generate(names.length, (index) {
      final rank = index + 1;
      return LeaderboardEntry(
        uid: 'mock-leader-$rank',
        username: names[index],
        rank: rank,
        level: 9 - (index ~/ 2),
        score: 9400 - (index * 470),
        wins: 38 - (index * 2),
        rating: 1500 - (index * 35),
        period: period,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<GameSession> startMockMatch({
    required UserProfile player,
    String mode = 'quick_1v1',
    int questionCount = AppConfig.defaultQuestionCount,
    int timerSeconds = AppConfig.defaultTimerSeconds,
  }) async {
    final questions = await getSampleQuestions(limit: questionCount);
    return GameSession(
      id: 'mock-session-${_uuid.v4()}',
      mode: mode,
      playerIds: [player.uid, 'bot-arena'],
      questionIds: questions.map((question) => question.id).toList(),
      currentQuestionIndex: 0,
      status: 'active',
      playerScores: {player.uid: 0, 'bot-arena': 0},
      teamScores: const {},
      timerSeconds: timerSeconds,
      startedAt: DateTime.now(),
    );
  }

  Future<Room> createMockRoom({
    required UserProfile host,
    required String code,
    required String name,
    required String mode,
    required int questionCount,
    required int maxPlayers,
    int roundDuration = 60,
    int totalRounds = 5,
  }) async {
    final now = DateTime.now();
    final gameType = GameTypeX.fromString(mode);
    return Room(
      id: 'mock-room-${_uuid.v4()}',
      code: code,
      name: name,
      hostId: host.uid,
      mode: mode,
      gameType: gameType,
      questionCount: questionCount,
      maxPlayers: maxPlayers,
      roundDuration: roundDuration,
      totalRounds: totalRounds,
      currentRound: 0,
      phase: GamePhase.lobby,
      status: 'waiting',
      players: [
        RoomPlayer(
          uid: host.uid,
          username: host.username,
          photoUrl: host.photoUrl,
          isHost: true,
          isReady: true,
          score: 0,
          role: PlayerRole.host,
          joinedAt: now,
        ),
      ],
      teams: gameType.isTeamMode
          ? [Team.fromPreset(0), Team.fromPreset(1)]
          : const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<MatchHistory>> getMockHistory(String uid) async {
    return [
      MatchHistory(
        id: 'history-1',
        uid: uid,
        mode: 'quick_1v1',
        score: 620,
        opponentName: 'بوت المعرفة',
        result: 'win',
        correctAnswers: 5,
        wrongAnswers: 1,
        playedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      MatchHistory(
        id: 'history-2',
        uid: uid,
        mode: 'team_battle',
        score: 430,
        opponentName: 'الفريق الذهبي',
        result: 'loss',
        correctAnswers: 3,
        wrongAnswers: 2,
        playedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      MatchHistory(
        id: 'history-3',
        uid: uid,
        mode: 'categories_points',
        score: 710,
        opponentName: 'تحدي الفئات',
        result: 'win',
        correctAnswers: 6,
        wrongAnswers: 1,
        playedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MatchHistory(
        id: 'history-4',
        uid: uid,
        mode: 'daily_challenge',
        score: 560,
        opponentName: 'لوحة اليوم',
        result: 'draw',
        correctAnswers: 4,
        wrongAnswers: 1,
        playedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  Future<List<UserProfile>> getMockFriends() async {
    return [
      getMockUser(uid: 'friend-1', username: 'سلمان').copyWith(rating: 1240),
      getMockUser(uid: 'friend-2', username: 'جنى').copyWith(rating: 1185),
      getMockUser(uid: 'friend-3', username: 'فارس').copyWith(rating: 1110),
      getMockUser(uid: 'friend-4', username: 'ميرا').copyWith(rating: 1095),
      getMockUser(uid: 'friend-5', username: 'يزن').copyWith(rating: 1060),
    ];
  }

  Future<DailyChallenge> getTodayChallenge() async {
    final questions = await getSampleQuestions(limit: 10);
    final dateKey = ChallengeDateUtils.todayKey();
    return DailyChallenge(
      id: 'daily-$dateKey',
      dateKey: dateKey,
      questionIds: questions.map((question) => question.id).toList(),
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  Future<List<ChallengeCard>> getSampleChallengeCards({
    String? categoryId,
    ChallengeCardType? type,
    ChallengeDifficulty? difficulty,
    int? limit,
  }) async {
    final text = await rootBundle.loadString(
      'assets/sample_data/challenge_cards.json',
    );
    final data = jsonDecode(text) as Map<String, dynamic>;
    final list = data['cards'] as List<dynamic>;
    var cards = list
        .whereType<Map<String, dynamic>>()
        .map(ChallengeCard.fromJson)
        .where((c) => c.isActive)
        .toList();

    if (categoryId != null) {
      cards = cards.where((c) => c.categoryId == categoryId).toList();
    }
    if (type != null) {
      cards = cards.where((c) => c.type == type).toList();
    }
    if (difficulty != null) {
      cards = cards.where((c) => c.difficulty == difficulty).toList();
    }

    cards.shuffle(_random);
    return cards.take(limit ?? cards.length).toList(growable: false);
  }
}
