import '../core/utils/date_utils.dart';

/// مدخل لاعب في طابور المطابقة.
class MatchmakingEntry {
  const MatchmakingEntry({
    required this.uid,
    required this.username,
    required this.rating,
    required this.mode,
    required this.enteredAt,
    required this.status,
    this.matchedSessionId,
  });

  final String uid;
  final String username;
  final int rating;
  final String mode; // 'quick1v1' | 'teams2v2' | 'teams3v3' | 'party'
  final DateTime enteredAt;
  final String status; // 'waiting' | 'matched' | 'cancelled'
  final String? matchedSessionId;

  bool get isWaiting => status == 'waiting';
  bool get isMatched => status == 'matched';

  /// ثواني الانتظار منذ دخول الطابور.
  int get waitSeconds => DateTime.now().difference(enteredAt).inSeconds;

  factory MatchmakingEntry.fromJson(Map<String, dynamic> json) {
    return MatchmakingEntry(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      mode: json['mode']?.toString() ?? 'quick1v1',
      enteredAt: ChallengeDateUtils.parse(json['enteredAt']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'waiting',
      matchedSessionId: json['matchedSessionId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'rating': rating,
    'mode': mode,
    'enteredAt': enteredAt.toIso8601String(),
    'status': status,
    'matchedSessionId': matchedSessionId,
  };
}
