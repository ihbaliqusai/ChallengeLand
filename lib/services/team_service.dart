import '../models/player_role.dart';
import '../models/room.dart';
import '../models/room_player.dart';
import '../models/team.dart';

class TeamService {
  const TeamService();

  static const int correctDescriberPoints = 2;
  static const int correctGuesserPoints = 3;
  static const int correctTeamPoints = 5;
  static const int skipDescriberPenalty = -1;

  Room ensureDefaultTeams(Room room, {int teamCount = 2}) {
    final count = teamCount.clamp(2, 4);
    if (room.teams.length >= count) {
      return syncTeamsFromPlayers(room);
    }

    final teams = [
      ...room.teams,
      for (var i = room.teams.length; i < count; i++) Team.fromPreset(i),
    ];
    return syncTeamsFromPlayers(room.copyWith(teams: teams));
  }

  Room autoAssignTeams(Room room) {
    if (room.players.isEmpty) return ensureDefaultTeams(room);

    final prepared = ensureDefaultTeams(room);
    final teamShells = _resetTeamPlayers(prepared.teams.take(2).toList());
    final playersByStrength = [...prepared.players]
      ..sort((a, b) {
        final strengthCompare = _playerStrength(
          b,
        ).compareTo(_playerStrength(a));
        if (strengthCompare != 0) return strengthCompare;
        return a.joinedAt?.compareTo(
              b.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ) ??
            0;
      });

    final targetSizes = _targetSizes(
      playersByStrength.length,
      teamShells.length,
    );
    final assignments = List.generate(teamShells.length, (_) => <RoomPlayer>[]);

    for (var i = 0; i < playersByStrength.length; i++) {
      final round = i ~/ teamShells.length;
      final preferred = round.isEven
          ? i % teamShells.length
          : (teamShells.length - 1) - (i % teamShells.length);
      final target = _openTeamIndex(assignments, targetSizes, preferred);
      assignments[target].add(playersByStrength[i]);
    }

    final players = [
      for (final player in prepared.players)
        player.copyWith(
          teamId: _teamIdForPlayer(player.uid, teamShells, assignments),
        ),
    ];

    final teams = [
      for (var i = 0; i < teamShells.length; i++)
        teamShells[i].copyWith(
          players: [
            for (final player in assignments[i])
              PlayerInTeam.fromRoomPlayer(
                player.copyWith(teamId: teamShells[i].id),
              ),
          ],
          describerIndex: 0,
        ),
    ];

    return prepared.copyWith(
      players: players,
      teams: teams,
      clearCurrentDescriber: true,
      clearCurrentTeamDescribingId: true,
      updatedAt: DateTime.now(),
    );
  }

  Room movePlayerToTeam(Room room, String uid, String teamId) {
    final prepared = ensureDefaultTeams(room);
    if (!prepared.teams.any((team) => team.id == teamId)) return prepared;

    final players = prepared.players
        .map(
          (player) =>
              player.uid == uid ? player.copyWith(teamId: teamId) : player,
        )
        .toList(growable: false);

    return syncTeamsFromPlayers(
      prepared.copyWith(players: players, updatedAt: DateTime.now()),
    );
  }

  Room resetTeams(Room room) {
    final teams = _resetTeamPlayers(
      (room.teams.isEmpty
              ? [Team.fromPreset(0), Team.fromPreset(1)]
              : room.teams)
          .toList(),
    );
    final players = room.players
        .map((player) => player.copyWith(teamId: ''))
        .toList(growable: false);
    return room.copyWith(
      players: players,
      teams: teams,
      clearCurrentDescriber: true,
      clearCurrentTeamDescribingId: true,
      updatedAt: DateTime.now(),
    );
  }

  Room syncTeamsFromPlayers(Room room) {
    if (room.teams.isEmpty) return room;
    final teams = [
      for (final team in room.teams)
        team.copyWith(
          players: [
            for (final player in room.players.where((p) => p.teamId == team.id))
              PlayerInTeam.fromRoomPlayer(
                player,
                isCurrentDescriber: player.uid == room.currentDescriber,
              ),
          ],
        ),
    ];
    return room.copyWith(teams: teams);
  }

  Room applyRolesForRound(Room room) {
    final synced = syncTeamsFromPlayers(room);
    final describingTeam = describingTeamForRound(synced);
    final describerUid = describingTeam?.currentDescriberUid;

    final players = synced.players
        .map((player) {
          if (player.uid == describerUid) {
            return player.copyWith(role: PlayerRole.describer);
          }
          if (describingTeam != null) {
            return player.copyWith(
              role: player.teamId == describingTeam.id
                  ? PlayerRole.spectator
                  : PlayerRole.guesser,
            );
          }
          return player.copyWith(role: PlayerRole.guesser);
        })
        .toList(growable: false);

    return syncTeamsFromPlayers(
      synced.copyWith(
        players: players,
        currentDescriber: describerUid,
        currentTeamDescribingId: describingTeam?.id,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Team? describingTeamForRound(Room room) {
    if (room.teams.isEmpty || room.currentRound <= 0) return null;
    return room.teams[(room.currentRound - 1) % room.teams.length];
  }

  Team? guessingTeamForRound(Room room) {
    final describingTeam = describingTeamForRound(room);
    if (describingTeam == null || room.teams.length < 2) return null;
    return room.teams.firstWhere(
      (team) => team.id != describingTeam.id,
      orElse: () => room.teams.first,
    );
  }

  Room advanceDescriberForFinishedRound(Room room) {
    final describingTeam = describingTeamForRound(room);
    if (describingTeam == null) return room;
    final teams = [
      for (final team in room.teams)
        team.id == describingTeam.id ? team.advanceDescriber() : team,
    ];
    return room.copyWith(teams: teams);
  }

  Room applyCorrectAnswer(
    Room room, {
    required String describerUid,
    required String guesserUid,
  }) {
    final scoringTeamId =
        _playerByUid(room.players, guesserUid)?.teamId ??
        guessingTeamForRound(room)?.id;

    return _applyScore(
      room,
      describerUid: describerUid,
      describerDelta: correctDescriberPoints,
      guesserUid: guesserUid,
      guesserDelta: correctGuesserPoints,
      teamId: scoringTeamId,
      teamDelta: correctTeamPoints,
      isSkip: false,
      isCorrect: true,
    );
  }

  Room applySkip(Room room, {required String describerUid}) {
    return _applyScore(
      room,
      describerUid: describerUid,
      describerDelta: skipDescriberPenalty,
      guesserUid: null,
      guesserDelta: 0,
      teamId: null,
      teamDelta: 0,
      isSkip: true,
      isCorrect: false,
    );
  }

  Room _applyScore(
    Room room, {
    required String describerUid,
    required int describerDelta,
    required String? guesserUid,
    required int guesserDelta,
    required String? teamId,
    required int teamDelta,
    required bool isSkip,
    required bool isCorrect,
  }) {
    final players = room.players
        .map((player) {
          if (player.uid == describerUid) {
            return player.copyWith(
              score: player.score + describerDelta,
              personalScore: player.personalScore + describerDelta,
              skipsUsed: isSkip ? player.skipsUsed + 1 : player.skipsUsed,
            );
          }
          if (isCorrect && player.uid == guesserUid) {
            return player.copyWith(
              score: player.score + guesserDelta,
              personalScore: player.personalScore + guesserDelta,
              correctGuesses: player.correctGuesses + 1,
            );
          }
          return player;
        })
        .toList(growable: false);

    final teams = room.teams
        .map((team) {
          final updatedPlayers = team.players
              .map((player) {
                if (player.uid == describerUid) {
                  return player.copyWith(score: player.score + describerDelta);
                }
                if (isCorrect && player.uid == guesserUid) {
                  return player.copyWith(
                    score: player.score + guesserDelta,
                    correctAnswers: player.correctAnswers + 1,
                  );
                }
                return player;
              })
              .toList(growable: false);

          final withPlayers = team.copyWith(players: updatedPlayers);
          if (team.id != teamId || teamDelta == 0) return withPlayers;
          return withPlayers.addPoints(teamDelta, round: room.currentRound);
        })
        .toList(growable: false);

    return room.copyWith(
      players: players,
      teams: teams,
      updatedAt: DateTime.now(),
    );
  }

  List<Team> _resetTeamPlayers(List<Team> teams) => [
    for (final team in teams)
      team.copyWith(
        players: const [],
        describerIndex: 0,
        roundScores: const [],
        score: 0,
      ),
  ];

  List<int> _targetSizes(int playersCount, int teamsCount) {
    final base = playersCount ~/ teamsCount;
    final extra = playersCount % teamsCount;
    return [for (var i = 0; i < teamsCount; i++) base + (i < extra ? 1 : 0)];
  }

  int _openTeamIndex(
    List<List<RoomPlayer>> assignments,
    List<int> targetSizes,
    int preferred,
  ) {
    if (assignments[preferred].length < targetSizes[preferred]) {
      return preferred;
    }

    var fallback = 0;
    for (var i = 1; i < assignments.length; i++) {
      if (assignments[i].length >= targetSizes[i]) continue;
      if (assignments[fallback].length >= targetSizes[fallback] ||
          _teamStrength(assignments[i]) <
              _teamStrength(assignments[fallback])) {
        fallback = i;
      }
    }
    return fallback;
  }

  String? _teamIdForPlayer(
    String uid,
    List<Team> teams,
    List<List<RoomPlayer>> assignments,
  ) {
    for (var i = 0; i < assignments.length; i++) {
      if (assignments[i].any((player) => player.uid == uid)) {
        return teams[i].id;
      }
    }
    return null;
  }

  int _playerStrength(RoomPlayer player) {
    return player.score +
        player.personalScore +
        (player.correctGuesses * 10) -
        (player.skipsUsed * 2);
  }

  int _teamStrength(List<RoomPlayer> players) =>
      players.fold(0, (total, player) => total + _playerStrength(player));

  RoomPlayer? _playerByUid(List<RoomPlayer> players, String uid) {
    for (final player in players) {
      if (player.uid == uid) return player;
    }
    return null;
  }
}
