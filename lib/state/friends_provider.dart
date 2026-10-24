import 'package:flutter/foundation.dart';

import '../models/friend_request.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';

class FriendsProvider extends ChangeNotifier {
  FriendsProvider({FriendService? friendService, UserService? userService})
    : _friendService = friendService ?? FriendService(),
      _userService = userService ?? UserService();

  final FriendService _friendService;
  final UserService _userService;

  List<UserProfile> friends = const [];
  List<UserProfile> searchResults = const [];
  List<FriendRequest> requests = const [];
  bool isLoading = false;
  String? error;

  Future<void> load(UserProfile user) async {
    await _run(() async {
      friends = await _friendService.getFriends(user.uid);
      requests = await _friendService.getFriendRequests(user.uid);
    });
  }

  Future<void> search(String query) async {
    await _run(() async {
      searchResults = await _userService.searchUsersByUsername(query);
    });
  }

  Future<void> sendRequest(UserProfile from, UserProfile to) async {
    await _run(() async {
      await _friendService.sendFriendRequest(from, to);
    });
  }

  Future<void> accept(FriendRequest request) async {
    await _friendService.acceptFriendRequest(request);
    requests = requests.where((item) => item.id != request.id).toList();
    notifyListeners();
  }

  Future<void> reject(FriendRequest request) async {
    await _friendService.rejectFriendRequest(request);
    requests = requests.where((item) => item.id != request.id).toList();
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
