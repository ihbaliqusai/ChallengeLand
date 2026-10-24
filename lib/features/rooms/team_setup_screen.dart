import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/player_card.dart';
import '../../core/widgets/team_card.dart';
import '../../models/room_player.dart';
import '../../models/team.dart';
import '../../state/auth_provider.dart';
import '../../state/room_provider.dart';

class TeamSetupScreen extends StatelessWidget {
  const TeamSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تحدي الفرق')),
        body: const EmptyState(message: 'أنشئ غرفة فرق أولًا من شاشة الأنماط.'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.pop(context),
          label: const Text('رجوع'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      );
    }

    final user = context.watch<AuthProvider>().user;
    final isHost = user?.uid == room.hostId;
    final unassigned = room.players
        .where(
          (player) =>
              player.teamId == null ||
              player.teamId!.isEmpty ||
              !room.teams.any((team) => team.id == player.teamId),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('إعداد الفرق')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: room.teams
                    .map(
                      (team) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _TeamDropZone(
                            team: team,
                            players: room.players
                                .where((player) => player.teamId == team.id)
                                .toList(growable: false),
                            enabled: isHost,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              if (unassigned.isNotEmpty) ...[
                const Text(
                  'لاعبون بدون فريق',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...unassigned.map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DraggablePlayer(player: player, enabled: isHost),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AppButton(
                label: 'توزيع تلقائي',
                icon: Icons.auto_awesome_rounded,
                onPressed: isHost
                    ? () => context.read<RoomProvider>().autoAssignTeams()
                    : null,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'إعادة تعيين الفرق',
                icon: Icons.restart_alt_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: isHost
                    ? () => context.read<RoomProvider>().resetTeams()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamDropZone extends StatelessWidget {
  const _TeamDropZone({
    required this.team,
    required this.players,
    required this.enabled,
  });

  final Team team;
  final List<RoomPlayer> players;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => enabled,
      onAcceptWithDetails: (details) {
        context.read<RoomProvider>().movePlayerToTeam(details.data, team.id);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? team.color : team.color.withValues(alpha: 0.28),
              width: active ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TeamCard(team: team),
                const SizedBox(height: 8),
                if (players.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      enabled ? 'اسحب لاعبًا هنا' : 'بانتظار الهوست',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: team.color.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...players.map(
                    (player) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DraggablePlayer(player: player, enabled: enabled),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DraggablePlayer extends StatelessWidget {
  const _DraggablePlayer({required this.player, required this.enabled});

  final RoomPlayer player;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final card = PlayerCard(player: player);
    if (!enabled) return card;

    return LongPressDraggable<String>(
      data: player.uid,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 260, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
