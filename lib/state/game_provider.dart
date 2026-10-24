import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/score_utils.dart';
import '../models/answer.dart';
import '../models/game_session.dart';
import '../models/match_history.dart';
import '../models/question.dart';
import '../models/user_profile.dart';
import '../services/game_service.dart';

enum BotDifficulty { easy, medium, hard }

class GameProvider extends ChangeNotifier {
  GameProvider({
    GameService? gameService,
    this.botDifficulty = BotDifficulty.medium,
  }) : _gameService = gameService ?? GameService();

  final GameService _gameService;
  final BotDifficulty botDifficulty;

  GameSession? session;
  List<Question> questions = const [];
  List<Answer> answers = const [];
  bool isLoading = false;
  String? error;
  String? selectedAnswer;
  String? revealMessage;
  bool isRevealVisible = false;
  bool didTimeout = false;
  int playerScore = 0;
  int opponentScore = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int currentIndex = 0;
  MatchHistory? latestHistory;

  Question? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
      ? questions[currentIndex]
      : null;
  bool get isFinished => session?.isFinished == true;
  int get totalQuestions => questions.length;
  String get botDifficultyLabel => switch (botDifficulty) {
    BotDifficulty.easy => AppStrings.botEasy,
    BotDifficulty.medium => AppStrings.botMedium,
    BotDifficulty.hard => AppStrings.botHard,
  };

  Future<void> startGame({
    required UserProfile player,
    String mode = 'quick_1v1',
    String? categoryId,
    int questionCount = AppConfig.defaultQuestionCount,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      questions = await _gameService.getQuestionsForSession(
        categoryId: categoryId,
        questionCount: questionCount,
      );
      if (questions.isEmpty) {
        throw StateError(AppStrings.noQuestions);
      }
      session = await _gameService.createGameSession(
        player: player,
        mode: mode,
        questionCount: questions.length,
      );
      answers = const [];
      selectedAnswer = null;
      revealMessage = null;
      isRevealVisible = false;
      didTimeout = false;
      playerScore = 0;
      opponentScore = 0;
      correctAnswers = 0;
      wrongAnswers = 0;
      currentIndex = 0;
      latestHistory = null;
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitAnswer({
    required UserProfile player,
    required String answer,
    required int remainingTime,
    bool timedOut = false,
  }) async {
    final currentSession = session;
    final question = currentQuestion;
    if (currentSession == null || question == null) return;
    if (isRevealVisible) {
      error = AppStrings.duplicateAnswer;
      notifyListeners();
      return;
    }

    error = null;
    didTimeout = timedOut;
    selectedAnswer = answer;
    final isCorrect = !timedOut && question.isCorrect(answer);
    final score = ScoreUtils.calculateQuestionScore(
      isCorrect: isCorrect,
      remainingTime: timedOut ? 0 : remainingTime,
      totalTime: currentSession.timerSeconds,
      basePoints: question.points,
    );
    final savedAnswer = await _gameService.submitAnswer(
      session: currentSession,
      question: question,
      player: player,
      selectedAnswer: answer,
      remainingTime: timedOut ? 0 : remainingTime,
      score: score,
    );

    answers = [...answers, savedAnswer];
    playerScore += score;
    opponentScore += _calculateBotQuestionScore(
      question: question,
      timerSeconds: currentSession.timerSeconds,
      questionIndex: currentIndex,
    );
    if (isCorrect) {
      correctAnswers++;
    } else {
      wrongAnswers++;
    }
    revealMessage = timedOut
        ? AppStrings.timeExpired
        : isCorrect
        ? AppStrings.correctAnswerTitle
        : AppStrings.wrongAnswerTitle;
    isRevealVisible = true;
    notifyListeners();
  }

  Future<void> submitTimeout({required UserProfile player}) {
    return submitAnswer(
      player: player,
      answer: AppStrings.timeExpired,
      remainingTime: 0,
      timedOut: true,
    );
  }

  Future<void> nextQuestion(UserProfile player) async {
    final currentSession = session;
    if (currentSession == null) return;
    if (currentIndex >= questions.length - 1) {
      await finish(player);
      return;
    }
    currentIndex++;
    selectedAnswer = null;
    revealMessage = null;
    isRevealVisible = false;
    didTimeout = false;
    error = null;
    await _gameService.moveToNextQuestion(currentSession);
    notifyListeners();
  }

  Future<void> finish(UserProfile player) async {
    final currentSession = session;
    if (currentSession == null) return;
    if (currentSession.isFinished) return;
    final won = playerScore >= opponentScore;
    session = await _gameService.finishGame(
      currentSession.copyWith(
        playerScores: {player.uid: playerScore, 'bot-arena': opponentScore},
        winnerId: won ? player.uid : 'bot-arena',
      ),
    );
    latestHistory = MatchHistory(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      uid: player.uid,
      mode: currentSession.mode,
      score: playerScore,
      opponentName: 'بوت المعرفة',
      result: won ? 'win' : 'loss',
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      playedAt: DateTime.now(),
    );
    await _gameService.saveMatchHistory(latestHistory!);
    notifyListeners();
  }

  void resetRevealError() {
    error = null;
    notifyListeners();
  }

  int _calculateBotQuestionScore({
    required Question question,
    required int timerSeconds,
    required int questionIndex,
  }) {
    final isBotCorrect = switch (botDifficulty) {
      BotDifficulty.easy => questionIndex.isEven,
      BotDifficulty.medium => (questionIndex + 1) % 3 != 0,
      BotDifficulty.hard => (questionIndex + 1) % 5 != 0,
    };
    if (!isBotCorrect) return 0;

    final remainingRatio = switch (botDifficulty) {
      BotDifficulty.easy => 0.35,
      BotDifficulty.medium => 0.55,
      BotDifficulty.hard => 0.75,
    };
    final botRemainingTime = (timerSeconds * remainingRatio).round();
    return ScoreUtils.calculateQuestionScore(
      isCorrect: true,
      remainingTime: botRemainingTime,
      totalTime: timerSeconds,
      basePoints: question.points,
    );
  }
}
