import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../core/utils/room_code_generator.dart';
import '../models/game_session.dart';
import '../models/matchmaking_entry.dart';
import '../models/player_role.dart';
import '../models/room.dart';
import '../models/room_player.dart';
import '../models/team.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';
import 'team_service.dart';

class MatchmakingService {
  MatchmakingService({
    MockDataService? mockDataService,
    FirebaseFirestore? firestore,
    RoomCodeGenerator? codeGenerator,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firestore = firestore,
       _codeGenerator = codeGenerator ?? RoomCodeGenerator();

  final MockDataService _mockDataService;
  final FirebaseFirestore? _firestore;
  final RoomCodeGenerator _codeGenerator;
  final TeamService _teamService = const TeamService();

  static const int _roomExpiryMinutes = 30;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════
  // طابور المطابقة
  // ═══════════════════════════════════════════════

  Future<void> joinQueue(UserProfile user, String mode) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.matchmakingQueue)
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'username': user.username,
          'rating': user.rating,
          'mode': mode,
          'enteredAt': FieldValue.serverTimestamp(),
          'status': 'waiting',
          'matchedSessionId': null,
        });
  }

  Future<void> leaveQueue(String uid) async {
    if (AppConfig.useMockData) return;
    await _db
        .collection(FirestoreCollections.matchmakingQueue)
        .doc(uid)
        .delete();
  }

  /// يراقب مدخل اللاعب في الطابور ويُطلق عند تغيير الحالة.
  Stream<MatchmakingEntry?> listenToQueueEntry(String uid) {
    if (AppConfig.useMockData) return const Stream.empty();
    return _db
        .collection(FirestoreCollections.matchmakingQueue)
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return MatchmakingEntry.fromJson(snap.data()!);
        });
  }

  Future<GameSession> fetchSession(String sessionId) async {
    final doc = await _db
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('لم يتم العثور على الجلسة');
    }
    return GameSession.fromJson(doc.data()!);
  }

  // ═══════════════════════════════════════════════
  // بوت (Fallback بعد 90 ثانية)
  // ═══════════════════════════════════════════════

  Future<GameSession> createBotSession(UserProfile user) {
    return _mockDataService.startMockMatch(
      player: user,
      mode: 'quick1v1',
      timerSeconds: 60,
    );
  }

  // ═══════════════════════════════════════════════
  // غرفة خاصة
  // ═══════════════════════════════════════════════

  Future<Room> createPrivateRoom(
    UserProfile host, {
    String mode = 'quick1v1',
    int maxPlayers = 4,
  }) async {
    final code = _codeGenerator.generate();

    if (AppConfig.useMockData) {
      return _mockDataService.createMockRoom(
        host: host,
        code: code,
        name: 'غرفة ${host.username}',
        mode: mode,
        questionCount: 10,
        maxPlayers: maxPlayers,
      );
    }

    final gameType = GameTypeX.fromString(mode);
    final now = DateTime.now();
    final doc = _db.collection(FirestoreCollections.rooms).doc();

    final room = Room(
      id: doc.id,
      code: code,
      name: 'غرفة ${host.username}',
      hostId: host.uid,
      mode: mode,
      gameType: gameType,
      questionCount: 10,
      maxPlayers: maxPlayers,
      roundDuration: 60,
      totalRounds: 5,
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

    // expiresAt مخزون في Firestore فقط (ليس في نموذج Room)
    await doc.set({
      ...room.toJson(),
      'expiresAt': Timestamp.fromDate(
        now.add(const Duration(minutes: _roomExpiryMinutes)),
      ),
    });

    return room;
  }

  Future<Room> joinPrivateRoomByCode(UserProfile user, String code) async {
    if (AppConfig.useMockData) {
      throw StateError('استخدم زر "إنشاء غرفة" في وضع التجربة.');
    }

    final snapshot = await _db
        .collection(FirestoreCollections.rooms)
        .where('code', isEqualTo: code.trim().toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError('الغرفة غير موجودة أو انتهت صلاحيتها.');
    }

    final data = snapshot.docs.first.data();

    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw StateError('انتهت صلاحية هذه الغرفة ($_roomExpiryMinutes دقيقة).');
    }

    final room = Room.fromJson(data);
    if (room.isFull) throw StateError('الغرفة ممتلئة.');
    if (room.players.any((p) => p.uid == user.uid)) return room;

    final newPlayer = RoomPlayer(
      uid: user.uid,
      username: user.username,
      photoUrl: user.photoUrl,
      isHost: false,
      isReady: false,
      score: 0,
      role: PlayerRole.guesser,
      joinedAt: DateTime.now(),
    );

    final updatedPlayers = [...room.players, newPlayer];

    await snapshot.docs.first.reference.update({
      'players': updatedPlayers.map((p) => p.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return room.copyWith(players: updatedPlayers);
  }

  // ═══════════════════════════════════════════════
  // توزيع الفرق (Snake Draft)
  // ═══════════════════════════════════════════════

  /// يوزّع اللاعبين بشكل متوازن على الفرق عبر خوارزمية Snake Draft.
  /// مثال لـ 4 لاعبين (0-3 مرتبون من الأعلى تقييماً):
  ///   فريق A: [0, 3]  |  فريق B: [1, 2]
  Room autoAssignTeams(Room room) {
    return _teamService.autoAssignTeams(room);
  }

  // ═══════════════════════════════════════════════
  // Clipboard
  // ═══════════════════════════════════════════════

  Future<void> copyCodeToClipboard(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
  }
}
