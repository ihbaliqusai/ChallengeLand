import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room.dart';
import '../screens/online/room_lobby_screen.dart';
import '../services/native_bridge_service.dart';
import '../services/room_service.dart';

class OnlineMatchRecoveryCard extends StatefulWidget {
  const OnlineMatchRecoveryCard({super.key, required this.userId});

  final String userId;

  @override
  State<OnlineMatchRecoveryCard> createState() =>
      _OnlineMatchRecoveryCardState();
}

class _OnlineMatchRecoveryCardState extends State<OnlineMatchRecoveryCard>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _matches = const [];
  bool _busy = false;
  int _refreshId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(OnlineMatchRecoveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _matches = const [];
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final refreshId = ++_refreshId;
    if (widget.userId.isEmpty) return;
    try {
      final matches = await context
          .read<NativeBridgeService>()
          .getRecoverableOnlineMatches();
      if (mounted && refreshId == _refreshId) {
        setState(() => _matches = matches
            .where((match) => match['uid'] == widget.userId)
            .toList(growable: false));
      }
    } catch (_) {
      // A failed refresh keeps the saved return button available for another try.
    }
  }

  Future<void> _showResult(String id, String message) async {
    final uid = widget.userId;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('انتهت المباراة'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'))
        ],
      ),
    );
    if (!mounted || widget.userId != uid) return;
    await context.read<NativeBridgeService>().dismissOnlineMatchRecovery(id);
  }

  Future<void> _resume(Map<String, dynamic> match) async {
    if (_busy) return;
    final uid = widget.userId;
    final id = match['id'] as String;
    setState(() => _busy = true);
    try {
      if (match['finished'] == true) {
        await _showResult(
            id, match['message'] as String? ?? 'انتهت المباراة أثناء غيابك.');
      } else if ((match['roomId'] as String? ?? '').isNotEmpty) {
        final roomId = match['roomId'] as String;
        final service = context.read<RoomService>();
        final room = await service.getRoomForRecovery(roomId);
        if (!mounted || widget.userId != uid) return;
        if (room == null || !room.containsPlayer(uid)) {
          await _showResult(id, 'لم تعد هذه المباراة متاحة للعودة إليها.');
        } else if (room.phase == Room.phaseFinished) {
          final winner = room.winnerId ?? '';
          final winnerTeam = room.winnerTeamId ?? '';
          final won = winner == uid ||
              (winnerTeam.isNotEmpty &&
                  winnerTeam == room.players[uid]?.teamId);
          await _showResult(
              id,
              won
                  ? 'فزت بالمباراة.'
                  : winner.isNotEmpty || winnerTeam.isNotEmpty
                      ? 'خسرت المباراة التي انتهت أثناء غيابك.'
                      : 'انتهت المباراة بالتعادل.');
        } else {
          await service.joinRoom(roomId: roomId, userId: uid);
          if (!mounted || widget.userId != uid) return;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                RoomLobbyScreen(roomId: roomId, isJoiningMidGame: true),
          ));
        }
      } else {
        await context.read<NativeBridgeService>().resumeOnlineMatch(id);
      }
      if (mounted && widget.userId == uid) await _refresh();
    } catch (_) {
      if (mounted && widget.userId == uid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('تعذر استعادة المباراة. تحقق من الاتصال ثم حاول مجددًا.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseMatch() async {
    if (_matches.length == 1) return _resume(_matches.first);
    final uid = widget.userId;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('مبارياتك السابقة'),
        children: [
          for (final match in _matches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, match),
              child: Text(match['finished'] == true
                  ? 'عرض نتيجة المباراة'
                  : (match['roomId'] as String? ?? '').isNotEmpty
                      ? 'العودة إلى غرفة اللعب'
                      : 'العودة إلى المباراة'),
            ),
        ],
      ),
    );
    if (mounted && selected != null && widget.userId == uid) {
      await _resume(selected);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) return const SizedBox.shrink();
    final finished = _matches.every((match) => match['finished'] == true);
    return Material(
      color: const Color(0xF2113440),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('resume-online-match'),
        onTap: _busy ? null : _chooseMatch,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(textDirection: TextDirection.rtl, children: [
            if (_busy)
              const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(finished ? Icons.info_outline : Icons.play_circle_fill,
                  color: const Color(0xFF6EE7B7)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text(
                      finished
                          ? 'نتيجة مباراتك السابقة'
                          : 'العودة إلى المباراة',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  Text(
                      _matches.length > 1
                          ? 'لديك ${_matches.length} مباريات محفوظة'
                          : finished
                              ? 'اضغط لعرض النتيجة'
                              : 'تابع المباراة أو اعرض نتيجتها إذا انتهت',
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFB9D8DE), fontSize: 10)),
                ])),
          ]),
        ),
      ),
    );
  }
}
