import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/answer.dart';
import '../models/game_session.dart';
import '../models/match_history.dart';
import '../models/question.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';

class GameService {
  GameService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
    Uuid? uuid,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore,
       _uuid = uuid ?? const Uuid();

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<GameSession> createGameSession({
    required UserProfile player,
    String mode = 'quick_1v1',
    int questionCount = AppConfig.defaultQuestionCount,
    int timerSeconds = AppConfig.defaultTimerSeconds,
  }) async {
    if (AppConfig.useMockData) {
      return _mockDataService.startMockMatch(
        player: player,
        mode: mode,
        questionCount: questionCount,
        timerSeconds: timerSeconds,
      );
    }

    final questions = await getQuestionsForSession(
      questionCount: questionCount,
    );
    final doc = _db.collection(FirestoreCollections.gameSessions).doc();
    final session = GameSession(
      id: doc.id,
      mode: mode,
      playerIds: [player.uid],
      questionIds: questions.map((question) => question.id).toList(),
      currentQuestionIndex: 0,
      status: 'active',
      playerScores: {player.uid: 0},
      teamScores: const {},
      timerSeconds: timerSeconds,
      startedAt: DateTime.now(),
    );
    await doc.set(session.toJson());
    return session;
  }

  Stream<GameSession?> listenToGameSession(String sessionId) {
    if (AppConfig.useMockData) return const Stream<GameSession?>.empty();
    return _db
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .snapshots()
        .map(
          (doc) =>
              doc.data() == null ? null : GameSession.fromJson(doc.data()!),
        );
  }

  Future<List<Question>> getQuestionsForSession({
    String? categoryId,
    int questionCount = AppConfig.defaultQuestionCount,
  }) async {
    if (AppConfig.useMockData) {
      return _mockDataService.getSampleQuestions(
        categoryId: categoryId,
        limit: questionCount,
      );
    }
    final query = categoryId == null
        ? _db.collection(FirestoreCollections.questions)
        : _db
              .collection(FirestoreCollections.questions)
              .where('categoryId', isEqualTo: categoryId);
    final snapshot = await query
        .where('isActive', isEqualTo: true)
        .limit(questionCount)
        .get();
    return snapshot.docs
        .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
        .toList(growable: false);
  }

  Future<Answer> submitAnswer({
    required GameSession session,
    required Question question,
    required UserProfile player,
    required String selectedAnswer,
    required int remainingTime,
    required int score,
  }) async {
    final answer = Answer(
      id: _uuid.v4(),
      sessionId: session.id,
      questionId: question.id,
      uid: player.uid,
      selectedAnswer: selectedAnswer,
      isCorrect: question.isCorrect(selectedAnswer),
      score: score,
      remainingTime: remainingTime,
      answeredAt: DateTime.now(),
    );
    if (AppConfig.useMockData) return answer;
    await _db
        .collection(FirestoreCollections.gameSessions)
        .doc(session.id)
        .collection(FirestoreCollections.answers)
        .doc(answer.id)
        .set(answer.toJson());
    return answer;
  }

  Future<void> revealAnswer(String sessionId, String questionId) async {
    if (AppConfig.useMockData) return;
    // TODO: Reveal state should be controlled by Cloud Functions.
  }

  Future<void> moveToNextQuestion(GameSession session) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.gameSessions)
        .doc(session.id)
        .update({'currentQuestionIndex': session.currentQuestionIndex + 1});
  }

  Future<GameSession> finishGame(GameSession session) async {
    final finished = session.copyWith(
      status: 'finished',
      finishedAt: DateTime.now(),
    );
    if (AppConfig.useMockData) return finished;
    await _db
        .collection(FirestoreCollections.gameSessions)
        .doc(session.id)
        .set(finished.toJson(), SetOptions(merge: true));
    return finished;
  }

  Future<void> saveMatchHistory(MatchHistory history) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.matchHistory)
        .doc(history.id)
        .set(history.toJson());
  }
}
