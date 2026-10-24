import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../core/utils/room_code_generator.dart';
import '../models/room.dart';
import '../models/room_player.dart';
import '../models/player_role.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';
import 'role_rotation_service.dart';
import 'team_service.dart';

class RoomService {
  RoomService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
    RoomCodeGenerator? codeGenerator,
    TeamService? teamService,
    RoleRotationService? roleRotationService,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore,
       _codeGenerator = codeGenerator ?? RoomCodeGenerator(),
       _teamService = teamService ?? const TeamService(),
       _roleRotationService =
           roleRotationService ?? const RoleRotationService();

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  final RoomCodeGenerator _codeGenerator;
  final TeamService _teamService;
  final RoleRotationService _roleRotationService;
  Room? _mockRoom;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<Room> createRoom({
    required UserProfile host,
    required String name,
    required String mode,
    required int questionCount,
    required int maxPlayers,
    int roundDuration = 60,
    int totalRounds = 5,
  }) async {
    final code = _codeGenerator.generate();
    if (AppConfig.useMockData) {
      _mockRoom = await _mockDataService.createMockRoom(
        host: host,
        code: code,
        name: name,
        mode: mode,
        questionCount: questionCount,
        maxPlayers: maxPlayers,
        roundDuration: roundDuration,
        totalRounds: totalRounds,
      );
      return _mockRoom!;
    }

    final doc = _db.collection(FirestoreCollections.rooms).doc();
    final room = await _mockDataService.createMockRoom(
      host: host,
      code: code,
      name: name,
      mode: mode,
      questionCount: questionCount,
      maxPlayers: maxPlayers,
      roundDuration: roundDuration,
      totalRounds: totalRounds,
    );
    final realRoom = room.copyWith(id: doc.id);
    await doc.set(realRoom.toJson());
    return realRoom;
  }

  Future<Room> joinRoomByCode({
    required UserProfile user,
    required String code,
  }) async {
    if (AppConfig.useMockData) {
      final base =
          _mockRoom ??
          await _mockDataService.createMockRoom(
            host: user,
            code: code,
            name: 'غرفة تدريب',
            mode: 'quick1v1',
            questionCount: 5,
            maxPlayers: 4,
          );
      if (base.isFull) throw StateError('الغرفة ممتلئة');
      final exists = base.players.any((player) => player.uid == user.uid);
      _mockRoom = exists
          ? base
          : base.copyWith(
              players: [
                ...base.players,
                RoomPlayer(
                  uid: user.uid,
                  username: user.username,
                  photoUrl: user.photoUrl,
                  isHost: false,
                  isReady: true,
                  score: 0,
                  joinedAt: DateTime.now(),
                ),
              ],
            );
      return _mockRoom!;
    }

    final snapshot = await _db
        .collection(FirestoreCollections.rooms)
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) throw StateError('لم يتم العثور على الغرفة');
    final room = Room.fromJson(snapshot.docs.first.data());
    if (room.isFull) throw StateError('الغرفة ممتلئة');
    // TODO: Use a transaction and validate room state server-side.
    return room;
  }

  Future<void> leaveRoom(String roomId, String uid) async {
    if (AppConfig.useMockData) {
      _mockRoom = _mockRoom?.copyWith(
        players: _mockRoom!.players
            .where((player) => player.uid != uid)
            .toList(growable: false),
      );
      if (_mockRoom != null) {
        _mockRoom = _teamService.syncTeamsFromPlayers(_mockRoom!);
      }
      return;
    }
    await _db.collection(FirestoreCollections.rooms).doc(roomId).update({
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<Room?> listenToRoom(String roomId) {
    if (AppConfig.useMockData) return Stream.value(_mockRoom);
    return _db
        .collection(FirestoreCollections.rooms)
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.data() == null ? null : Room.fromJson(doc.data()!));
  }

  Future<Room> updateRoomSettings(Room room) async {
    if (AppConfig.useMockData) {
      _mockRoom = room.copyWith(updatedAt: DateTime.now());
      return _mockRoom!;
    }
    await _db
        .collection(FirestoreCollections.rooms)
        .doc(room.id)
        .set(room.toJson(), SetOptions(merge: true));
    return room;
  }

  Future<Room> assignTeam(Room room, String uid, String teamId) async {
    return updateRoomSettings(_teamService.movePlayerToTeam(room, uid, teamId));
  }

  Future<Room> autoAssignTeams(Room room) async {
    return updateRoomSettings(_teamService.autoAssignTeams(room));
  }

  Future<Room> resetTeams(Room room) async {
    return updateRoomSettings(_teamService.resetTeams(room));
  }

  Future<Room> applyCorrectAnswer(
    Room room, {
    required String describerUid,
    required String guesserUid,
  }) async {
    return updateRoomSettings(
      _teamService.applyCorrectAnswer(
        room,
        describerUid: describerUid,
        guesserUid: guesserUid,
      ),
    );
  }

  Future<Room> applySkip(Room room, {required String describerUid}) async {
    return updateRoomSettings(
      _teamService.applySkip(room, describerUid: describerUid),
    );
  }

  Future<Room> advanceToNextRound(Room room) async {
    return updateRoomSettings(_roleRotationService.advanceToNextRound(room));
  }

  Future<Room> removePlayer(Room room, String uid) async {
    return updateRoomSettings(
      _teamService.syncTeamsFromPlayers(
        room.copyWith(
          players: room.players
              .where((player) => player.uid != uid)
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<Room> startGame(Room room) async {
    final prepared =
        room.gameType.isTeamMode &&
            room.players.any(
              (player) => player.teamId == null || player.teamId!.isEmpty,
            )
        ? _teamService.autoAssignTeams(room)
        : _teamService.syncTeamsFromPlayers(room);
    return updateRoomSettings(_roleRotationService.startGame(prepared));
  }

  Future<Room> finishRoom(Room room) async {
    return updateRoomSettings(room.copyWith(status: 'finished'));
  }

  Future<Room> setPlayerReady(Room room, String uid, bool ready) async {
    final players = room.players
        .map((p) => p.uid == uid ? p.copyWith(isReady: ready) : p)
        .toList(growable: false);
    return updateRoomSettings(room.copyWith(players: players));
  }
}
