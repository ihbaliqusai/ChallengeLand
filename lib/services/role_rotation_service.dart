import '../models/player_role.dart';
import '../models/room.dart';
import '../models/room_player.dart';
import '../models/team.dart';
import 'team_service.dart';

/// يتحكم في تدوير أدوار اللاعبين والنقاط عبر جولات اللعبة.
///
/// القواعد:
///   وصف صحيح  → المُوصِف +2 | المُخمِّن +3 | الفريق +5
///   تخطي       → المُوصِف -1  | لا شيء للمُخمِّن | الفريق -1
///
/// تدوير round-robin:
///   - 1v1  : اللاعبان يتبادلان الدور كل جولة
///   - فرق  : الفريقان يتبادلان الوصف كل جولة،
///             وداخل كل فريق يتناوب اللاعبون كل مرة يصف فيها الفريق
///   - حفلة : اللاعبون يتناوبون بالترتيب، الجميع يخمّن
class RoleRotationService {
  const RoleRotationService({TeamService teamService = const TeamService()})
    : _teamService = teamService;

  final TeamService _teamService;

  // =========================================================
  // 1. بدء اللعبة
  // =========================================================

  /// يحوّل الغرفة من مرحلة الانتظار إلى الجولة الأولى.
  Room startGame(Room room) {
    final prepared = room.gameType.isTeamMode
        ? _teamService.ensureDefaultTeams(room)
        : room;
    final started = prepared.copyWith(
      currentRound: 1,
      status: 'active',
      phase: GamePhase.describing,
      updatedAt: DateTime.now(),
    );
    return _applyRolesAndDescriber(started);
  }

  // =========================================================
  // 2. تقدم الجولة
  // =========================================================

  /// ينتقل إلى مرحلة "نتيجة الجولة" ويُسجّل نقاط الجولة في الفرق.
  Room endDescribingPhase(Room room) {
    return room.copyWith(
      phase: GamePhase.roundResult,
      updatedAt: DateTime.now(),
    );
  }

  /// ينتقل إلى الجولة التالية أو يُعلن نهاية اللعبة.
  Room advanceToNextRound(Room room) {
    final nextRound = room.currentRound + 1;

    if (nextRound > room.totalRounds) {
      // انتهت جميع الجولات
      return room.copyWith(
        phase: GamePhase.gameOver,
        status: 'finished',
        updatedAt: DateTime.now(),
      );
    }

    // أُقدِّم describerIndex للفريق الذي وصف في هذه الجولة
    final teamsAdvanced = _advanceTeamDescriber(room);

    final advanced = room.copyWith(
      currentRound: nextRound,
      phase: GamePhase.describing,
      teams: teamsAdvanced,
      updatedAt: DateTime.now(),
    );

    return _applyRolesAndDescriber(advanced);
  }

  // =========================================================
  // 3. تطبيق النقاط
  // =========================================================

  /// يُطبَّق عندما يخمّن الفريق الإجابة الصحيحة.
  ///
  /// [describerUid] - uid اللاعب الذي كان يصف
  /// [guesserUid]   - uid أول لاعب أجاب صحيحاً
  Room applyCorrectAnswer(Room room, String describerUid, String guesserUid) {
    if (room.gameType.isTeamMode) {
      return _teamService.applyCorrectAnswer(
        room,
        describerUid: describerUid,
        guesserUid: guesserUid,
      );
    }

    final update = ScoreUpdate.correct(
      describerUid: describerUid,
      guesserUid: guesserUid,
      describingTeamId: room.currentTeamDescribingId,
    );
    return _applyScoreUpdate(room, update);
  }

  /// يُطبَّق عندما يتخطى المُوصِف البطاقة.
  Room applySkip(Room room, String describerUid) {
    if (room.gameType.isTeamMode) {
      return _teamService.applySkip(room, describerUid: describerUid);
    }

    final update = ScoreUpdate.skip(
      describerUid: describerUid,
      describingTeamId: room.currentTeamDescribingId,
    );
    return _applyScoreUpdate(room, update);
  }

  // =========================================================
  // 4. استعلامات الحالة
  // =========================================================

  /// يحسب uid المُوصِف للجولة الحالية بناءً على نوع اللعبة.
  String? computeDescriberUid(Room room) {
    if (room.currentRound == 0 || room.players.isEmpty) return null;

    switch (room.gameType) {
      case GameType.quick1v1:
      case GameType.party:
        return _roundRobinDescriber(room.players, room.currentRound);

      case GameType.teams2v2:
      case GameType.teams3v3:
        return _teamDescriber(room);
    }
  }

  /// يعيد الفريق الذي يصف في الجولة الحالية.
  Team? computeDescribingTeam(Room room) {
    if (!room.gameType.isTeamMode || room.teams.isEmpty) return null;
    return _teamService.describingTeamForRound(room);
  }

  /// يعيد كل لاعب مع دوره المحدَّث للجولة الحالية.
  List<RoomPlayer> computeRolesForRound(Room room) {
    final describerUid = computeDescriberUid(room);
    final describingTeam = computeDescribingTeam(room);

    return room.players
        .map((player) {
          final role = _roleForPlayer(
            player: player,
            describerUid: describerUid,
            describingTeamId: describingTeam?.id,
          );
          return player.copyWith(role: role);
        })
        .toList(growable: false);
  }

  /// يعيد اللاعب الفائز (أعلى نقاط) في لعبة 1v1 أو حفلة.
  RoomPlayer? winner(Room room) {
    if (room.players.isEmpty) return null;
    return room.players.reduce(
      (a, b) => a.personalScore >= b.personalScore ? a : b,
    );
  }

  /// يعيد الفريق الفائز (أعلى نقاط) في لعبة الفرق.
  Team? winningTeam(Room room) {
    if (room.teams.isEmpty) return null;
    return room.teams.reduce((a, b) => a.score >= b.score ? a : b);
  }

  // =========================================================
  // Private helpers
  // =========================================================

  /// يضبط currentDescriber و currentTeamDescribingId و أدوار اللاعبين.
  Room _applyRolesAndDescriber(Room room) {
    final describerUid = computeDescriberUid(room);
    final describingTeam = computeDescribingTeam(room);
    final updatedPlayers = computeRolesForRound(
      room.copyWith(
        currentDescriber: describerUid,
        currentTeamDescribingId: describingTeam?.id,
      ),
    );
    final updatedRoom = room.copyWith(
      currentDescriber: describerUid,
      currentTeamDescribingId: describingTeam?.id,
      players: updatedPlayers,
    );

    return room.gameType.isTeamMode
        ? _teamService.syncTeamsFromPlayers(updatedRoom)
        : updatedRoom;
  }

  /// يُقدِّم describerIndex للفريق الذي وصف في الجولة المنتهية.
  List<Team> _advanceTeamDescriber(Room room) {
    if (room.teams.isEmpty || room.currentRound == 0) return room.teams;

    return _teamService.advanceDescriberForFinishedRound(room).teams;
  }

  // ─── تحديد المُوصِف ───

  /// Round-robin بسيط على قائمة اللاعبين (1v1 وحفلة).
  String? _roundRobinDescriber(List<RoomPlayer> players, int round) {
    if (players.isEmpty) return null;
    final idx = (round - 1) % players.length;
    return players[idx].uid;
  }

  /// يحدد المُوصِف في نظام الفرق:
  ///   الفريق المصف = (round-1) % عدد الفرق
  ///   المُوصِف داخل الفريق = team.currentDescriberUid
  String? _teamDescriber(Room room) {
    if (room.teams.isEmpty) return null;
    final teamIdx = (room.currentRound - 1) % room.teams.length;
    return room.teams[teamIdx].currentDescriberUid;
  }

  // ─── تحديد الدور ───

  PlayerRole _roleForPlayer({
    required RoomPlayer player,
    required String? describerUid,
    required String? describingTeamId,
  }) {
    // المُوصِف
    if (player.uid == describerUid) return PlayerRole.describer;

    // في نظام الفرق: زملاء المُوصِف = متفرجون، الخصوم = مُخمِّنون
    if (describingTeamId != null) {
      final isSameTeam = player.teamId == describingTeamId;
      return isSameTeam ? PlayerRole.spectator : PlayerRole.guesser;
    }

    // في 1v1 والحفلة: الجميع مُخمِّنون ما عدا المُوصِف
    return PlayerRole.guesser;
  }

  // ─── تطبيق النقاط ───

  Room _applyScoreUpdate(Room room, ScoreUpdate update) {
    // تحديث اللاعبين
    final updatedPlayers = room.players
        .map((player) {
          if (player.uid == update.describerUid) {
            return player.copyWith(
              personalScore: player.personalScore + update.describerDelta,
              score: player.score + update.describerDelta,
              skipsUsed: update.isSkip
                  ? player.skipsUsed + 1
                  : player.skipsUsed,
            );
          }
          if (update.isCorrect && player.uid == update.guesserUid) {
            return player.copyWith(
              personalScore: player.personalScore + update.guesserDelta,
              score: player.score + update.guesserDelta,
              correctGuesses: player.correctGuesses + 1,
            );
          }
          return player;
        })
        .toList(growable: false);

    // تحديث نقاط الفرق
    final updatedTeams = room.teams
        .map((team) {
          final delta = update.teamDeltas[team.id];
          if (delta == null || delta == 0) return team;
          return team.addPoints(delta, round: room.currentRound);
        })
        .toList(growable: false);

    return room.copyWith(
      players: updatedPlayers,
      teams: updatedTeams,
      updatedAt: DateTime.now(),
    );
  }
}
