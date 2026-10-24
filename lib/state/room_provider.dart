import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../models/room.dart';
import '../models/user_profile.dart';
import '../services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider({RoomService? roomService})
    : _roomService = roomService ?? RoomService();

  final RoomService _roomService;

  Room? room;
  bool isLoading = false;
  String? error;

  /// يصبح true عندما يغيّر الهوست حالة الغرفة إلى 'active'
  bool gameStarting = false;

  StreamSubscription<Room?>? _roomSub;

  // ═══════════════════════════════════════════════
  // Stream listener
  // ═══════════════════════════════════════════════

  void listenToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = _roomService.listenToRoom(roomId).listen((updated) {
      if (updated == null) return;
      room = updated;
      if (updated.isActive && !gameStarting) {
        gameStarting = true;
      }
      notifyListeners();
    });
  }

  void stopListening() {
    _roomSub?.cancel();
    _roomSub = null;
  }

  // ═══════════════════════════════════════════════
  // Create / Join
  // ═══════════════════════════════════════════════

  Future<void> createRoom({
    required UserProfile host,
    required String name,
    required String mode,
    required int questionCount,
    required int maxPlayers,
    int roundDuration = 60,
    int totalRounds = 5,
  }) async {
    await _run(() async {
      room = await _roomService.createRoom(
        host: host,
        name: name,
        mode: mode,
        questionCount: questionCount,
        maxPlayers: maxPlayers,
        roundDuration: roundDuration,
        totalRounds: totalRounds,
      );
    });
  }

  Future<void> joinRoom(UserProfile user, String code) async {
    await _run(() async {
      room = await _roomService.joinRoomByCode(user: user, code: code);
    }, fallback: AppStrings.roomNotFound);
  }

  // ═══════════════════════════════════════════════
  // Ready status
  // ═══════════════════════════════════════════════

  Future<void> setReady(String uid, bool ready) async {
    final current = room;
    if (current == null) return;

    // Optimistic update
    room = current.copyWith(
      players: current.players
          .map((p) => p.uid == uid ? p.copyWith(isReady: ready) : p)
          .toList(growable: false),
    );
    notifyListeners();

    try {
      room = await _roomService.setPlayerReady(current, uid, ready);
    } catch (_) {
      room = current; // rollback on error
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Settings (host only)
  // ═══════════════════════════════════════════════

  Future<void> updateSettings({int? totalRounds, int? roundDuration}) async {
    final current = room;
    if (current == null) return;

    final updated = current.copyWith(
      totalRounds: totalRounds ?? current.totalRounds,
      roundDuration: roundDuration ?? current.roundDuration,
    );

    // Optimistic update
    room = updated;
    notifyListeners();

    try {
      room = await _roomService.updateRoomSettings(updated);
    } catch (_) {
      room = current; // rollback
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Team management
  // ═══════════════════════════════════════════════

  Future<void> assignTeam(String uid, String teamId) async {
    final current = room;
    if (current == null) return;
    room = await _roomService.assignTeam(current, uid, teamId);
    notifyListeners();
  }

  Future<void> autoAssignTeams() async {
    final current = room;
    if (current == null) return;
    room = await _roomService.autoAssignTeams(current);
    notifyListeners();
  }

  Future<void> movePlayerToTeam(String uid, String teamId) =>
      assignTeam(uid, teamId);

  Future<void> resetTeams() async {
    final current = room;
    if (current == null) return;
    room = await _roomService.resetTeams(current);
    notifyListeners();
  }

  Future<void> applyCorrectAnswer({
    required String describerUid,
    required String guesserUid,
  }) async {
    final current = room;
    if (current == null) return;
    room = await _roomService.applyCorrectAnswer(
      current,
      describerUid: describerUid,
      guesserUid: guesserUid,
    );
    notifyListeners();
  }

  Future<void> applySkip({required String describerUid}) async {
    final current = room;
    if (current == null) return;
    room = await _roomService.applySkip(current, describerUid: describerUid);
    notifyListeners();
  }

  Future<void> advanceToNextRound() async {
    final current = room;
    if (current == null) return;
    room = await _roomService.advanceToNextRound(current);
    notifyListeners();
  }

  Future<void> removePlayer(String uid) async {
    final current = room;
    if (current == null) return;
    room = await _roomService.removePlayer(current, uid);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Game lifecycle
  // ═══════════════════════════════════════════════

  Future<void> startGame() async {
    final current = room;
    if (current == null) return;
    room = await _roomService.startGame(current);
    gameStarting = true;
    notifyListeners();
  }

  Future<void> leave(UserProfile user) async {
    final current = room;
    if (current == null) return;
    await _roomService.leaveRoom(current.id, user.uid);
    room = null;
    notifyListeners();
  }

  /// مغادرة مع إيقاف الاستماع وتنظيف الحالة.
  Future<void> leaveRoom(UserProfile user) async {
    stopListening();
    gameStarting = false;
    await leave(user);
  }

  void resetGame() {
    stopListening();
    room = null;
    gameStarting = false;
    error = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Internal helpers
  // ═══════════════════════════════════════════════

  Future<void> _run(
    Future<void> Function() action, {
    String fallback = AppStrings.unexpectedError,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = exception.toString().isEmpty ? fallback : exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
