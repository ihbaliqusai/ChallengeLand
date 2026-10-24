import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_routes.dart';
import '../features/onboarding/guide_steps.dart';

class GuestGuideProvider extends ChangeNotifier {
  static const completionKey = 'guest_guide_v1_completed';
  static const trialPendingKey = 'guest_guide_v1_trial_pending';
  GuestGuideProvider({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  final Map<String, List<GlobalKey>> _targets = {};
  bool _disposed = false;
  bool _targetNoticePending = false;
  Future<void>? _initializing;
  bool loaded = false;
  bool completed = false;
  bool expanded = false;
  int stepIndex = 0;
  String route = AppRoutes.splash;
  bool lobbyReady = false;
  void Function(String route)? navigateTo;
  void setLobbyReady(bool value) {
    if (_disposed || lobbyReady == value) return;
    lobbyReady = value;
    notifyListeners();
  }

  GuideStep get step => guestGuideSteps[stepIndex];
  bool get isLast => stepIndex == guestGuideSteps.length - 1;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await _preferences();
      completed = prefs.getBool(completionKey) ?? false;
      if (prefs.getBool(trialPendingKey) == true) {
        stepIndex = guestGuideSteps.length - 1;
        completed = false;
        await prefs.remove(trialPendingKey);
      }
    } catch (_) {
      // A storage failure must still allow an optional first visit.
    }
    if (_disposed) return;
    loaded = true;
    expanded = !completed;
    notifyListeners();
  }

  void setRoute(String value) {
    if (_disposed || value == route) return;
    route = value;
    notifyListeners();
  }

  void next() {
    if (isLast) return;
    stepIndex++;
    notifyListeners();
  }

  void previous() {
    if (stepIndex == 0) return;
    stepIndex--;
    notifyListeners();
  }

  void explain(String target) {
    final index = guestGuideSteps.indexWhere((step) => step.target == target);
    stepIndex = index < 0 ? guestGuideSteps.length - 1 : index;
    expanded = true;
    notifyListeners();
  }

  void resume() {
    expanded = true;
    notifyListeners();
  }

  void restart() {
    stepIndex = 0;
    expanded = true;
    notifyListeners();
  }

  Future<void> minimize() async {
    completed = true;
    expanded = false;
    notifyListeners();
    try {
      await (await _preferences()).setBool(completionKey, true);
    } catch (_) {
      // The guide remains usable even if its preference cannot be saved.
    }
  }

  void showChoices() => explain(GuideTargets.ready);

  void register(String id, GlobalKey key) {
    final keys = _targets.putIfAbsent(id, () => []);
    if (!keys.contains(key)) keys.add(key);
    if (_targetNoticePending) return;
    _targetNoticePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _targetNoticePending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void unregister(String id, GlobalKey key) => _targets[id]?.remove(key);

  BuildContext? targetContext() {
    for (final key in (_targets[step.target] ?? <GlobalKey>[]).reversed) {
      final context = key.currentContext;
      if (context != null && ModalRoute.of(context)?.isCurrent == true) {
        return context;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class GuestGuideObserver extends NavigatorObserver {
  GuestGuideObserver(this.guide);
  final GuestGuideProvider guide;

  void _update(Route<dynamic>? route) {
    final rawName = route?.settings.name;
    final name = rawName == '/' ? AppRoutes.home : rawName ?? 'dialog';
    WidgetsBinding.instance.addPostFrameCallback((_) => guide.setRoute(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}
