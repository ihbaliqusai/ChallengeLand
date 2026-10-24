import 'package:cloud_firestore/cloud_firestore.dart';

/// Mutually exclusive activity groups for the player discovery feed.
enum SocialPlayerActivity { online, lastHour, lastSixHours, today }

class SocialActivity {
  SocialActivity._();

  static const presenceLease = Duration(seconds: 75);
  static const _clockTolerance = Duration(seconds: 10);

  static DateTime? _heartbeat(Map<String, dynamic>? data) {
    final stamp = data?['heartbeatAt'];
    return stamp is Timestamp ? stamp.toDate() : null;
  }

  /// Presence expires independently of snapshots. Call this again when the
  /// screen's clock advances, so a disconnected player moves out of online.
  static SocialPlayerActivity? classify(
      Map<String, dynamic>? data, DateTime now) {
    final lastSeen = _heartbeat(data);
    if (lastSeen == null) return null;
    final age = now.difference(lastSeen);
    if (age < -_clockTolerance) return null;
    final state = data?['state'];
    if (age < presenceLease && (state == 'available' || state == 'in_match')) {
      return SocialPlayerActivity.online;
    }
    if (age < const Duration(hours: 1)) {
      return SocialPlayerActivity.lastHour;
    }
    if (age < const Duration(hours: 6)) {
      return SocialPlayerActivity.lastSixHours;
    }
    final calendarSeen = now.isUtc ? lastSeen.toUtc() : lastSeen.toLocal();
    if (calendarSeen.year == now.year &&
        calendarSeen.month == now.month &&
        calendarSeen.day == now.day) {
      return SocialPlayerActivity.today;
    }
    return null;
  }

  static String lastSeenLabel(Map<String, dynamic>? data, DateTime now) {
    if (classify(data, now) == SocialPlayerActivity.online) {
      return data?['state'] == 'in_match' ? 'في مباراة الآن' : 'متصل الآن';
    }
    final lastSeen = _heartbeat(data);
    if (lastSeen == null || now.difference(lastSeen) < -_clockTolerance) {
      return 'آخر ظهور غير معروف';
    }
    final age = now.difference(lastSeen);
    if (age.inMinutes < 1) return 'آخر ظهور منذ لحظات';
    if (age.inHours < 1) {
      return 'آخر ظهور منذ ${_unit(age.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
    }
    if (age.inDays < 1) {
      return 'آخر ظهور منذ ${_unit(age.inHours, 'ساعة', 'ساعتين', 'ساعات')}';
    }
    return 'آخر ظهور منذ ${_unit(age.inDays, 'يوم', 'يومين', 'أيام')}';
  }

  static String _unit(int count, String single, String dual, String plural) {
    if (count == 1) return single;
    if (count == 2) return dual;
    return '$count ${count <= 10 ? plural : single}';
  }
}
