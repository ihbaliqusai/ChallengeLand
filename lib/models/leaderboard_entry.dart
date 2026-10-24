import '../core/utils/date_utils.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.username,
    this.photoUrl,
    required this.rank,
    required this.level,
    required this.score,
    required this.wins,
    required this.rating,
    this.period,
    this.updatedAt,
  });

  final String uid;
  final String username;
  final String? photoUrl;
  final int rank;
  final int level;
  final int score;
  final int wins;
  final int rating;
  final String? period;
  final DateTime? updatedAt;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        uid: json['uid']?.toString() ?? '',
        username: json['username']?.toString() ?? 'لاعب',
        photoUrl: json['photoUrl']?.toString(),
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        score: (json['score'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toInt() ?? 1000,
        period: json['period']?.toString(),
        updatedAt: ChallengeDateUtils.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'photoUrl': photoUrl,
    'rank': rank,
    'level': level,
    'score': score,
    'wins': wins,
    'rating': rating,
    'period': period,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  LeaderboardEntry copyWith({
    String? uid,
    String? username,
    String? photoUrl,
    int? rank,
    int? level,
    int? score,
    int? wins,
    int? rating,
    String? period,
    DateTime? updatedAt,
  }) {
    return LeaderboardEntry(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      rank: rank ?? this.rank,
      level: level ?? this.level,
      score: score ?? this.score,
      wins: wins ?? this.wins,
      rating: rating ?? this.rating,
      period: period ?? this.period,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
