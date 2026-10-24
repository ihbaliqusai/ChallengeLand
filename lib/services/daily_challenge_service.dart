import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../core/utils/date_utils.dart';
import '../models/daily_challenge.dart';
import '../models/daily_score.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';

class DailyChallengeService {
  DailyChallengeService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore;

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<DailyChallenge> getTodayChallenge() async {
    if (AppConfig.useMockData) return _mockDataService.getTodayChallenge();
    final dateKey = ChallengeDateUtils.todayKey();
    final doc = await _db
        .collection(FirestoreCollections.dailyChallenges)
        .doc(dateKey)
        .get();
    final data = doc.data();
    if (data == null) {
      // TODO: Create daily question sets with Cloud Functions.
      return _mockDataService.getTodayChallenge();
    }
    return DailyChallenge.fromJson(data);
  }

  Future<DailyChallenge> startDailyChallenge() => getTodayChallenge();

  Future<void> submitDailyScore({
    required UserProfile user,
    required int score,
    required int correctAnswers,
    required int timeSpentSeconds,
  }) async {
    if (AppConfig.useMockData) return;
    final dateKey = ChallengeDateUtils.todayKey();
    final dailyScore = DailyScore(
      id: '${user.uid}-$dateKey',
      uid: user.uid,
      username: user.username,
      dateKey: dateKey,
      score: score,
      correctAnswers: correctAnswers,
      timeSpentSeconds: timeSpentSeconds,
      submittedAt: DateTime.now(),
    );
    await _db
        .collection(FirestoreCollections.dailyScores)
        .doc(dailyScore.id)
        .set(dailyScore.toJson(), SetOptions(merge: true));
  }

  Future<DailyScore?> getDailyScore(String uid) async {
    if (AppConfig.useMockData) return null;
    final dateKey = ChallengeDateUtils.todayKey();
    final doc = await _db
        .collection(FirestoreCollections.dailyScores)
        .doc('$uid-$dateKey')
        .get();
    final data = doc.data();
    return data == null ? null : DailyScore.fromJson(data);
  }
}
