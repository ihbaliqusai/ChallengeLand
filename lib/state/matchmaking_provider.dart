import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_strings.dart';
import '../models/game_session.dart';
import '../models/matchmaking_entry.dart';
import '../models/room.dart';
import '../models/user_profile.dart';
import '../services/matchmaking_service.dart';

enum MatchmakingState {
  idle,
  searching, // في الطابور، ينتظر خصماً
  found, // تمت المطابقة أو إنشاء الغرفة
  creatingRoom, // إنشاء غرفة خاصة
  joiningRoom, // الانضمام بكود
  error,
}

class MatchmakingProvider extends ChangeNotifier {
  MatchmakingProvider({MatchmakingService? matchmakingService})
    : _service = matchmakingService ?? MatchmakingService();

  final MatchmakingService _service;

  MatchmakingState state = MatchmakingState.idle;
  GameSession? session; // جلسة اللعب بعد المطابقة
  Room? room; // غرفة خاصة/فرق بعد الإنشاء أو الانضمام
  bool isBotMatch = false;
  String? error;
  int waitSeconds = 0; // مدة الانتظار للعرض في الواجهة

  bool get isSearching => state == MatchmakingState.searching;
  bool get isFound => state == MatchmakingState.found;
  bool get isBusy =>
      state == MatchmakingState.searching ||
      state == MatchmakingState.creatingRoom ||
      state == MatchmakingState.joiningRoom;

  Timer? _waitTimer;
  Timer? _botTimer;
  StreamSubscription<MatchmakingEntry?>? _queueSub;
  String? _pendingUid;

  // ═══════════════════════════════════════════════
  // مطابقة سريعة 1v1
  // ═══════════════════════════════════════════════

  Future<void> startQuickMatch(
    UserProfile user, {
    String mode = 'quick1v1',
  }) async {
    if (state != MatchmakingState.idle) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) &&
        !AppConfig.useMockData) {
      _setError(AppStrings.weakConnection);
      return;
    }

    state = MatchmakingState.searching;
    waitSeconds = 0;
    isBotMatch = false;
    error = null;
    notifyListeners();

    if (AppConfig.useMockData) {
      _runMockSearch(user);
      return;
    }

    try {
      await _service.joinQueue(user, mode);
      _pendingUid = user.uid;
      _startWaitTimer();
      _startBotFallback(user);
      _subscribeToQueue(user);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // وضع التجربة: محاكاة مطابقة بعد 2.5 ثانية
  void _runMockSearch(UserProfile user) {
    _startWaitTimer();
    Timer(const Duration(milliseconds: 2500), () async {
      if (state != MatchmakingState.searching) return;
      session = await _service.createBotSession(user);
      isBotMatch = true;
      state = MatchmakingState.found;
      _stopTimers();
      notifyListeners();
    });
  }

  void _startWaitTimer() {
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      waitSeconds++;
      notifyListeners();
    });
  }

  // بوت fallback بعد 90 ثانية بدون مطابقة
  void _startBotFallback(UserProfile user) {
    _botTimer = Timer(const Duration(seconds: 90), () async {
      if (state != MatchmakingState.searching) return;
      await _service.leaveQueue(user.uid);
      session = await _service.createBotSession(user);
      isBotMatch = true;
      state = MatchmakingState.found;
      _stopTimers();
      notifyListeners();
    });
  }

  void _subscribeToQueue(UserProfile user) {
    _queueSub = _service.listenToQueueEntry(user.uid).listen((entry) async {
      if (state != MatchmakingState.searching) return;
      if (entry?.isMatched != true || entry?.matchedSessionId == null) return;

      try {
        session = await _service.fetchSession(entry!.matchedSessionId!);
        isBotMatch = false;
        state = MatchmakingState.found;
      } catch (e) {
        _setError(e.toString());
        return;
      }
      _stopTimers();
      notifyListeners();
    }, onError: (Object e) => _setError(e.toString()));
  }

  Future<void> cancelSearch() async {
    final uid = _pendingUid;
    _stopTimers();
    _pendingUid = null;
    state = MatchmakingState.idle;
    notifyListeners();
    if (uid != null) await _service.leaveQueue(uid);
  }

  // للتوافق مع الكود القديم
  Future<void> cancel(String uid) => cancelSearch();

  // ═══════════════════════════════════════════════
  // غرفة خاصة
  // ═══════════════════════════════════════════════

  Future<void> createPrivateRoom(
    UserProfile host, {
    String mode = 'quick1v1',
    int maxPlayers = 4,
  }) async {
    state = MatchmakingState.creatingRoom;
    error = null;
    notifyListeners();
    try {
      room = await _service.createPrivateRoom(
        host,
        mode: mode,
        maxPlayers: maxPlayers,
      );
      state = MatchmakingState.found;
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> joinByCode(UserProfile user, String code) async {
    if (code.trim().isEmpty) {
      _setError('أدخل كود الغرفة.');
      return;
    }
    state = MatchmakingState.joiningRoom;
    error = null;
    notifyListeners();
    try {
      room = await _service.joinPrivateRoomByCode(user, code);
      state = MatchmakingState.found;
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> shareRoomCode(String code) async {
    await _service.copyCodeToClipboard(code);
  }

  // ═══════════════════════════════════════════════
  // إدارة الفرق
  // ═══════════════════════════════════════════════

  void autoAssignTeams() {
    if (room == null) return;
    room = _service.autoAssignTeams(room!);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // إعادة الضبط
  // ═══════════════════════════════════════════════

  void reset() {
    _stopTimers();
    state = MatchmakingState.idle;
    session = null;
    room = null;
    isBotMatch = false;
    error = null;
    waitSeconds = 0;
    _pendingUid = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════

  void _setError(String msg) {
    error = msg;
    state = MatchmakingState.error;
    _stopTimers();
    notifyListeners();
  }

  void _stopTimers() {
    _waitTimer?.cancel();
    _waitTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
    _queueSub?.cancel();
    _queueSub = null;
    waitSeconds = 0;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
