import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/legacy_room.dart';
import '../screens/online/room_lobby_screen.dart';
import '../widgets/game_notice.dart';
import 'native_bridge_service.dart';
import 'legacy_room_service.dart';

/// Shared rules for starting and returning to an account's online match.
class OnlineMatchFlow {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool _preparing = false;

  static Future<Map<String, dynamic>> inspect(
      BuildContext context, String uid, Map<String, dynamic> match) async {
    if (match['finished'] == true) return match;
    final roomId = match['roomId'] as String? ?? '';
    if (roomId.isEmpty) {
      return context
          .read<NativeBridgeService>()
          .inspectOnlineMatch(match['id'] as String, uid: uid);
    }
    final room = await context.read<RoomService>().getRoomForRecovery(roomId);
    if (!context.mounted) return match;
    if (room == null || !room.containsPlayer(uid)) {
      const message = 'لم تعد هذه المباراة متاحة للعودة إليها.';
      await context
          .read<NativeBridgeService>()
          .completeOnlineRoomRecovery(match['id'] as String, message, uid: uid);
      return {...match, 'finished': true, 'message': message};
    }
    if (room.players[uid]?.forfeited == true) {
      return context
          .read<NativeBridgeService>()
          .inspectOnlineMatch(match['id'] as String, forfeit: true, uid: uid);
    }
    if (room.phase != Room.phaseFinished) return match;
    final winner = room.winnerId ?? '';
    final winnerTeam = room.winnerTeamId ?? '';
    final won = winner == uid ||
        (winnerTeam.isNotEmpty && winnerTeam == room.players[uid]?.teamId);
    final message = won
        ? 'فزت بالمباراة.'
        : winner.isNotEmpty || winnerTeam.isNotEmpty
            ? 'خسرت المباراة التي انتهت أثناء غيابك.'
            : 'انتهت المباراة بالتعادل.';
    await context
        .read<NativeBridgeService>()
        .completeOnlineRoomRecovery(match['id'] as String, message, uid: uid);
    return {...match, 'finished': true, 'message': message};
  }

  static Future<void> resume(
      BuildContext context, String uid, Map<String, dynamic> match) async {
    final native = context.read<NativeBridgeService>();
    final resolved = await inspect(context, uid, match);
    if (!context.mounted || !await native.isOnlineMatchAccount(uid)) return;
    if (!context.mounted) return;
    if (resolved['finished'] == true) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GameAlertDialog(
          title: const Text('انتهت المباراة'),
          content: Text(
              resolved['message'] as String? ?? 'انتهت المباراة أثناء غيابك.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'))
          ],
        ),
      );
      if (await native.isOnlineMatchAccount(uid)) {
        await native.dismissOnlineMatchRecovery(match['id'] as String);
      }
      return;
    }
    final roomId = match['roomId'] as String? ?? '';
    if (roomId.isEmpty) {
      await native.resumeOnlineMatch(match['id'] as String);
    } else {
      await context.read<RoomService>().joinRoom(roomId: roomId, userId: uid);
      if (!context.mounted || !await native.isOnlineMatchAccount(uid)) return;
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RoomLobbyScreen(roomId: roomId, isJoiningMidGame: true),
      ));
    }
  }

  /// A failed lookup never counts as consent to discard the previous match.
  static Future<bool> prepare(BuildContext context, String uid,
      {String? roomId, String? matchId}) async {
    if (_preparing || uid.isEmpty) return false;
    // SocialShell lives above the app Navigator in MaterialApp.builder.
    if (Navigator.maybeOf(context) == null) {
      final overlayContext = navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null) return false;
      context = overlayContext;
    }
    _preparing = true;
    try {
      final native = context.read<NativeBridgeService>();
      final saved = await native.getRecoverableOnlineMatches();
      if (!context.mounted) return false;
      final active = <Map<String, dynamic>>[];
      for (final match in saved) {
        if (match['uid'] != uid ||
            match['finished'] == true ||
            (roomId != null && roomId == match['roomId']) ||
            (matchId != null && 'paid:$matchId' == match['id'])) {
          continue;
        }
        final resolved = await inspect(context, uid, match);
        if (!context.mounted) return false;
        if (resolved['finished'] != true) active.add(resolved);
      }
      if (active.isEmpty) return native.isOnlineMatchAccount(uid);
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => GameAlertDialog(
          title: const Text('لديك مباراة لم تنتهِ'),
          content: Text(active.length == 1
              ? 'يمكنك إكمال مباراتك السابقة، أو الانسحاب منها وبدء مباراة جديدة. يُحسب الانسحاب خسارة وتُفقد قطع المباراة المحجوزة إن وجدت.'
              : 'لديك ${active.length} مباريات سابقة. يمكنك العودة لإكمالها، أو الانسحاب منها جميعًا وبدء مباراة جديدة. يُحسب الانسحاب خسارة وتُفقد قطع المباريات المحجوزة إن وجدت.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'resume'),
                child: const Text('إكمال السابقة')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'forfeit'),
                child: const Text('انسحاب وبدء جديدة')),
          ],
        ),
      );
      if (!context.mounted || !await native.isOnlineMatchAccount(uid)) {
        return false;
      }
      if (!context.mounted) return false;
      if (choice == 'resume') {
        await resume(context, uid, active.first);
        return false;
      }
      if (choice != 'forfeit') return false;
      final leftRooms = <String, Room?>{};
      for (final match in active) {
        final previousRoom = match['roomId'] as String? ?? '';
        if (previousRoom.isNotEmpty) {
          if (!leftRooms.containsKey(previousRoom)) {
            leftRooms[previousRoom] = await context
                .read<RoomService>()
                .forfeitRoom(roomId: previousRoom, userId: uid);
          }
          if (!context.mounted) return false;
          final room = leftRooms[previousRoom];
          if (room != null && room.phase == Room.phaseFinished) {
            // Read the immutable result; do not turn a completed win into a loss.
            await inspect(context, uid, match);
            continue;
          }
        }
        final result = await native.inspectOnlineMatch(match['id'] as String,
            forfeit: true, uid: uid);
        if (result['finished'] != true) {
          throw StateError('لم تنتهِ المباراة السابقة. حاول مجددًا.');
        }
        if (!context.mounted) return false;
      }
      return native.isOnlineMatchAccount(uid);
    } finally {
      _preparing = false;
    }
  }
}
