import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../models/player_role.dart';
import '../../models/room.dart';
import '../../models/room_player.dart';
import '../../models/team.dart';
import '../../state/auth_provider.dart';
import '../../state/room_provider.dart';

class RoomLobbyScreen extends StatefulWidget {
  const RoomLobbyScreen({super.key});

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _countdownCtrl;

  int _tick = 3;
  bool _showCountdown = false;
  bool _countdownTriggered = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final room = context.read<RoomProvider>().room;
      if (room != null) context.read<RoomProvider>().listenToRoom(room.id);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countdownCtrl.dispose();
    super.dispose();
  }

  Future<void> _runCountdown() async {
    if (!mounted || _countdownTriggered) return;
    _countdownTriggered = true;
    setState(() => _showCountdown = true);

    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _tick = i);
      _countdownCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 950));
    }

    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.gameBoard);
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.watch<RoomProvider>();
    final user = context.watch<AuthProvider>().user;
    final room = roomProv.room;

    if (room == null) {
      return const Scaffold(
        backgroundColor: AppColors.challengeDark,
        body: Center(
          child: Text(
            'لا توجد غرفة نشطة',
            style: TextStyle(color: AppColors.challengeGray),
          ),
        ),
      );
    }

    if (roomProv.gameStarting && !_countdownTriggered) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runCountdown());
    }

    final myUid = user?.uid ?? '';
    final isHost = myUid == room.hostId;
    final myPlayer = room.players.cast<RoomPlayer?>().firstWhere(
      (p) => p?.uid == myUid,
      orElse: () => null,
    );
    final isReady = myPlayer?.isReady ?? false;
    final readyCount = room.players.where((p) => p.isReady).length;
    final allReady =
        room.players.length > 1 && readyCount == room.players.length;

    return Scaffold(
      backgroundColor: AppColors.challengeDark,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _Header(room: room),
                _ReadyBar(
                  readyCount: readyCount,
                  total: room.players.length,
                  allReady: allReady,
                  pulseCtrl: _pulseCtrl,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        room.gameType.isTeamMode
                            ? _TeamSection(room: room, myUid: myUid)
                            : _PlayerList(room: room, myUid: myUid),
                        const SizedBox(height: 16),
                        _SettingsCard(room: room, isHost: isHost),
                        const SizedBox(height: 20),
                        _BottomActions(
                          room: room,
                          isHost: isHost,
                          isReady: isReady,
                          allReady: allReady,
                          isLoading: roomProv.isLoading,
                          myUid: myUid,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCountdown)
            _CountdownOverlay(tick: _tick, controller: _countdownCtrl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.challengeGray,
            ),
            onPressed: () async {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                await context.read<RoomProvider>().leaveRoom(user);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              room.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.challengeLight,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _CodeBadge(code: room.code),
        ],
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ الكود ✅'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.challengeBlue.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.challengeBlue.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tag_rounded,
              size: 13,
              color: AppColors.challengeCyan,
            ),
            const SizedBox(width: 4),
            Text(
              code,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.challengeCyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.copy_rounded,
              size: 12,
              color: AppColors.challengeGray,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Ready Progress Bar
// ═══════════════════════════════════════════════

class _ReadyBar extends StatelessWidget {
  const _ReadyBar({
    required this.readyCount,
    required this.total,
    required this.allReady,
    required this.pulseCtrl,
  });

  final int readyCount;
  final int total;
  final bool allReady;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : readyCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) => Text(
                  allReady ? '✅ الجميع جاهز!' : '$readyCount / $total جاهزون',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: allReady
                        ? Color.lerp(
                            AppColors.challengeGreen,
                            Colors.white,
                            pulseCtrl.value * 0.45,
                          )
                        : AppColors.challengeGray,
                  ),
                ),
              ),
              if (!allReady && total > 0)
                Text(
                  '${total - readyCount} ينتظرون',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.challengeGray,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: AppColors.challengeCard,
                valueColor: AlwaysStoppedAnimation(
                  allReady ? AppColors.challengeGreen : AppColors.challengeCyan,
                ),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Player List  (non-team mode)
// ═══════════════════════════════════════════════

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.room, required this.myUid});
  final Room room;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isHost = myUid == room.hostId;
    return Column(
      children: [
        ...room.players.asMap().entries.map((e) {
          final player = e.value;
          return _PlayerTile(
            key: ValueKey(player.uid),
            player: player,
            slideDelay: e.key * 70,
            isMe: player.uid == myUid,
            canRemove: isHost && !player.isHost,
          );
        }),
        // Empty slots
        ...List.generate(
          (room.maxPlayers - room.players.length).clamp(0, 6),
          (_) => _EmptyPlayerSlot(),
        ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    super.key,
    required this.player,
    required this.slideDelay,
    required this.isMe,
    required this.canRemove,
  });

  final RoomPlayer player;
  final int slideDelay;
  final bool isMe;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + slideDelay),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset((1 - v) * 48, 0),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.challengeBlue.withValues(alpha: 0.14)
              : AppColors.challengeCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? AppColors.challengeBlue.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            _Avatar(username: player.username, photoUrl: player.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    player.username,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isMe
                          ? AppColors.challengeCyan
                          : AppColors.challengeLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (player.isHost) ...[
                    const SizedBox(width: 6),
                    const Text('👑', style: TextStyle(fontSize: 13)),
                  ],
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Text(
                      'أنت',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.challengeGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ReadyBadge(isReady: player.isReady),
            if (canRemove) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    context.read<RoomProvider>().removePlayer(player.uid),
                child: const Icon(
                  Icons.remove_circle_rounded,
                  color: AppColors.challengeRed,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlayerSlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.challengeGray.withValues(alpha: 0.15),
        ),
      ),
      child: const Center(
        child: Text(
          '+ مقعد فارغ',
          style: TextStyle(fontSize: 13, color: AppColors.challengeGray),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Team Section
// ═══════════════════════════════════════════════

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.room, required this.myUid});
  final Room room;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isHost = myUid == room.hostId;
    final slotsPerTeam = room.maxPlayers ~/ room.teams.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: room.teams.map((team) {
        final members = room.players
            .where((p) => team.playerIds.contains(p.uid))
            .toList();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _TeamCol(
              team: team,
              members: members,
              totalSlots: slotsPerTeam,
              myUid: myUid,
              isHost: isHost,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TeamCol extends StatelessWidget {
  const _TeamCol({
    required this.team,
    required this.members,
    required this.totalSlots,
    required this.myUid,
    required this.isHost,
  });

  final Team team;
  final List<RoomPlayer> members;
  final int totalSlots;
  final String myUid;
  final bool isHost;

  Color get _color {
    return team.color;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final emptySlots = (totalSlots - members.length).clamp(0, 8);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Team header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(team.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  team.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Members
          ...members.asMap().entries.map(
            (e) => _TeamChip(
              key: ValueKey(e.value.uid),
              player: e.value,
              color: color,
              isMe: e.value.uid == myUid,
              canRemove: isHost && !e.value.isHost,
              delay: e.key * 80,
            ),
          ),
          // Empty slots
          ...List.generate(
            emptySlots,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: const Center(
                child: Text(
                  '+ مقعد فارغ',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.challengeGray,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    super.key,
    required this.player,
    required this.color,
    required this.isMe,
    required this.canRemove,
    required this.delay,
  });

  final RoomPlayer player;
  final Color color;
  final bool isMe;
  final bool canRemove;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? color.withValues(alpha: 0.22) : AppColors.challengeCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _Avatar(
              username: player.username,
              photoUrl: player.photoUrl,
              radius: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                player.username,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isMe ? Colors.white : AppColors.challengeLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ReadyBadge(isReady: player.isReady, compact: true),
            if (canRemove) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () =>
                    context.read<RoomProvider>().removePlayer(player.uid),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.challengeRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Shared small widgets
// ═══════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.username,
    required this.photoUrl,
    this.radius = 20,
  });

  final String username;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.challengeBlue.withValues(alpha: 0.3),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? Text(
              username.isNotEmpty ? username.substring(0, 1) : '؟',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.8,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class _ReadyBadge extends StatelessWidget {
  const _ReadyBadge({required this.isReady, this.compact = false});
  final bool isReady;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Container(
        key: ValueKey(isReady),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isReady
              ? AppColors.challengeGreen.withValues(alpha: 0.18)
              : AppColors.challengeGray.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          isReady ? '✅' : '⏳',
          style: TextStyle(fontSize: compact ? 11 : 12),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Settings Card
// ═══════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.room, required this.isHost});
  final Room room;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.challengeCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 15,
                color: AppColors.challengeGold,
              ),
              const SizedBox(width: 7),
              const Text(
                'إعدادات اللعبة',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.challengeGold,
                ),
              ),
              if (!isHost) ...[
                const Spacer(),
                const Text(
                  'للهوست فقط',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.challengeGray,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _SettingRow(
            label: 'الجولات',
            options: const {3: '3', 5: '5', 7: '7', 10: '10'},
            selected: room.totalRounds,
            enabled: isHost,
            onSelected: (v) =>
                context.read<RoomProvider>().updateSettings(totalRounds: v),
          ),
          const SizedBox(height: 10),
          _SettingRow(
            label: 'المدة',
            options: const {30: '30ث', 60: '60ث', 90: '90ث', 120: '2د'},
            selected: room.roundDuration,
            enabled: isHost,
            onSelected: (v) =>
                context.read<RoomProvider>().updateSettings(roundDuration: v),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final Map<int, String> options;
  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.challengeGray,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: options.entries.map((e) {
            final picked = e.key == selected;
            return GestureDetector(
              onTap: enabled ? () => onSelected(e.key) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: picked
                      ? AppColors.challengeCyan.withValues(alpha: 0.2)
                      : AppColors.challengeDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: picked
                        ? AppColors.challengeCyan
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: picked
                        ? AppColors.challengeCyan
                        : enabled
                        ? AppColors.challengeGray
                        : AppColors.challengeGray.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Bottom Actions
// ═══════════════════════════════════════════════

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.room,
    required this.isHost,
    required this.isReady,
    required this.allReady,
    required this.isLoading,
    required this.myUid,
  });

  final Room room;
  final bool isHost;
  final bool isReady;
  final bool allReady;
  final bool isLoading;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Copy + Share row
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'نسخ الكود',
                icon: Icons.copy_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: room.code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الكود ✅'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'مشاركة',
                icon: Icons.share_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: 'العب معي في أرض التحدي! الكود: ${room.code}',
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ رسالة المشاركة ✅'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Ready toggle for non-host
        if (!isHost)
          AppButton(
            label: isReady ? 'إلغاء الجاهزية' : '✊ جاهز للعب!',
            variant: isReady
                ? AppButtonVariant.ghost
                : AppButtonVariant.primary,
            onPressed: () =>
                context.read<RoomProvider>().setReady(myUid, !isReady),
          ),
        // Start game for host
        if (isHost) ...[
          AppButton(
            label: allReady ? '🚀 ابدأ اللعبة!' : '⏳ انتظار الجميع...',
            variant: AppButtonVariant.gold,
            isLoading: isLoading,
            onPressed: allReady
                ? () => context.read<RoomProvider>().startGame()
                : null,
          ),
        ],
        const SizedBox(height: 10),
        AppButton(
          label: 'مغادرة الغرفة',
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.danger,
          onPressed: () async {
            final user = context.read<AuthProvider>().user;
            if (user != null) {
              await context.read<RoomProvider>().leaveRoom(user);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Countdown Overlay  3 → 2 → 1
// ═══════════════════════════════════════════════

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.tick, required this.controller});

  final int tick;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final scale = Tween<double>(begin: 2.0, end: 1.0)
            .animate(
              CurvedAnimation(parent: controller, curve: Curves.elasticOut),
            )
            .value;
        final opacity = (controller.value * 2.5).clamp(0.0, 1.0);

        return Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اللعبة تبدأ الآن!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.challengeGold,
                  ),
                ),
                const SizedBox(height: 32),
                Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.challengeBlue.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppColors.challengeCyan,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.challengeCyan.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$tick',
                          style: const TextStyle(
                            fontSize: 70,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'استعد...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.challengeGray,
                    letterSpacing: 1,
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
