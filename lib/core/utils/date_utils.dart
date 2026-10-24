import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChallengeDateUtils {
  const ChallengeDateUtils._();

  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String todayKey([DateTime? now]) {
    return DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());
  }

  static String formatArabicDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'ar').format(date);
  }
}
