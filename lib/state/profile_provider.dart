import 'package:flutter/foundation.dart';

import '../models/match_history.dart';
import '../models/user_profile.dart';
import '../services/mock_data_service.dart';
import '../services/user_service.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({UserService? userService, MockDataService? mockDataService})
    : _userService = userService ?? UserService(),
      _mockDataService = mockDataService ?? MockDataService();

  final UserService _userService;
  final MockDataService _mockDataService;

  UserProfile? profile;
  List<MatchHistory> history = const [];
  bool isLoading = false;
  String? error;

  Future<void> load(UserProfile user) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _userService.getUserProfile(user.uid) ?? user;
      history = await _mockDataService.getMockHistory(user.uid);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
