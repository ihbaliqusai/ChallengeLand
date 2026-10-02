import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/core/app_state.dart';

void main() {
  group('Daily Reward & Streak Tests', () {
    test('AppState.streakRewards contains 30 days of balanced rewards', () {
      expect(AppState.streakRewards.length, 30);

      // Verify Day 1
      final day1 = AppState.getRewardForDay(1);
      expect(day1['coins'], greaterThanOrEqualTo(100));
      expect(day1['gems'], greaterThanOrEqualTo(0));

      // Verify Day 7 milestone
      final day7 = AppState.getRewardForDay(7);
      expect(day7['coins'], greaterThanOrEqualTo(500));
      expect(day7['gems'], greaterThanOrEqualTo(3));

      // Verify Day 30 grand milestone
      final day30 = AppState.getRewardForDay(30);
      expect(day30['coins'], 2000);
      expect(day30['gems'], 15);
    });

    test('AppState.getRewardForDay clamps correctly out of range', () {
      final below = AppState.getRewardForDay(0);
      expect(below, AppState.streakRewards.first);

      final above = AppState.getRewardForDay(999);
      expect(above, AppState.streakRewards.last);
    });
  });
}
