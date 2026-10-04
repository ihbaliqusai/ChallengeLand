import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/player_rank.dart';
import '../core/trophy_league.dart';
import '../services/progression_service.dart';

class PlayerProfile {
  PlayerProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.photoUrl,
    required this.wins,
    required this.losses,
    required this.totalMatches,
    required this.totalScore,
    required this.rating,
    required this.createdAt,
    required this.lastSeenAt,
    this.xp = 0,
    this.level = 1,
    this.trophies = 0,
    this.bestTrophies = 0,
    this.draws = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.friendCode = '',
    this.progressionVersion = 0,
    this.playerStats = const <String, int>{},
  });

  final String uid;
  final String email;
  final String username;
  final String? photoUrl;
  final int wins;
  final int losses;
  final int totalMatches;
  final int totalScore;
  final int rating;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final int xp;
  final int level;
  final int trophies;
  final int bestTrophies;
  final int draws;
  final int correctAnswers;
  final int wrongAnswers;
  final String friendCode;
  final int progressionVersion;
  final Map<String, int> playerStats;

  PlayerRankTier get rank => PlayerRank.tierForLevel(level);
  TrophyLeague get league => TrophyProgression.leagueFor(trophies);
  int get accuracy => playerStats['accuracy'] ?? 0;
  int get winPercent => playerStats['winPercent'] ?? 0;

  factory PlayerProfile.empty() => PlayerProfile(
        uid: '',
        email: '',
        username: 'لاعب',
        photoUrl: null,
        wins: 0,
        losses: 0,
        totalMatches: 0,
        totalScore: 0,
        rating: 1000,
        createdAt: null,
        lastSeenAt: null,
      );

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    final stats = ProgressionService.readStats(map);
    final hasXp = map['xp'] is num ||
        (map['playerStats'] is Map && map['playerStats']['xp'] is num) ||
        map['totalScore'] is num;
    return PlayerProfile(
      uid: (map['uid'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      username: _resolveUsername(map),
      photoUrl: map['photoUrl']?.toString(),
      wins: stats['wins']!,
      losses: stats['losses']!,
      totalMatches: stats['gamesPlayed']!,
      totalScore: stats['xp']!,
      rating: map['rating'] == null
          ? 1000
          : ProgressionService.integer(map['rating']),
      createdAt: _readDate(map['createdAt']),
      lastSeenAt: _readDate(map['lastSeenAt']),
      xp: stats['xp']!,
      level: hasXp
          ? stats['level']!
          : ProgressionService.integer(map['level'])
              .clamp(1, ProgressionService.maxValue),
      trophies: stats['trophies']!,
      bestTrophies: stats['bestTrophies']!,
      draws: stats['draws']!,
      correctAnswers: stats['correctAnswers']!,
      wrongAnswers: stats['wrongAnswers']!,
      friendCode: (map['friendCode'] ?? '').toString(),
      progressionVersion: ProgressionService.integer(map['progressionVersion']),
      playerStats: Map<String, int>.unmodifiable(stats),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'username': username,
        'photoUrl': photoUrl,
        'wins': wins,
        'losses': losses,
        'totalMatches': totalMatches,
        'totalScore': totalScore,
        'rating': rating,
        'createdAt': createdAt,
        'lastSeenAt': lastSeenAt,
        'xp': xp,
        'level': level,
        'trophies': trophies,
        'bestTrophies': bestTrophies,
        'draws': draws,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'friendCode': friendCode,
        'progressionVersion': progressionVersion,
        'playerStats': playerStats,
      };

  PlayerProfile copyWith({
    String? uid,
    String? email,
    String? username,
    String? photoUrl,
    int? wins,
    int? losses,
    int? totalMatches,
    int? totalScore,
    int? rating,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    int? xp,
    int? level,
    int? trophies,
    int? bestTrophies,
    int? draws,
    int? correctAnswers,
    int? wrongAnswers,
    String? friendCode,
    int? progressionVersion,
    Map<String, int>? playerStats,
  }) {
    final stats = ProgressionService.normalize({
      ...this.playerStats,
      ...?playerStats,
      'xp': xp ?? totalScore ?? playerStats?['xp'] ?? this.xp,
      'wins': wins ?? playerStats?['wins'] ?? this.wins,
      'losses': losses ?? playerStats?['losses'] ?? this.losses,
      'draws': draws ?? playerStats?['draws'] ?? this.draws,
      'gamesPlayed':
          totalMatches ?? playerStats?['gamesPlayed'] ?? this.totalMatches,
      'trophies': trophies ?? playerStats?['trophies'] ?? this.trophies,
      'bestTrophies':
          bestTrophies ?? playerStats?['bestTrophies'] ?? this.bestTrophies,
      'correctAnswers': correctAnswers ??
          playerStats?['correctAnswers'] ??
          this.correctAnswers,
      'wrongAnswers':
          wrongAnswers ?? playerStats?['wrongAnswers'] ?? this.wrongAnswers,
    });
    final changedXp =
        xp != null || totalScore != null || playerStats?['xp'] != null;
    return PlayerProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      wins: stats['wins']!,
      losses: stats['losses']!,
      totalMatches: stats['gamesPlayed']!,
      totalScore: stats['xp']!,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      xp: stats['xp']!,
      level: level ?? (changedXp ? stats['level']! : this.level),
      trophies: stats['trophies']!,
      bestTrophies: stats['bestTrophies']!,
      draws: stats['draws']!,
      correctAnswers: stats['correctAnswers']!,
      wrongAnswers: stats['wrongAnswers']!,
      friendCode: friendCode ?? this.friendCode,
      progressionVersion: progressionVersion ?? this.progressionVersion,
      playerStats: Map<String, int>.unmodifiable(stats),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static String _resolveUsername(Map<String, dynamic> map) {
    final candidates = <String?>[
      map['username']?.toString(),
      map['playerName']?.toString(),
      map['displayName']?.toString(),
      map['name']?.toString(),
      map['email']?.toString().split('@').first,
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isEmpty) continue;
      final lowered = normalized.toLowerCase();
      if (lowered == 'guest' || lowered == 'player') continue;
      return normalized;
    }

    return 'لاعب';
  }
}
