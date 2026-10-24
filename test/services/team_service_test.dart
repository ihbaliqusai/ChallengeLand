import 'package:challenge_land/models/player_role.dart';
import 'package:challenge_land/models/room.dart';
import 'package:challenge_land/models/room_player.dart';
import 'package:challenge_land/services/role_rotation_service.dart';
import 'package:challenge_land/services/team_service.dart';
import 'package:flutter_test/flutter_test.dart';

Room _roomWithPlayers(int count) {
  final now = DateTime.utc(2026, 1, 1);
  return Room.createNew(
    id: 'room',
    code: 'ABC123',
    name: 'غرفة الفرق',
    hostId: 'p1',
    gameType: GameType.teams2v2,
  ).copyWith(
    maxPlayers: count,
    totalRounds: 4,
    players: [
      for (var i = 1; i <= count; i++)
        RoomPlayer(
          uid: 'p$i',
          username: 'لاعب $i',
          isHost: i == 1,
          isReady: true,
          score: (count - i + 1) * 10,
          role: i == 1 ? PlayerRole.host : PlayerRole.guesser,
          joinedAt: now.add(Duration(seconds: i)),
        ),
    ],
  );
}

void main() {
  group('TeamService', () {
    const service = TeamService();

    test('auto assigns even team sizes for 2, 4, 6, and 8 players', () {
      for (final count in [2, 4, 6, 8]) {
        final room = service.autoAssignTeams(_roomWithPlayers(count));

        expect(room.teams, hasLength(2));
        expect(room.teams[0].playerCount, count ~/ 2);
        expect(room.teams[1].playerCount, count ~/ 2);
        expect(room.players.every((player) => player.teamId != null), isTrue);
      }
    });

    test('auto assigns uneven but balanced teams for 5 and 7 players', () {
      for (final count in [5, 7]) {
        final room = service.autoAssignTeams(_roomWithPlayers(count));
        final sizes = room.teams.map((team) => team.playerCount).toList();

        expect(sizes.reduce((a, b) => a > b ? a : b), (count / 2).ceil());
        expect(sizes.reduce((a, b) => a < b ? a : b), count ~/ 2);
        expect(room.teams.first.playerIds, contains('p1'));
        expect(room.teams.first.playerIds, contains('p$count'));
      }
    });

    test('manual move and reset update room players and team players', () {
      final room = service.autoAssignTeams(_roomWithPlayers(4));
      final moved = service.movePlayerToTeam(room, 'p1', 'blue');

      expect(moved.players.firstWhere((p) => p.uid == 'p1').teamId, 'blue');
      expect(
        moved.teams.firstWhere((t) => t.id == 'blue').playerIds,
        contains('p1'),
      );

      final reset = service.resetTeams(moved);
      expect(reset.teams.every((team) => team.players.isEmpty), isTrue);
      expect(reset.players.every((player) => player.teamId == ''), isTrue);
    });

    test('rotates teams and describers round-robin', () {
      final rotation = RoleRotationService();
      final assigned = service.autoAssignTeams(_roomWithPlayers(4));

      final round1 = rotation.startGame(assigned);
      expect(round1.currentRound, 1);
      expect(round1.currentTeamDescribingId, 'red');
      expect(round1.currentDescriber, round1.teams[0].players.first.uid);
      expect(
        round1.players.firstWhere((p) => p.uid == round1.currentDescriber).role,
        PlayerRole.describer,
      );

      final round2 = rotation.advanceToNextRound(round1);
      expect(round2.currentRound, 2);
      expect(round2.currentTeamDescribingId, 'blue');
      expect(round2.currentDescriber, round2.teams[1].players.first.uid);

      final round3 = rotation.advanceToNextRound(round2);
      expect(round3.currentRound, 3);
      expect(round3.currentTeamDescribingId, 'red');
      expect(round3.currentDescriber, round3.teams[0].players.last.uid);
    });

    test('applies correct answer and skip scoring rules', () {
      final rotation = RoleRotationService();
      final started = rotation.startGame(
        service.autoAssignTeams(_roomWithPlayers(4)),
      );
      final describerUid = started.currentDescriber!;
      final guesser = started.players.firstWhere(
        (player) => player.teamId != started.currentTeamDescribingId,
      );

      final correct = service.applyCorrectAnswer(
        started,
        describerUid: describerUid,
        guesserUid: guesser.uid,
      );
      expect(
        correct.players.firstWhere((p) => p.uid == describerUid).personalScore,
        2,
      );
      expect(
        correct.players.firstWhere((p) => p.uid == guesser.uid).personalScore,
        3,
      );
      expect(correct.teams.firstWhere((t) => t.id == guesser.teamId).score, 5);
      expect(
        correct.teams.firstWhere((t) => t.id == guesser.teamId).roundScores,
        [5],
      );

      final skipped = service.applySkip(correct, describerUid: describerUid);
      expect(
        skipped.players.firstWhere((p) => p.uid == describerUid).personalScore,
        1,
      );
      expect(skipped.teams.firstWhere((t) => t.id == guesser.teamId).score, 5);
    });
  });
}
