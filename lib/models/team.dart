import 'package:flutter/material.dart';

import 'player_role.dart';
import 'room_player.dart';

class Team {
  Team({
    required this.id,
    required this.name,
    required Object color,
    required this.emoji,
    List<PlayerInTeam>? players,
    List<String>? playerIds,
    required this.score,
    this.roundScores = const [],
    this.describerIndex = 0,
  }) : color = parseColor(color),
       players = players ?? _playersFromIds(playerIds ?? const []);

  final String id;
  final String name;
  final Color color;
  final String emoji;
  final List<PlayerInTeam> players;
  final int score;
  final List<int> roundScores;
  final int describerIndex;

  String? get currentDescriberUid {
    if (players.isEmpty) return null;
    return players[describerIndex % players.length].uid;
  }

  List<String> get playerIds =>
      players.map((player) => player.uid).toList(growable: false);

  int get playerCount => players.length;
  int get roundsPlayed => roundScores.length;
  String get colorHex => colorToHex(color);

  static const List<_TeamPreset> _presets = [
    _TeamPreset(
      id: 'red',
      name: 'الفريق الأحمر',
      color: Color(0xFFEF4444),
      emoji: '🔴',
    ),
    _TeamPreset(
      id: 'blue',
      name: 'الفريق الأزرق',
      color: Color(0xFF3B82F6),
      emoji: '🔵',
    ),
    _TeamPreset(
      id: 'green',
      name: 'الفريق الأخضر',
      color: Color(0xFF22C55E),
      emoji: '🟢',
    ),
    _TeamPreset(
      id: 'yellow',
      name: 'الفريق الأصفر',
      color: Color(0xFFEAB308),
      emoji: '🟡',
    ),
  ];

  static Team fromPreset(int index) {
    final p = _presets[index % _presets.length];
    return Team(
      id: p.id,
      name: p.name,
      color: p.color,
      emoji: p.emoji,
      players: const [],
      score: 0,
    );
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    final players = rawPlayers is List
        ? rawPlayers
              .whereType<Map<String, dynamic>>()
              .map(PlayerInTeam.fromJson)
              .toList(growable: false)
        : _playersFromIds(
            (json['playerIds'] as List<dynamic>? ?? const [])
                .map((item) => item.toString())
                .toList(growable: false),
          );

    return Team(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color'] ?? const Color(0xFF3B82F6),
      emoji: json['emoji']?.toString() ?? '🎯',
      players: players,
      score: (json['score'] as num?)?.toInt() ?? 0,
      roundScores: (json['roundScores'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(growable: false),
      describerIndex: (json['describerIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': colorHex,
    'emoji': emoji,
    'players': players.map((player) => player.toJson()).toList(),
    'playerIds': playerIds,
    'score': score,
    'roundScores': roundScores,
    'describerIndex': describerIndex,
  };

  Team copyWith({
    String? id,
    String? name,
    Object? color,
    String? emoji,
    List<PlayerInTeam>? players,
    List<String>? playerIds,
    int? score,
    List<int>? roundScores,
    int? describerIndex,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      players: players ?? (playerIds == null ? this.players : null),
      playerIds: playerIds,
      score: score ?? this.score,
      roundScores: roundScores ?? this.roundScores,
      describerIndex: describerIndex ?? this.describerIndex,
    );
  }

  Team addPoints(int points, {int? round}) => copyWith(
    score: score + points,
    roundScores: round == null
        ? roundScores
        : _addRoundPoints(roundScores, round, points),
  );

  Team recordRoundScore(int roundPoints) => copyWith(
    roundScores: [...roundScores, roundPoints],
    score: score + roundPoints,
  );

  Team advanceDescriber() => players.isEmpty
      ? this
      : copyWith(describerIndex: (describerIndex + 1) % players.length);

  Team markCurrentDescriber(String? uid) => copyWith(
    players: [
      for (final player in players)
        player.copyWith(isCurrentDescriber: player.uid == uid),
    ],
  );

  static Color parseColor(Object? value) {
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());

    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return const Color(0xFF3B82F6);
    final normalized = raw
        .replaceFirst('#', '')
        .replaceFirst('0x', '')
        .replaceFirst('0X', '');
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF3B82F6);
  }

  static String colorToHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static List<int> _addRoundPoints(List<int> existing, int round, int points) {
    final index = round <= 0 ? 0 : round - 1;
    final scores = [...existing];
    while (scores.length <= index) {
      scores.add(0);
    }
    scores[index] += points;
    return scores;
  }

  static List<PlayerInTeam> _playersFromIds(List<String> ids) => [
    for (final uid in ids)
      PlayerInTeam(
        uid: uid,
        username: '',
        avatar: '',
        score: 0,
        correctAnswers: 0,
        role: PlayerRole.guesser,
        isCurrentDescriber: false,
      ),
  ];
}

class PlayerInTeam {
  const PlayerInTeam({
    required this.uid,
    required this.username,
    required this.avatar,
    required this.score,
    required this.correctAnswers,
    required this.role,
    required this.isCurrentDescriber,
  });

  final String uid;
  final String username;
  final String avatar;
  final int score;
  final int correctAnswers;
  final PlayerRole role;
  final bool isCurrentDescriber;

  factory PlayerInTeam.fromRoomPlayer(
    RoomPlayer player, {
    bool isCurrentDescriber = false,
  }) {
    return PlayerInTeam(
      uid: player.uid,
      username: player.username,
      avatar: player.photoUrl ?? '',
      score: player.score,
      correctAnswers: player.correctGuesses,
      role: player.role,
      isCurrentDescriber: isCurrentDescriber,
    );
  }

  factory PlayerInTeam.fromJson(Map<String, dynamic> json) {
    return PlayerInTeam(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? json['photoUrl']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctAnswers:
          (json['correctAnswers'] as num?)?.toInt() ??
          (json['correctGuesses'] as num?)?.toInt() ??
          0,
      role: _parseRole(json['role']?.toString()),
      isCurrentDescriber: json['isCurrentDescriber'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'avatar': avatar,
    'score': score,
    'correctAnswers': correctAnswers,
    'role': role.name,
    'isCurrentDescriber': isCurrentDescriber,
  };

  PlayerInTeam copyWith({
    String? uid,
    String? username,
    String? avatar,
    int? score,
    int? correctAnswers,
    PlayerRole? role,
    bool? isCurrentDescriber,
  }) {
    return PlayerInTeam(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      role: role ?? this.role,
      isCurrentDescriber: isCurrentDescriber ?? this.isCurrentDescriber,
    );
  }

  static PlayerRole _parseRole(String? value) {
    switch (value) {
      case 'host':
        return PlayerRole.host;
      case 'describer':
        return PlayerRole.describer;
      case 'guesser':
        return PlayerRole.guesser;
      case 'spectator':
        return PlayerRole.spectator;
      case 'judge':
        return PlayerRole.judge;
      default:
        return PlayerRole.guesser;
    }
  }
}

class _TeamPreset {
  const _TeamPreset({
    required this.id,
    required this.name,
    required this.color,
    required this.emoji,
  });

  final String id;
  final String name;
  final Color color;
  final String emoji;
}
