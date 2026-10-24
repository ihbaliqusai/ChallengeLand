import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  LeaderboardProvider({LeaderboardService? leaderboardService})
    : _leaderboardService = leaderboardService ?? LeaderboardService();

  final LeaderboardService _leaderboardService;

  bool isLoading = false;
  String? error;
  String selectedPeriod = 'today';
  List<LeaderboardEntry> entries = const [];

  Future<void> load({String period = 'today'}) async {
    isLoading = true;
    selectedPeriod = period;
    error = null;
    notifyListeners();
    try {
      entries = switch (period) {
        'week' => await _leaderboardService.getWeeklyLeaderboard(),
        'all' => await _leaderboardService.getGlobalLeaderboard(),
        _ => await _leaderboardService.getDailyLeaderboard(),
      };
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
