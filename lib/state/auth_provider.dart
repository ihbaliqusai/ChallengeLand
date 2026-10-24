import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserService? userService})
    : _authService = authService ?? AuthService(),
      _userService = userService ?? UserService();

  final AuthService _authService;
  final UserService _userService;

  UserProfile? _user;
  bool _isLoading = false;
  String? _error;

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<void> signInAsGuest() async {
    await _run(() async {
      _user = await _authService.signInAnonymously();
    }, fallback: AppStrings.loginFailed);
  }

  Future<void> signInWithGoogle() async {
    await _run(() async {
      _user = await _authService.signInWithGoogle();
    }, fallback: AppStrings.loginFailed);
  }

  Future<void> updateUsername(String username) async {
    final current = _user;
    if (current == null) return;
    await _run(() async {
      _user = await _userService.updateUsername(current, username);
    });
  }

  Future<void> applyStats({
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
    required bool won,
  }) async {
    final current = _user;
    if (current == null) return;
    _user = await _userService.updateStats(
      current,
      score: score,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      won: won,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _run(() async {
      await _authService.signOut();
      _user = null;
    });
  }

  Future<void> _run(
    Future<void> Function() action, {
    String fallback = AppStrings.unexpectedError,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error.toString().isEmpty ? fallback : error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
