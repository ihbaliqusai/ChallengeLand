import 'package:challenge_land/models/social_player_activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);
  Map<String, dynamic> presence(Duration age, {String state = 'available'}) => {
        'heartbeatAt': Timestamp.fromDate(now.subtract(age)),
        'state': state,
      };

  test('activity groups are exclusive at lease, hour, and six-hour boundaries',
      () {
    final cases = {
      const Duration(seconds: 74): SocialPlayerActivity.online,
      const Duration(seconds: 75): SocialPlayerActivity.lastHour,
      const Duration(minutes: 59, seconds: 59): SocialPlayerActivity.lastHour,
      const Duration(hours: 1): SocialPlayerActivity.lastSixHours,
      const Duration(hours: 5, minutes: 59, seconds: 59):
          SocialPlayerActivity.lastSixHours,
      const Duration(hours: 6): SocialPlayerActivity.today,
      const Duration(hours: 12): SocialPlayerActivity.today,
    };
    for (final entry in cases.entries) {
      expect(SocialActivity.classify(presence(entry.key), now), entry.value,
          reason: '${entry.key}');
    }
    expect(SocialActivity.classify(presence(const Duration(hours: 25)), now),
        isNull);
  });

  test('away is offline immediately and expired match presence is recent', () {
    expect(SocialActivity.classify(presence(Duration.zero, state: 'away'), now),
        SocialPlayerActivity.lastHour);
    expect(
        SocialActivity.classify(
            presence(const Duration(seconds: 74), state: 'in_match'), now),
        SocialPlayerActivity.online);
    expect(
        SocialActivity.classify(
            presence(const Duration(seconds: 75), state: 'in_match'), now),
        SocialPlayerActivity.lastHour);
  });

  test('hour groups span midnight but today excludes previous calendar days',
      () {
    final afterMidnight = DateTime.utc(2026, 10, 12, 0, 30);
    Map<String, dynamic> earlier(Duration age) => {
          'heartbeatAt': Timestamp.fromDate(afterMidnight.subtract(age)),
          'state': 'away',
        };
    expect(
        SocialActivity.classify(
            earlier(const Duration(minutes: 45)), afterMidnight),
        SocialPlayerActivity.lastHour);
    expect(
        SocialActivity.classify(
            earlier(const Duration(hours: 3)), afterMidnight),
        SocialPlayerActivity.lastSixHours);
    expect(
        SocialActivity.classify(
            earlier(const Duration(hours: 6)), afterMidnight),
        isNull);
  });

  test('malformed and future timestamps are not exposed as active players', () {
    expect(SocialActivity.classify(null, now), isNull);
    expect(SocialActivity.classify({'heartbeatAt': 'invalid'}, now), isNull);
    expect(SocialActivity.classify(presence(const Duration(seconds: -11)), now),
        isNull);
    expect(SocialActivity.classify(presence(const Duration(seconds: -10)), now),
        SocialPlayerActivity.online);
  });

  test('Arabic last-seen labels distinguish live matches and elapsed time', () {
    expect(SocialActivity.lastSeenLabel(presence(Duration.zero), now),
        'متصل الآن');
    expect(
        SocialActivity.lastSeenLabel(
            presence(Duration.zero, state: 'in_match'), now),
        'في مباراة الآن');
    expect(
        SocialActivity.lastSeenLabel(
            presence(Duration.zero, state: 'away'), now),
        'آخر ظهور منذ لحظات');
    for (final entry in {
      const Duration(minutes: 1, seconds: 15): 'آخر ظهور منذ دقيقة',
      const Duration(minutes: 2): 'آخر ظهور منذ دقيقتين',
      const Duration(minutes: 3): 'آخر ظهور منذ 3 دقائق',
      const Duration(minutes: 15): 'آخر ظهور منذ 15 دقيقة',
      const Duration(hours: 1): 'آخر ظهور منذ ساعة',
      const Duration(hours: 2): 'آخر ظهور منذ ساعتين',
      const Duration(hours: 3): 'آخر ظهور منذ 3 ساعات',
      const Duration(hours: 11): 'آخر ظهور منذ 11 ساعة',
    }.entries) {
      expect(
          SocialActivity.lastSeenLabel(presence(entry.key), now), entry.value);
    }
    expect(SocialActivity.lastSeenLabel(null, now), 'آخر ظهور غير معروف');
  });
}
