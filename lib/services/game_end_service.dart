import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_history.dart';
import '../models/room_player.dart';
import '../state/auth_provider.dart';
import 'leaderboard_service.dart';

class GameEndService {
  GameEndService({
    LeaderboardService? leaderboardService,
    FirebaseFirestore? firestore,
  }) : _leaderboardService = leaderboardService ?? LeaderboardService(),
       _firestore = firestore;

  final LeaderboardService _leaderboardService;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// يحفظ نتائج اللعبة: إحصائيات المستخدم + سجل المباريات + المتصدرين.
  Future<void> finishGame({
    required AuthProvider auth,
    required RoomPlayer roomPlayer,
    required bool won,
    required String mode,
    required String opponentName,
  }) async {
    // 1. تحديث إحصائيات المستخدم عبر AuthProvider
    await auth.applyStats(
      score: roomPlayer.score,
      correctAnswers: roomPlayer.correctGuesses,
      wrongAnswers: roomPlayer.skipsUsed,
      won: won,
    );

    final user = auth.user;
    if (user == null || AppConfig.useMockData) return;

    // 2. حفظ سجل المباراة
    await _saveMatchHistory(
      uid: user.uid,
      mode: mode,
      score: roomPlayer.score,
      opponentName: opponentName,
      won: won,
      correctAnswers: roomPlayer.correctGuesses,
      wrongAnswers: roomPlayer.skipsUsed,
    );

    // 3. تحديث لوحة الصدارة
    await _leaderboardService.updateLeaderboardEntry(
      LeaderboardEntry(
        uid: user.uid,
        username: user.username,
        photoUrl: user.photoUrl,
        rank: 0,
        level: user.level,
        score: user.rating,
        wins: user.wins,
        rating: user.rating,
        period: 'all',
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _saveMatchHistory({
    required String uid,
    required String mode,
    required int score,
    required String opponentName,
    required bool won,
    required int correctAnswers,
    required int wrongAnswers,
  }) async {
    final id = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final history = MatchHistory(
      id: id,
      uid: uid,
      mode: mode,
      score: score,
      opponentName: opponentName,
      result: won ? 'win' : 'loss',
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      playedAt: DateTime.now(),
    );
    await _db
        .collection(FirestoreCollections.matchHistory)
        .doc(id)
        .set(history.toJson());
  }
}
