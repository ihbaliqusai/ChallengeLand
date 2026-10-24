import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';

class UserService {
  UserService({MockDataService? mockDataService, FirebaseFirestore? firestore})
    : _mockDataService = mockDataService ?? MockDataService(),
      _firestore = firestore;

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<UserProfile?> getUserProfile(String uid) async {
    if (AppConfig.useMockData) return _mockDataService.getMockUser(uid: uid);
    final doc = await _db.collection(FirestoreCollections.users).doc(uid).get();
    final data = doc.data();
    return data == null ? null : UserProfile.fromJson(data);
  }

  Future<UserProfile> updateUsername(
    UserProfile profile,
    String username,
  ) async {
    final updated = profile.copyWith(
      username: username.trim(),
      usernameLower: username.trim().toLowerCase(),
      updatedAt: DateTime.now(),
    );
    if (AppConfig.useMockData) return updated;
    await _db
        .collection(FirestoreCollections.users)
        .doc(profile.uid)
        .set(updated.toJson(), SetOptions(merge: true));
    await _db
        .collection(FirestoreCollections.publicProfiles)
        .doc(profile.uid)
        .set(updated.toJson(), SetOptions(merge: true));
    return updated;
  }

  Future<UserProfile> updateStats(
    UserProfile profile, {
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
    required bool won,
  }) async {
    final updated = profile.copyWith(
      xp: profile.xp + score ~/ 8,
      coins: profile.coins + (won ? 30 : 12),
      trophies: profile.trophies + (won ? 3 : 1),
      wins: profile.wins + (won ? 1 : 0),
      losses: profile.losses + (won ? 0 : 1),
      totalGames: profile.totalGames + 1,
      correctAnswers: profile.correctAnswers + correctAnswers,
      wrongAnswers: profile.wrongAnswers + wrongAnswers,
      rating: profile.rating + (won ? 18 : -8),
      updatedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );
    if (AppConfig.useMockData) return updated;
    await _db
        .collection(FirestoreCollections.users)
        .doc(profile.uid)
        .set(updated.toJson(), SetOptions(merge: true));
    return updated;
  }

  Future<List<UserProfile>> searchUsersByUsername(String query) async {
    if (AppConfig.useMockData) {
      final friends = await _mockDataService.getMockFriends();
      return friends
          .where((user) => user.username.contains(query.trim()))
          .toList(growable: false);
    }
    final normalized = query.trim().toLowerCase();
    final snapshot = await _db
        .collection(FirestoreCollections.publicProfiles)
        .where('usernameLower', isGreaterThanOrEqualTo: normalized)
        .where('usernameLower', isLessThanOrEqualTo: '$normalized\uf8ff')
        .limit(20)
        .get();
    return snapshot.docs
        .map((doc) => UserProfile.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<void> updateLastSeen(String uid) async {
    if (AppConfig.useMockData) return;
    await _db.collection(FirestoreCollections.users).doc(uid).set({
      'lastSeenAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
