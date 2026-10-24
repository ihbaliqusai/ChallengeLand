import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/leaderboard_entry.dart';
import 'mock_data_service.dart';

class LeaderboardService {
  LeaderboardService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore;

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<List<LeaderboardEntry>> getDailyLeaderboard() =>
      _getLeaderboard('today');

  Future<List<LeaderboardEntry>> getWeeklyLeaderboard() =>
      _getLeaderboard('week');

  Future<List<LeaderboardEntry>> getGlobalLeaderboard() =>
      _getLeaderboard('all');

  Future<List<LeaderboardEntry>> _getLeaderboard(String period) async {
    if (AppConfig.useMockData) {
      return _mockDataService.getMockLeaderboard(period: period);
    }
    final snapshot = await _db
        .collection(FirestoreCollections.leaderboards)
        .doc(period)
        .collection(FirestoreCollections.entries)
        .orderBy('score', descending: true)
        .limit(100)
        .get();
    var rank = 0;
    return snapshot.docs
        .map((doc) {
          rank++;
          return LeaderboardEntry.fromJson({...doc.data(), 'rank': rank});
        })
        .toList(growable: false);
  }

  Future<void> updateLeaderboardEntry(LeaderboardEntry entry) async {
    if (AppConfig.useMockData) return;
    // TODO: Move leaderboard writes to Cloud Functions before production.
    await _db
        .collection(FirestoreCollections.leaderboards)
        .doc(entry.period ?? 'all')
        .collection(FirestoreCollections.entries)
        .doc(entry.uid)
        .set(entry.toJson(), SetOptions(merge: true));
  }
}
