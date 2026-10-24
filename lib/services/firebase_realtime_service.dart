import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/challenge_card.dart';
import '../models/live_room_state.dart';
import '../models/player_role.dart';

class FirebaseRealtimeService {
  FirebaseRealtimeService({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  // ── مراجع المسارات ──

  DatabaseReference _roomRef(String roomId) => _db.ref('rooms/$roomId');
  DatabaseReference _stateRef(String roomId) => _db.ref('rooms/$roomId/state');
  DatabaseReference _playerRef(String roomId, String uid) =>
      _db.ref('rooms/$roomId/players/$uid');
  DatabaseReference _playersRef(String roomId) =>
      _db.ref('rooms/$roomId/players');
  DatabaseReference _answerRef(String roomId, String uid) =>
      _db.ref('rooms/$roomId/answers/$uid');
  DatabaseReference _answersRef(String roomId) =>
      _db.ref('rooms/$roomId/answers');
  DatabaseReference _cardRef(String roomId) =>
      _db.ref('rooms/$roomId/currentCard');

  // ── تهيئة الغرفة ──

  /// يستدعى عند إنشاء الغرفة: يضبط الحالة الأولية ويضيف الحضور.
  Future<void> initRoom(String roomId, {required String hostUid}) async {
    await Future.wait([
      _roomRef(roomId).update({
        'hostUid': hostUid,
        'state': {
          'phase': GamePhase.lobby.name,
          'currentRound': 0,
          'currentDescriber': null,
          'roundStartedAt': null,
          'roundDuration': 60,
        },
      }),
      setupPresence(roomId, hostUid),
    ]);
  }

  // ── الاستماع للتغيّرات (Streams) ──

  Stream<LiveRoomState> listenToRoom(String roomId) {
    return _roomRef(roomId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return const LiveRoomState(
          phase: GamePhase.lobby,
          currentRound: 0,
          roundDuration: 60,
        );
      }
      return LiveRoomState.fromRtdbMap(Map<String, dynamic>.from(raw as Map));
    });
  }

  Stream<Map<String, PlayerLiveState>> listenToPlayers(String roomId) {
    return _playersRef(roomId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return const {};
      final map = Map<String, dynamic>.from(raw as Map);
      return map.map(
        (uid, val) => MapEntry(
          uid,
          PlayerLiveState.fromRtdbMap(Map<String, dynamic>.from(val as Map)),
        ),
      );
    });
  }

  Stream<ChallengeCard?> listenToCurrentCard(String roomId) {
    return _cardRef(roomId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return null;
      return ChallengeCard.fromJson(Map<String, dynamic>.from(raw as Map));
    });
  }

  Stream<Map<String, AnswerState>> listenToAnswers(String roomId) {
    return _answersRef(roomId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return const {};
      final map = Map<String, dynamic>.from(raw as Map);
      return map.map(
        (uid, val) => MapEntry(
          uid,
          AnswerState.fromRtdbMap(Map<String, dynamic>.from(val as Map)),
        ),
      );
    });
  }

  // ── كتابة حضور اللاعب ──

  Future<void> setupPresence(String roomId, String uid) async {
    final ref = _playerRef(roomId, uid);
    await ref.set({
      'isOnline': true,
      'isReady': false,
      'lastSeen': ServerValue.timestamp,
    });
    // عند انقطاع الاتصال: يُسجَّل كغير متصل
    await ref.onDisconnect().update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Future<void> updatePlayerReady(
    String roomId,
    String uid, {
    required bool ready,
  }) {
    return _playerRef(roomId, uid).update({'isReady': ready});
  }

  Future<void> removePresence(String roomId, String uid) {
    return _playerRef(roomId, uid).remove();
  }

  // ── التحكم في الجولات (Host only) ──

  /// يبدأ جولة وصف: يضبط الحالة + البطاقة + يمسح إجابات الجولة السابقة.
  Future<void> startRound({
    required String roomId,
    required int roundNumber,
    required String describerUid,
    required int roundDuration,
    required ChallengeCard card,
  }) async {
    await Future.wait([
      _stateRef(roomId).update({
        'phase': GamePhase.describing.name,
        'currentRound': roundNumber,
        'currentDescriber': describerUid,
        'roundStartedAt': ServerValue.timestamp,
        'roundDuration': roundDuration,
      }),
      _cardRef(roomId).set(card.toJson()),
      _answersRef(roomId).remove(),
    ]);
  }

  Future<void> updateGamePhase(String roomId, GamePhase phase) {
    return _stateRef(roomId).update({'phase': phase.name});
  }

  Future<void> setCurrentCard(String roomId, ChallengeCard card) {
    return _cardRef(roomId).set(card.toJson());
  }

  Future<void> clearRoundAnswers(String roomId) {
    return _answersRef(roomId).remove();
  }

  // ── إجابات اللاعبين ──

  Future<void> submitAnswer(String roomId, String uid, String answer) {
    return _answerRef(roomId, uid).set({
      'uid': uid,
      'text': answer,
      'submittedAt': ServerValue.timestamp,
      'isCorrect': null,
    });
  }

  /// يحكم الhostt على الإجابة (وصف/تمثيل).
  Future<void> markAnswer(
    String roomId,
    String uid, {
    required bool isCorrect,
  }) {
    return _answerRef(roomId, uid).update({'isCorrect': isCorrect});
  }

  // ── تنظيف الغرفة ──

  Future<void> deleteRoom(String roomId) {
    return _roomRef(roomId).remove();
  }
}
