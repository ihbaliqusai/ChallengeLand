import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return firestore.collection(name);
  }

  CollectionReference<Map<String, dynamic>> get users =>
      collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get publicProfiles =>
      collection(FirestoreCollections.publicProfiles);
  CollectionReference<Map<String, dynamic>> get rooms =>
      collection(FirestoreCollections.rooms);
  CollectionReference<Map<String, dynamic>> get gameSessions =>
      collection(FirestoreCollections.gameSessions);
  CollectionReference<Map<String, dynamic>> get categories =>
      collection(FirestoreCollections.categories);
  CollectionReference<Map<String, dynamic>> get questions =>
      collection(FirestoreCollections.questions);
  CollectionReference<Map<String, dynamic>> get matchmakingQueue =>
      collection(FirestoreCollections.matchmakingQueue);
  CollectionReference<Map<String, dynamic>> get dailyChallenges =>
      collection(FirestoreCollections.dailyChallenges);
  CollectionReference<Map<String, dynamic>> get dailyScores =>
      collection(FirestoreCollections.dailyScores);
}
