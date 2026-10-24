import 'package:flutter/foundation.dart';

import '../models/match_history.dart';
import '../models/user_profile.dart';
import '../services/mock_data_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({MockDataService? mockDataService})
    : _mockDataService = mockDataService ?? MockDataService();

  final MockDataService _mockDataService;

  int trophies = 50;
  int coins = 10;
  int energy = 82;
  double nextUnlockProgress = 0.5;
  int selectedBottomTab = 2;
  List<MatchHistory> recentMatches = const [];
  String dailyChallengeStatus = 'جاهز';
  bool isLoading = false;
  String? error;

  Future<void> load(UserProfile? user) async {
    if (user == null) return;
    isLoading = true;
    notifyListeners();
    trophies = user.trophies;
    coins = user.coins;
    energy = user.energy;
    recentMatches = await _mockDataService.getMockHistory(user.uid);
    isLoading = false;
    notifyListeners();
  }

  void selectBottomTab(int index) {
    selectedBottomTab = index;
    notifyListeners();
  }
}
