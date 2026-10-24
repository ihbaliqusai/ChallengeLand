import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/player_role.dart';
import '../../models/room.dart';
import '../../models/room_player.dart';
import '../../models/team.dart';
import '../../services/game_end_service.dart';
import '../../state/auth_provider.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  Room? _room;
  String _currentUid = '';
  bool _initialized = false;

  bool _saving = false;
  bool _saved = false;
  String? _saveError;

  // خزّن التقييم القديم قبل التحديث
  int _oldRating = 1000;

  late final AnimationController _trophyCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _confettiCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final Animation<double> _trophyScale = CurvedAnimation(
    parent: _trophyCtrl,
    curve: Curves.elasticOut,
  );

  final _rng = math.Random(99);
  late final List<_Particle> _particles = List.generate(
    28,
    (i) => _Particle(
      leftFraction: _rng.nextDouble(),
      delay: _rng.nextDouble() * 0.6,
      speed: 0.45 + _rng.nextDouble() * 0.55,
      rotationBase: _rng.nextDouble() * math.pi * 2,
      rotationSpeed: (_rng.nextBool() ? 1 : -1) * (1.5 + _rng.nextDouble() * 3),
      w: 6.0 + _rng.nextDouble() * 8,
      h: 10.0 + _rng.nextDouble() * 14,
      color: [
        AppColors.challengeGold,
        AppColors.challengeCyan,
        AppColors.challengePink,
        AppColors.challengeGreen,
        AppColors.challengeOrange,
        AppColors.challengeYellow,
      ][i % 6],
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _room = args?['room'] as Room?;
      _currentUid = args?['currentUid'] as String? ?? '';
      _oldRating = context.read<AuthProvider>().user?.rating ?? 1000;
      _trophyCtrl.forward();
      if (_isCurrentPlayerWinner) _confettiCtrl.repeat();
      _saveResults();
    }
  }

  @override
  void dispose() {
    _trophyCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ── حساب الفائز ──────────────────────────────────────────────────────────

  bool get _isTeamMode => _room?.gameType.isTeamMode ?? false;

  String? get _winnerTeamId {
    final teams = _room?.teams ?? [];
    if (teams.isEmpty) return null;
    final s = [...teams]..sort((a, b) => b.score.compareTo(a.score));
    if (s.length > 1 && s[0].score == s[1].score) return null;
    return s.first.id;
  }

  String? get _winnerUid {
    final players = _room?.players ?? [];
    if (players.isEmpty) return null;
    final s = [...players]..sort((a, b) => b.score.compareTo(a.score));
    if (s.length > 1 && s[0].score == s[1].score) return null;
    return s.first.uid;
  }

  bool get _isCurrentPlayerWinner {
    if (_isTeamMode) {
      final wt = _winnerTeamId;
      if (wt == null) return false;
      final p = _room?.players.cast<RoomPlayer?>().firstWhere(
        (p) => p?.uid == _currentUid,
        orElse: () => null,
      );
      return p?.teamId == wt;
    }
    return _winnerUid == _currentUid;
  }

  // ── حفظ النتائج ──────────────────────────────────────────────────────────

  Future<void> _saveResults() async {
    final room = _room;
    if (room == null || _saving || _saved) return;

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user == null) return;

      final roomPlayer = room.players.cast<RoomPlayer?>().firstWhere(
        (p) => p?.uid == _currentUid,
        orElse: () => null,
      );
      if (roomPlayer == null) return;

      final won = _isCurrentPlayerWinner;

      // اسم المنافس
      String opponentName = 'منافس';
      if (_isTeamMode) {
        final loser = room.teams.cast<Team?>().firstWhere(
          (t) => t?.id != _winnerTeamId,
          orElse: () => null,
        );
        opponentName = loser?.name ?? 'الفريق الآخر';
      } else if (room.players.length > 1) {
        final opp = room.players.cast<RoomPlayer?>().firstWhere(
          (p) => p?.uid != _currentUid,
          orElse: () => null,
        );
        opponentName = opp?.username ?? 'منافس';
      }

      // حفظ النتائج في Firestore + تحديث الإحصائيات
      final svc = GameEndService();
      await svc.finishGame(
        auth: auth,
        roomPlayer: roomPlayer,
        won: won,
        mode: room.gameType.name,
        opponentName: opponentName,
      );

      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return const Scaffold(
        backgroundColor: AppColors.challengeDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.challengeGold),
        ),
      );
    }

    final won = _isCurrentPlayerWinner;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: won
                  ? [AppColors.challengeDark, const Color(0xFF1A0A2E)]
                  : [AppColors.challengeDark, AppColors.challengeNavy],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                if (won)
                  _ConfettiLayer(ctrl: _confettiCtrl, particles: _particles),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWinnerHeader(room, won),
                      const SizedBox(height: 14),
                      if (_isTeamMode)
                        _buildTeamSection(room)
                      else
                        _buildSoloLeaderboard(room),
                      const SizedBox(height: 12),
                      _buildStatsCard(room),
                      const SizedBox(height: 12),
                      _buildRewardsCard(room, won),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'العب مجدداً',
                        icon: Icons.refresh_rounded,
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (_) => false,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'القائمة الرئيسية',
                        icon: Icons.home_rounded,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (_) => false,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerHeader(Room room, bool won) {
    String title;
    String subtitle;

    if (_isTeamMode) {
      final winTeam = room.teams.cast<Team?>().firstWhere(
        (t) => t?.id == _winnerTeamId,
        orElse: () => null,
      );
      if (winTeam == null) {
        title = '🤝 تعادل!';
        subtitle = 'أداء رائع من الجميع';
      } else if (won) {
        title = '🏆 الفائز!';
        subtitle = '${winTeam.emoji} ${winTeam.name}';
      } else {
        title = '${winTeam.emoji} الفائز: ${winTeam.name}';
        subtitle = 'حظاً أوفر في المرة القادمة';
      }
    } else {
      final winPlayer = room.players.cast<RoomPlayer?>().firstWhere(
        (p) => p?.uid == _winnerUid,
        orElse: () => null,
      );
      if (winPlayer == null) {
        title = '🤝 تعادل!';
        subtitle = 'مباراة متكافئة الإتقان';
      } else if (won) {
        title = '🏆 أنت الفائز!';
        subtitle = 'أحسنت يا ${winPlayer.username}';
      } else {
        title = '🏆 الفائز: ${winPlayer.username}';
        subtitle = 'حظاً أوفر في المرة القادمة';
      }
    }

    return ScaleTransition(
      scale: _trophyScale,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        gradient: LinearGradient(
          colors: won
              ? [AppColors.challengeGold, AppColors.challengeOrange]
              : [AppColors.challengePurple, AppColors.challengeBlue],
        ),
        child: Column(
          children: [
            Icon(
              won ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
              size: 72,
              color: won ? AppColors.challengeDark : AppColors.challengeGold,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: won ? AppColors.challengeDark : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (won ? AppColors.challengeDark : Colors.white)
                    .withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection(Room room) {
    final sorted = [...room.teams]..sort((a, b) => b.score.compareTo(a.score));
    final maxScore = sorted.isEmpty ? 1 : sorted.first.score.clamp(1, 9999);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نقاط الفرق',
            style: TextStyle(
              color: AppColors.challengeGray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.map((team) {
            final color = _teamColor(team);
            final isWinner = team.id == _winnerTeamId;
            final teamPlayers =
                room.players.where((p) => p.teamId == team.id).toList()
                  ..sort((a, b) => b.score.compareTo(a.score));

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${team.emoji} ${team.name}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      if (isWinner) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: AppColors.challengeGold,
                          size: 18,
                        ),
                      ],
                      const Spacer(),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: team.score),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          '$v نقطة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: maxScore == 0 ? 0 : team.score / maxScore,
                    ),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: v,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...teamPlayers.asMap().entries.map(
                    (e) => _PlayerRow(
                      player: e.value,
                      isMe: e.value.uid == _currentUid,
                      rank: e.key + 1,
                      maxScore: _maxPlayerScore(room),
                      barColor: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSoloLeaderboard(Room room) {
    final sorted = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الترتيب النهائي',
            style: TextStyle(
              color: AppColors.challengeGray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...sorted.asMap().entries.map(
            (e) => _PlayerRow(
              player: e.value,
              isMe: e.value.uid == _currentUid,
              rank: e.key + 1,
              maxScore: _maxPlayerScore(room),
              showTrophy: e.key == 0 && _winnerUid != null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Room room) {
    final byPersonal = [...room.players]
      ..sort((a, b) => b.personalScore.compareTo(a.personalScore));
    final byCorrect = [...room.players]
      ..sort((a, b) => b.correctGuesses.compareTo(a.correctGuesses));
    final bestPlayer = byPersonal.isNotEmpty ? byPersonal.first : null;
    final topGuesser = byCorrect.isNotEmpty ? byCorrect.first : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'جوائز الجولة',
            style: TextStyle(
              color: AppColors.challengeGray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (bestPlayer != null && bestPlayer.personalScore > 0)
            _StatRow(
              icon: '🌟',
              label: 'أفضل لاعب',
              value: bestPlayer.username,
              color: AppColors.challengeGold,
            ),
          if (topGuesser != null &&
              topGuesser.correctGuesses > 0 &&
              topGuesser.uid != bestPlayer?.uid)
            _StatRow(
              icon: '🎯',
              label: 'أكثر إجابة صحيحة',
              value: '${topGuesser.username} (${topGuesser.correctGuesses})',
              color: AppColors.challengeGreen,
            ),
          _StatRow(
            icon: '🎮',
            label: 'عدد الجولات',
            value: '${room.totalRounds}',
            color: AppColors.challengeCyan,
          ),
          _StatRow(
            icon: '👥',
            label: 'عدد اللاعبين',
            value: '${room.players.length}',
            color: AppColors.challengePurple,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsCard(Room room, bool won) {
    final roomPlayer = room.players.cast<RoomPlayer?>().firstWhere(
      (p) => p?.uid == _currentUid,
      orElse: () => null,
    );

    final score = roomPlayer?.score ?? 0;
    final correct = roomPlayer?.correctGuesses ?? 0;
    final xp = score * 2 + correct * 6 + (won ? 35 : 15);
    final coins = won ? 30 : 12;
    final trophies = won ? 3 : 1;
    final auth = context.watch<AuthProvider>();
    final newRating = auth.user?.rating ?? _oldRating;
    final ratingDelta = newRating - _oldRating;

    return AppCard(
      gradient: LinearGradient(
        colors: won
            ? [
                AppColors.challengeGold.withValues(alpha: 0.15),
                AppColors.challengeOrange.withValues(alpha: 0.08),
              ]
            : [AppColors.challengeCard, AppColors.challengeCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'مكافآتك',
                style: TextStyle(
                  color: AppColors.challengeGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_saving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.challengeCyan,
                  ),
                )
              else if (_saved)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.challengeGreen,
                  size: 16,
                )
              else if (_saveError != null)
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.challengeRed,
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RewardChip(
                value: '+$xp',
                label: 'XP',
                icon: '⚡',
                color: AppColors.challengeCyan,
              ),
              _RewardChip(
                value: '+$coins',
                label: 'عملة',
                icon: '🪙',
                color: AppColors.challengeGold,
              ),
              _RewardChip(
                value: '+$trophies',
                label: 'كأس',
                icon: '🏆',
                color: AppColors.challengeOrange,
              ),
              _RewardChip(
                value: ratingDelta >= 0 ? '+$ratingDelta' : '$ratingDelta',
                label: 'تقييم',
                icon: '📊',
                color: ratingDelta >= 0
                    ? AppColors.challengeGreen
                    : AppColors.challengeRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  int _maxPlayerScore(Room room) {
    if (room.players.isEmpty) return 1;
    return room.players
        .map((p) => p.score)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 9999);
  }

  Color _teamColor(Team team) {
    return team.color;
  }
}

// ─── Private widgets ─────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.isMe,
    required this.rank,
    required this.maxScore,
    this.barColor = AppColors.challengeBlue,
    this.showTrophy = false,
  });

  final RoomPlayer player;
  final bool isMe;
  final int rank;
  final int maxScore;
  final Color barColor;
  final bool showTrophy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.username,
                      style: TextStyle(
                        color: isMe ? AppColors.challengeCyan : Colors.white,
                        fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (showTrophy) ...[
                      const SizedBox(width: 4),
                      const Text('🌟', style: TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: maxScore == 0 ? 0 : player.score / maxScore,
                  ),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: v,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: player.score),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '$v',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => AppColors.challengeGold,
      2 => AppColors.challengeGray,
      3 => AppColors.challengeOrange,
      _ => AppColors.challengeCard,
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.challengeGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.challengeGray,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confetti ────────────────────────────────────────────────────────────────

class _Particle {
  const _Particle({
    required this.leftFraction,
    required this.delay,
    required this.speed,
    required this.rotationBase,
    required this.rotationSpeed,
    required this.w,
    required this.h,
    required this.color,
  });

  final double leftFraction;
  final double delay;
  final double speed;
  final double rotationBase;
  final double rotationSpeed;
  final double w;
  final double h;
  final Color color;
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.ctrl, required this.particles});

  final AnimationController ctrl;
  final List<_Particle> particles;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = ctrl.value;
          return Stack(
            children: particles.map((p) {
              final progress = ((t - p.delay) * p.speed).clamp(0.0, 1.0);
              final top = -p.h + progress * (h + p.h * 2);
              final angle =
                  p.rotationBase + progress * p.rotationSpeed * math.pi * 2;
              return Positioned(
                left: p.leftFraction * (w - p.w),
                top: top,
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: p.w,
                    height: p.h,
                    decoration: BoxDecoration(
                      color: p.color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
