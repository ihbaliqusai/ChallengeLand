import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../models/live_room_state.dart';
import '../../models/player_role.dart';
import '../../models/room.dart';
import '../../models/room_player.dart';
import '../../models/team.dart';

class RoundResultScreen extends StatefulWidget {
  const RoundResultScreen({super.key});

  @override
  State<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends State<RoundResultScreen>
    with TickerProviderStateMixin {
  Room? _room;
  LiveRoomState? _liveState;
  String _currentUid = '';
  bool _initialized = false;

  int _countdown = 3;
  Timer? _countdownTimer;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _scoreCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _entryScale = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.elasticOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _room = args?['room'] as Room?;
      _liveState = args?['liveState'] as LiveRoomState?;
      _currentUid = args?['currentUid'] as String? ?? '';
      _entryCtrl.forward();
      _scoreCtrl.forward();
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _entryCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  // حساب النقاط المكتسبة من الإجابات مباشرةً
  Map<String, int> _calcRoundPoints() {
    final state = _liveState;
    if (state == null) return {};
    final points = <String, int>{};
    final describerUid = state.currentDescriber;

    for (final entry in state.answers.entries) {
      final uid = entry.key;
      final answer = entry.value;

      if (answer.text == '__skip__') {
        if (uid == describerUid) {
          points[uid] = (points[uid] ?? 0) + ScoreUpdate.skipDescriberPenalty;
        }
      } else if (answer.isCorrect == true) {
        points[uid] = (points[uid] ?? 0) + ScoreUpdate.correctGuesserPoints;
        if (describerUid != null) {
          points[describerUid] =
              (points[describerUid] ?? 0) + ScoreUpdate.correctDescriberPoints;
        }
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final state = _liveState;
    if (room == null || state == null) {
      return const Scaffold(backgroundColor: AppColors.challengeDark);
    }

    final roundPoints = _calcRoundPoints();
    final sortedPlayers = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.challengeDark, AppColors.challengeNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(room, state),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      if (room.gameType.isTeamMode) _buildTeamScores(room),
                      _buildAnswersList(state, roundPoints),
                      const SizedBox(height: 12),
                      _buildPlayerLeaderboard(room, sortedPlayers, roundPoints),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildCountdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Room room, LiveRoomState state) {
    return ScaleTransition(
      scale: _entryScale,
      child: AppCard(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        gradient: const LinearGradient(
          colors: [AppColors.challengePurple, AppColors.challengeBlue],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نتيجة الجولة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الجولة ${state.currentRound} من ${room.totalRounds}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.challengeGold,
                  size: 48,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScores(Room room) {
    final sorted = [...room.teams]..sort((a, b) => b.score.compareTo(a.score));
    final maxScore = sorted.isEmpty
        ? 1
        : sorted.first.score.clamp(1, double.maxFinite.toInt());

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
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
            const SizedBox(height: 12),
            ...sorted.map((team) {
              final color = _teamColor(team);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '${team.emoji} ${team.name}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: team.score),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        '$v',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: maxScore == 0 ? 0 : team.score / maxScore,
                        ),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: v,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswersList(LiveRoomState state, Map<String, int> roundPoints) {
    final answers =
        state.answers.entries.where((e) => e.value.text != '__skip__').toList()
          ..sort((a, b) => a.value.submittedAt.compareTo(b.value.submittedAt));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإجابات',
              style: TextStyle(
                color: AppColors.challengeGray,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (answers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'لم تُقدَّم أي إجابة هذه الجولة',
                    style: TextStyle(color: AppColors.challengeGray),
                  ),
                ),
              )
            else
              ...answers.map((entry) {
                final player = _room?.players.cast<RoomPlayer?>().firstWhere(
                  (p) => p?.uid == entry.key,
                  orElse: () => null,
                );
                final answer = entry.value;
                final isCorrect = answer.isCorrect;
                final isMe = entry.key == _currentUid;
                final isDescriber = entry.key == state.currentDescriber;
                final pts = isCorrect == true
                    ? (isDescriber
                          ? ScoreUpdate.correctDescriberPoints
                          : ScoreUpdate.correctGuesserPoints)
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect == true
                            ? Icons.check_circle_rounded
                            : isCorrect == false
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                        color: isCorrect == true
                            ? AppColors.challengeGreen
                            : isCorrect == false
                            ? AppColors.challengeRed
                            : AppColors.challengeGray,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player?.username ?? entry.key,
                              style: TextStyle(
                                color: isMe
                                    ? AppColors.challengeCyan
                                    : Colors.white,
                                fontWeight: isMe
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              answer.text,
                              style: const TextStyle(
                                color: AppColors.challengeGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pts != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.challengeGreen.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+$pts',
                            style: const TextStyle(
                              color: AppColors.challengeGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (isCorrect == false)
                        const Text(
                          '0',
                          style: TextStyle(
                            color: AppColors.challengeGray,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerLeaderboard(
    Room room,
    List<RoomPlayer> sorted,
    Map<String, int> roundPoints,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الترتيب',
            style: TextStyle(
              color: AppColors.challengeGray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...sorted.asMap().entries.map((e) {
            final rank = e.key + 1;
            final player = e.value;
            final isMe = player.uid == _currentUid;
            final earned = roundPoints[player.uid] ?? 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  _RankBadge(rank: rank),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      player.username,
                      style: TextStyle(
                        color: isMe ? AppColors.challengeCyan : Colors.white,
                        fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (earned != 0)
                    Text(
                      earned > 0 ? '+$earned  ' : '$earned  ',
                      style: TextStyle(
                        color: earned > 0
                            ? AppColors.challengeGreen
                            : AppColors.challengeRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: player.score),
                    duration: const Duration(milliseconds: 1200),
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
          }),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            'الجولة التالية خلال',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              '$_countdown',
              key: ValueKey(_countdown),
              style: const TextStyle(
                color: AppColors.challengeGold,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _teamColor(Team team) {
    return team.color;
  }
}

// ─── Rank Badge ──────────────────────────────────────────────────────────────

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
