import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../screens/home/lucky_wheel_screen.dart';

/// The former daily reward entry now opens the full luck wheel page.
class DailyRewardDialog extends StatelessWidget {
  const DailyRewardDialog({super.key, this.autoOpen = false});
  final bool autoOpen;
  static bool _isShowing = false;

  static Future<void> show(BuildContext context,
      {bool autoOpen = false}) async {
    if (_isShowing) return;
    final state = context.read<AppState>();
    if (state.dailyStreakLoaded && state.claimedToday) return;
    _isShowing = true;
    try {
      if (!state.dailyStreakLoaded) await state.loadLevelData();
      if (!context.mounted || !state.dailyStreakLoaded || state.claimedToday) {
        return;
      }
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AppState>.value(
            value: state, child: const LuckyWheelScreen()),
        fullscreenDialog: true,
      ));
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => const LuckyWheelScreen();
}
