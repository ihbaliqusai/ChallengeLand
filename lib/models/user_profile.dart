import '../core/utils/date_utils.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.usernameLower,
    this.photoUrl,
    this.email,
    required this.isGuest,
    required this.level,
    required this.xp,
    required this.coins,
    required this.trophies,
    required this.energy,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.totalGames,
    required this.correctAnswers,
    required this.wrongAnswers,
    this.bestCategoryId,
    this.createdAt,
    this.updatedAt,
    this.lastSeenAt,
  });

  final String uid;
  final String username;
  final String usernameLower;
  final String? photoUrl;
  final String? email;
  final bool isGuest;
  final int level;
  final int xp;
  final int coins;
  final int trophies;
  final int energy;
  final int rating;
  final int wins;
  final int losses;
  final int totalGames;
  final int correctAnswers;
  final int wrongAnswers;
  final String? bestCategoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeenAt;

  double get winRate => totalGames == 0 ? 0 : wins / totalGames;
  double get correctRate {
    final totalAnswers = correctAnswers + wrongAnswers;
    return totalAnswers == 0 ? 0 : correctAnswers / totalAnswers;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? 'لاعب جديد';
    return UserProfile(
      uid: json['uid']?.toString() ?? '',
      username: username,
      usernameLower:
          json['usernameLower']?.toString() ?? username.toLowerCase(),
      photoUrl: json['photoUrl']?.toString(),
      email: json['email']?.toString(),
      isGuest: json['isGuest'] == true,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      trophies: (json['trophies'] as num?)?.toInt() ?? 0,
      energy: (json['energy'] as num?)?.toInt() ?? 100,
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      totalGames: (json['totalGames'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correctAnswers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (json['wrongAnswers'] as num?)?.toInt() ?? 0,
      bestCategoryId: json['bestCategoryId']?.toString(),
      createdAt: ChallengeDateUtils.parse(json['createdAt']),
      updatedAt: ChallengeDateUtils.parse(json['updatedAt']),
      lastSeenAt: ChallengeDateUtils.parse(json['lastSeenAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'usernameLower': usernameLower,
    'photoUrl': photoUrl,
    'email': email,
    'isGuest': isGuest,
    'level': level,
    'xp': xp,
    'coins': coins,
    'trophies': trophies,
    'energy': energy,
    'rating': rating,
    'wins': wins,
    'losses': losses,
    'totalGames': totalGames,
    'correctAnswers': correctAnswers,
    'wrongAnswers': wrongAnswers,
    'bestCategoryId': bestCategoryId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
  };

  UserProfile copyWith({
    String? uid,
    String? username,
    String? usernameLower,
    String? photoUrl,
    String? email,
    bool? isGuest,
    int? level,
    int? xp,
    int? coins,
    int? trophies,
    int? energy,
    int? rating,
    int? wins,
    int? losses,
    int? totalGames,
    int? correctAnswers,
    int? wrongAnswers,
    String? bestCategoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      usernameLower: usernameLower ?? this.usernameLower,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      isGuest: isGuest ?? this.isGuest,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      trophies: trophies ?? this.trophies,
      energy: energy ?? this.energy,
      rating: rating ?? this.rating,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      totalGames: totalGames ?? this.totalGames,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      bestCategoryId: bestCategoryId ?? this.bestCategoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
