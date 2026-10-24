import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/friend_request.dart';
import '../models/room.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';
import 'room_service.dart';

class FriendService {
  FriendService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
    RoomService? roomService,
    Uuid? uuid,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore,
       _roomService = roomService ?? RoomService(),
       _uuid = uuid ?? const Uuid();

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  final RoomService _roomService;
  final Uuid _uuid;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<void> sendFriendRequest(UserProfile from, UserProfile to) async {
    if (AppConfig.useMockData) return;
    final request = FriendRequest(
      id: _uuid.v4(),
      fromUid: from.uid,
      toUid: to.uid,
      fromUsername: from.username,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _db
        .collection(FirestoreCollections.friendRequests)
        .doc(request.id)
        .set(request.toJson());
  }

  Future<List<FriendRequest>> getFriendRequests(String uid) async {
    if (AppConfig.useMockData) return const [];
    final snapshot = await _db
        .collection(FirestoreCollections.friendRequests)
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs
        .map((doc) => FriendRequest.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.friendRequests)
        .doc(request.id)
        .set(
          request.copyWith(status: 'accepted').toJson(),
          SetOptions(merge: true),
        );
  }

  Future<void> rejectFriendRequest(FriendRequest request) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.friendRequests)
        .doc(request.id)
        .set(
          request.copyWith(status: 'rejected').toJson(),
          SetOptions(merge: true),
        );
  }

  Future<List<UserProfile>> getFriends(String uid) async {
    if (AppConfig.useMockData) return _mockDataService.getMockFriends();
    final snapshot = await _db
        .collection(FirestoreCollections.friends)
        .doc(uid)
        .collection(FirestoreCollections.items)
        .get();
    return snapshot.docs
        .map((doc) => UserProfile.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<Room> challengeFriend({
    required UserProfile host,
    required UserProfile friend,
  }) {
    return _roomService.createRoom(
      host: host,
      name: 'تحدي ${friend.username}',
      mode: 'quick1v1',
      questionCount: 5,
      maxPlayers: 2,
      roundDuration: 60,
    );
  }
}
