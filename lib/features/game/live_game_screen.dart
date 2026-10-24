import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/challenge_card.dart';
import '../../models/live_room_state.dart';
import '../../models/player_role.dart';
import '../../models/room.dart';
import '../../models/room_player.dart';
import '../../models/team.dart';
import '../../services/firebase_realtime_service.dart';
import '../../state/auth_provider.dart';

// ─── أحجام ثابتة ───────────────────────────────────────────────────────────
const _kCardRadius = 24.0;
const _kSectionRadius = 16.0;

// ════════════════════════════════════════════════════════════════════════════
//  الشاشة الرئيسية
// ════════════════════════════════════════════════════════════════════════════

class LiveGameScreen extends StatefulWidget {
  const LiveGameScreen({super.key});

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen>
    with TickerProviderStateMixin {
  // ── Route args ──────────────────────────────────────────────────────────
  Room? _room;
  String _currentUid = '';
  bool _argsReady = false;

  // ── Services ─────────────────────────────────────────────────────────────
  final _rtdb = FirebaseRealtimeService();
  StreamSubscription<LiveRoomState>? _roomSub;

  // ── Live state ───────────────────────────────────────────────────────────
  LiveRoomState? _state;
  bool _didNavigateAway = false;
  int _roundResultShown = -1; // تتبع أي جولة عُرضت نتائجها

  // ── Timer ────────────────────────────────────────────────────────────────
  Timer? _tickTimer;
  bool _didVibrate = false;
  bool _lastTenSoundEnabled = true;

  // ── Guesser input ────────────────────────────────────────────────────────
  final _guessCtrl = TextEditingController();
  final _guessFocus = FocusNode();
  bool _submittingGuess = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _celebCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _celebScale = CurvedAnimation(
    parent: _celebCtrl,
    curve: Curves.elasticOut,
  );
  bool _showCelebration = false;
  String _celebText = '';

  late final AnimationController _timeAlertCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  // ── Previous answers snapshot ─────────────────────────────────────────────
  int _prevCorrectCount = 0;

  // ─────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromRoute());
  }

  void _initFromRoute() {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _room = args['room'] as Room?;
      _currentUid =
          (args['currentUid'] as String?) ??
          context.read<AuthProvider>().user?.uid ??
          '';
    }
    if (_room == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _argsReady = true);
    _roomSub = _rtdb.listenToRoom(_room!.id).listen(_onStateUpdate);
  }

  void _onStateUpdate(LiveRoomState next) {
    if (!mounted) return;
    setState(() => _state = next);

    // تشغيل التايمر فقط عند الجولات النشطة
    if (next.isRoundActive) {
      _ensureTimer();
      _didVibrate = false;
      _lastTenSoundEnabled = true;
    } else {
      _tickTimer?.cancel();
    }

    // احتفال عند ظهور إجابة صحيحة جديدة
    final correctNow = next.answers.values
        .where((a) => a.isCorrect == true)
        .length;
    if (correctNow > _prevCorrectCount) {
      _prevCorrectCount = correctNow;
      final latestCorrect = next.answers.values
          .where((a) => a.isCorrect == true)
          .reduce((a, b) => a.submittedAt > b.submittedAt ? a : b);
      _triggerCelebration(latestCorrect.text);
    } else {
      _prevCorrectCount = correctNow;
    }

    // نتيجة الجولة: تُعرض مرة واحدة لكل جولة
    if (next.phase == GamePhase.roundResult &&
        _roundResultShown != next.currentRound) {
      _roundResultShown = next.currentRound;
      Future.microtask(() {
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.roundResult,
          arguments: {
            'room': _room!,
            'liveState': next,
            'currentUid': _currentUid,
          },
        );
      });
    }

    // نهاية اللعبة
    if (next.phase == GamePhase.gameOver && !_didNavigateAway) {
      _didNavigateAway = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.gameOver,
          arguments: {'room': _room!, 'currentUid': _currentUid},
        );
      });
    }
  }

  void _ensureTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final rem = _calcRemaining();

      // اهتزاز مزدوج عند انتهاء الوقت
      if (rem == 0 && !_didVibrate) {
        _didVibrate = true;
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 150),
          () => HapticFeedback.heavyImpact(),
        );
      }

      // نغمة + اهتزاز خفيف في آخر 10 ثوانٍ
      if (rem <= 10 && rem > 0 && _lastTenSoundEnabled) {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);
      }
    });
  }

  void _triggerCelebration(String text) {
    setState(() {
      _showCelebration = true;
      _celebText = text;
    });
    _celebCtrl.forward(from: 0);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _showCelebration = false);
    });
  }

  int _calcRemaining() {
    final s = _state;
    if (s == null || s.roundStartedAt == null) return s?.roundDuration ?? 60;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - s.roundStartedAt!) ~/ 1000;
    return (s.roundDuration - elapsed).clamp(0, s.roundDuration);
  }

  bool get _isDescriber => _state?.currentDescriber == _currentUid;

  @override
  void dispose() {
    _roomSub?.cancel();
    _tickTimer?.cancel();
    _guessCtrl.dispose();
    _guessFocus.dispose();
    _celebCtrl.dispose();
    _timeAlertCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _markLastCorrect() async {
    final s = _state;
    final room = _room;
    if (s == null || room == null) return;
    final pending =
        s.answers.entries
            .where((e) => e.value.isPending && e.value.text != '__skip__')
            .toList()
          ..sort((a, b) => b.value.submittedAt.compareTo(a.value.submittedAt));
    if (pending.isEmpty) return;
    await _rtdb.markAnswer(room.id, pending.first.key, isCorrect: true);
  }

  Future<void> _skipCard() async {
    final room = _room;
    if (room == null) return;
    // إرسال إشارة التخطي عبر إجابة خاصة — الهوست يعالجها ليبدأ جولة جديدة
    await _rtdb.submitAnswer(room.id, _currentUid, '__skip__');
    HapticFeedback.lightImpact();
  }

  Future<void> _submitGuess() async {
    final text = _guessCtrl.text.trim();
    final room = _room;
    if (text.isEmpty || _submittingGuess || room == null) return;
    setState(() => _submittingGuess = true);
    try {
      await _rtdb.submitAnswer(room.id, _currentUid, text);
      _guessCtrl.clear();
    } finally {
      if (mounted) setState(() => _submittingGuess = false);
    }
  }

  Future<void> _judgeAnswer(String uid, bool correct) async {
    final room = _room;
    if (room == null) return;
    await _rtdb.markAnswer(room.id, uid, isCorrect: correct);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_argsReady || _state == null) {
      return const Scaffold(
        backgroundColor: AppColors.challengeDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.challengeGold),
        ),
      );
    }
    final s = _state!;
    final remaining = _calcRemaining();
    final isLow = remaining <= 10 && s.isRoundActive;

    return Scaffold(
      backgroundColor: AppColors.challengeDark,
      body: Stack(
        children: [
          _GradientBackground(isLow: isLow),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  round: s.currentRound,
                  totalRounds: _room!.totalRounds,
                  remaining: remaining,
                  isLow: isLow,
                  isDescriber: _isDescriber,
                ),
                _RoundProgressBar(
                  current: s.currentRound,
                  total: _room!.totalRounds,
                ),
                const SizedBox(height: 4),
                Expanded(child: _buildPhaseBody(s)),
              ],
            ),
          ),
          if (_showCelebration)
            _CelebrationOverlay(text: _celebText, scale: _celebScale),
          if (s.phase == GamePhase.roundResult)
            _RoundResultSheet(
              round: s.currentRound,
              total: _room!.totalRounds,
              correctCount: s.answers.values
                  .where((a) => a.isCorrect == true)
                  .length,
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseBody(LiveRoomState s) {
    switch (s.phase) {
      case GamePhase.lobby:
        return const _WaitingView(message: 'في انتظار بدء اللعبة...');
      case GamePhase.describing:
      case GamePhase.guessing:
        return _isDescriber ? _buildDescriberBody(s) : _buildGuesserBody(s);
      case GamePhase.roundResult:
        return const _WaitingView(message: 'جارٍ احتساب الجولة...');
      case GamePhase.gameOver:
        return const _WaitingView(message: 'انتهت اللعبة! 🎉');
    }
  }

  // ── شاشة المُوصِف ─────────────────────────────────────────────────────────

  Widget _buildDescriberBody(LiveRoomState s) {
    final card = s.currentCard;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScoreRow(room: _room!, currentUid: _currentUid),
          const SizedBox(height: 14),
          if (card != null) ...[
            _WordCard(card: card),
            const SizedBox(height: 18),
            _DescriberButtons(onCorrect: _markLastCorrect, onSkip: _skipCard),
          ] else
            _PlaceholderCard(message: 'في انتظار البطاقة...'),
          const SizedBox(height: 20),
          _GuessesFeed(
            state: s,
            isDescriber: true,
            getPlayerName: _getPlayerName,
            onJudge: _judgeAnswer,
            roomId: _room!.id,
          ),
        ],
      ),
    );
  }

  // ── شاشة المُخمِّن ─────────────────────────────────────────────────────────

  Widget _buildGuesserBody(LiveRoomState s) {
    final card = s.currentCard;
    final describerName = _resolveDescriberName(s);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScoreRow(room: _room!, currentUid: _currentUid),
          const SizedBox(height: 14),
          _DescriberBanner(name: describerName),
          const SizedBox(height: 12),
          if (card != null) ...[
            _GuesserHintsCard(card: card),
            const SizedBox(height: 16),
          ],
          _GuessInputRow(
            controller: _guessCtrl,
            focusNode: _guessFocus,
            isLoading: _submittingGuess,
            onSubmit: _submitGuess,
          ),
          const SizedBox(height: 16),
          _GuessesFeed(
            state: s,
            isDescriber: false,
            getPlayerName: _getPlayerName,
            onJudge: null,
            roomId: _room!.id,
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getPlayerName(String uid) {
    return _room!.players
            .cast<RoomPlayer?>()
            .firstWhere((p) => p?.uid == uid, orElse: () => null)
            ?.username ??
        uid.substring(0, uid.length.clamp(0, 6));
  }

  String? _resolveDescriberName(LiveRoomState s) {
    final uid = s.currentDescriber;
    if (uid == null) return null;
    return _getPlayerName(uid);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Widgets مستقلة — الشريط العلوي
// ════════════════════════════════════════════════════════════════════════════

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.isLow});
  final bool isLow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLow
              ? [
                  AppColors.challengeRed.withValues(alpha: 0.12),
                  AppColors.challengeNavy,
                ]
              : [AppColors.challengeDark, AppColors.challengeNavy],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.isLow,
    required this.isDescriber,
  });

  final int round;
  final int totalRounds;
  final int remaining;
  final bool isLow;
  final bool isDescriber;

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.challengeCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLow
              ? AppColors.challengeRed.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.07),
          width: isLow ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // ─ الجولة
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الجولة',
                style: TextStyle(
                  color: AppColors.challengeGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$round / $totalRounds',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const Spacer(),

          // ─ التايمر
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isLow
                  ? AppColors.challengeRed.withValues(alpha: 0.18)
                  : AppColors.challengeBlue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLow ? AppColors.challengeRed : AppColors.challengeBlue,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 16,
                  color: isLow
                      ? AppColors.challengeRed
                      : AppColors.challengeCyan,
                ),
                const SizedBox(width: 5),
                Text(
                  _fmt(remaining),
                  style: TextStyle(
                    color: isLow ? AppColors.challengeRed : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // ─ الدور
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDescriber
                  ? AppColors.challengePurple.withValues(alpha: 0.22)
                  : AppColors.challengeGreen.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isDescriber ? '🎭 مُوصِف' : '🤔 مُخمِّن',
              style: TextStyle(
                color: isDescriber
                    ? AppColors.challengePurple
                    : AppColors.challengeGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundProgressBar extends StatelessWidget {
  const _RoundProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current - 1) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: AppColors.challengeCard,
          valueColor: const AlwaysStoppedAnimation(AppColors.challengeGold),
          minHeight: 4,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  النقاط
// ════════════════════════════════════════════════════════════════════════════

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.room, required this.currentUid});
  final Room room;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    if (room.gameType.isTeamMode && room.teams.length >= 2) {
      return Row(
        children: [
          for (int i = 0; i < room.teams.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _TeamScoreCard(
                team: room.teams[i],
                isHighlighted: room.teams[i].playerIds.contains(currentUid),
              ),
            ),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (int i = 0; i < room.players.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PlayerScoreCard(
              player: room.players[i],
              isSelf: room.players[i].uid == currentUid,
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamScoreCard extends StatelessWidget {
  const _TeamScoreCard({required this.team, required this.isHighlighted});
  final Team team;
  final bool isHighlighted;

  Color get _tc => team.color;

  @override
  Widget build(BuildContext context) {
    final c = _tc;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isHighlighted ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(_kSectionRadius),
        border: Border.all(
          color: c.withValues(alpha: isHighlighted ? 0.65 : 0.22),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(team.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            '${team.score}',
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            team.name.split(' ').last,
            style: TextStyle(color: c.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreCard extends StatelessWidget {
  const _PlayerScoreCard({required this.player, required this.isSelf});
  final RoomPlayer player;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final c = isSelf ? AppColors.challengeGold : AppColors.challengeCyan;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isSelf ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(_kSectionRadius),
        border: Border.all(
          color: c.withValues(alpha: isSelf ? 0.55 : 0.22),
          width: isSelf ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSelf ? '👤 أنت' : player.username,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${player.score}',
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              Text(
                'نقطة',
                style: TextStyle(color: c.withValues(alpha: 0.6), fontSize: 10),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (player.score / 25).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(c),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  بطاقة الكلمة (شاشة المُوصِف)
// ════════════════════════════════════════════════════════════════════════════

class _WordCard extends StatelessWidget {
  const _WordCard({required this.card});
  final ChallengeCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.challengePurple.withValues(alpha: 0.38),
            AppColors.challengeCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: AppColors.challengePurple.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.challengePurple.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // نوع البطاقة
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.typeEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                card.typeNameAr,
                style: const TextStyle(
                  color: AppColors.challengeGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),

          // تسمية "الكلمة"
          Text(
            '🎯 الكلمة:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // المحتوى الرئيسي
          Text(
            card.mainContent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.3,
            ),
          ),

          // الكلمات الممنوعة
          if (card.tabooWords.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '🚫 ممنوع ذكر:',
              style: TextStyle(
                color: AppColors.challengeRed.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: card.tabooWords
                  .map((w) => _TabooChip(word: w))
                  .toList(),
            ),
          ],

          const SizedBox(height: 16),

          // الفئة والصعوبة
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _InfoChip(
                '${card.categoryEmoji} ${card.categoryName}',
                AppColors.challengeCyan,
              ),
              _InfoChip(
                '${'⭐' * card.difficultyStars} ${card.difficultyNameAr}',
                AppColors.challengeGold,
              ),
              _InfoChip('${card.points} نقطة', AppColors.challengeGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabooChip extends StatelessWidget {
  const _TabooChip({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.challengeRed.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.challengeRed.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        word,
        style: const TextStyle(
          color: AppColors.challengeRed,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  أزرار المُوصِف
// ════════════════════════════════════════════════════════════════════════════

class _DescriberButtons extends StatelessWidget {
  const _DescriberButtons({required this.onCorrect, required this.onSkip});
  final VoidCallback onCorrect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GameActionButton(
            label: 'تخطي ⏭️',
            sublabel: '-1 نقطة',
            icon: Icons.skip_next_rounded,
            color: AppColors.challengeOrange,
            onPressed: onSkip,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _GameActionButton(
            label: 'صح ✅',
            sublabel: '+2 نقطة',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.challengeGreen,
            onPressed: onCorrect,
          ),
        ),
      ],
    );
  }
}

class _GameActionButton extends StatelessWidget {
  const _GameActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Text(
            sublabel,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  شاشة المُخمِّن — بطاقة المُوصِف + تلميحات
// ════════════════════════════════════════════════════════════════════════════

class _DescriberBanner extends StatelessWidget {
  const _DescriberBanner({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.challengeCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_kSectionRadius),
        border: Border.all(
          color: AppColors.challengePurple.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.challengePurple.withValues(alpha: 0.22),
              border: Border.all(
                color: AppColors.challengePurple.withValues(alpha: 0.5),
              ),
            ),
            child: const Center(
              child: Text('🎭', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'زميلك ${name ?? '...'} يصف الآن',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  'استمع جيداً وخمّن الكلمة!',
                  style: TextStyle(
                    color: AppColors.challengeGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.graphic_eq_rounded,
            color: AppColors.challengePurple,
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _GuesserHintsCard extends StatelessWidget {
  const _GuesserHintsCard({required this.card});
  final ChallengeCard card;

  @override
  Widget build(BuildContext context) {
    final charCount = card.mainContent.replaceAll(' ', '').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.challengeCard.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(_kSectionRadius),
        border: Border.all(
          color: AppColors.challengeCyan.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HintRow(
            emoji: '💬',
            label: 'الفئة:',
            value: '${card.categoryEmoji} ${card.categoryName}',
            valueColor: AppColors.challengeCyan,
          ),
          const SizedBox(height: 8),
          _HintRow(
            emoji: '💡',
            label: 'عدد الحروف:',
            value: '$charCount',
            valueColor: AppColors.challengeGold,
            valueFontSize: 20,
          ),
          if (card.hint != null && card.hint!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HintRow(
              emoji: '🔍',
              label: 'تلميح:',
              value: card.hint!,
              valueColor: Colors.white70,
            ),
          ],
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.valueColor,
    this.valueFontSize = 14,
  });
  final String emoji;
  final String label;
  final String value;
  final Color valueColor;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          '$label ',
          style: const TextStyle(
            color: AppColors.challengeGray,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: valueFontSize,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  حقل الإدخال
// ════════════════════════════════════════════════════════════════════════════

class _GuessInputRow extends StatelessWidget {
  const _GuessInputRow({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'اكتب تخمينك...',
              hintStyle: const TextStyle(color: AppColors.challengeGray),
              filled: true,
              fillColor: AppColors.challengeCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.challengeBlue,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.challengeBlue,
              disabledBackgroundColor: AppColors.challengeBlue.withValues(
                alpha: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  قسم التخمينات
// ════════════════════════════════════════════════════════════════════════════

class _GuessesFeed extends StatelessWidget {
  const _GuessesFeed({
    required this.state,
    required this.isDescriber,
    required this.getPlayerName,
    required this.onJudge,
    required this.roomId,
  });

  final LiveRoomState state;
  final bool isDescriber;
  final String Function(String uid) getPlayerName;
  final Future<void> Function(String uid, bool correct)? onJudge;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final answers =
        state.answers.entries.where((e) => e.value.text != '__skip__').toList()
          ..sort((a, b) => b.value.submittedAt.compareTo(a.value.submittedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDescriber ? 'فريقك يخمّن الآن...' : 'التخمينات',
          style: const TextStyle(
            color: AppColors.challengeGray,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        if (answers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                isDescriber
                    ? 'ابدأ الوصف وانتظر تخمينات فريقك'
                    : 'كن أول من يخمّن!',
                style: const TextStyle(
                  color: AppColors.challengeGray,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...answers.map(
            (entry) => _GuessChip(
              answer: entry.value,
              playerName: getPlayerName(entry.key),
              uid: entry.key,
              isDescriber: isDescriber,
              onMarkCorrect: onJudge != null
                  ? () => onJudge!(entry.key, true)
                  : null,
              onMarkWrong: onJudge != null
                  ? () => onJudge!(entry.key, false)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _GuessChip extends StatelessWidget {
  const _GuessChip({
    required this.answer,
    required this.playerName,
    required this.uid,
    required this.isDescriber,
    this.onMarkCorrect,
    this.onMarkWrong,
  });

  final AnswerState answer;
  final String playerName;
  final String uid;
  final bool isDescriber;
  final VoidCallback? onMarkCorrect;
  final VoidCallback? onMarkWrong;

  @override
  Widget build(BuildContext context) {
    late final Color border;
    late final Color bg;
    late final Widget trailing;

    if (answer.isCorrect == true) {
      border = AppColors.challengeGreen;
      bg = AppColors.challengeGreen.withValues(alpha: 0.13);
      trailing = const Icon(
        Icons.check_circle_rounded,
        color: AppColors.challengeGreen,
        size: 22,
      );
    } else if (answer.isCorrect == false) {
      border = AppColors.challengeRed;
      bg = AppColors.challengeRed.withValues(alpha: 0.10);
      trailing = const Icon(
        Icons.cancel_rounded,
        color: AppColors.challengeRed,
        size: 22,
      );
    } else {
      border = Colors.white.withValues(alpha: 0.12);
      bg = AppColors.challengeCard.withValues(alpha: 0.55);
      trailing = isDescriber
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _JudgeBtn(
                  icon: Icons.check_rounded,
                  color: AppColors.challengeGreen,
                  onTap: onMarkCorrect,
                ),
                const SizedBox(width: 6),
                _JudgeBtn(
                  icon: Icons.close_rounded,
                  color: AppColors.challengeRed,
                  onTap: onMarkWrong,
                ),
              ],
            )
          : const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.challengeGray,
              ),
            );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            playerName,
            style: const TextStyle(
              color: AppColors.challengeGold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: AppColors.challengeGray, fontSize: 12),
          ),
          Expanded(
            child: Text(
              answer.text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _JudgeBtn extends StatelessWidget {
  const _JudgeBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Overlays: احتفال ونتيجة الجولة
// ════════════════════════════════════════════════════════════════════════════

class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({required this.text, required this.scale});
  final String text;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: ScaleTransition(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.challengeGreen.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.challengeGreen.withValues(alpha: 0.45),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text(
                  'إجابة صحيحة!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$text"',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundResultSheet extends StatelessWidget {
  const _RoundResultSheet({
    required this.round,
    required this.total,
    required this.correctCount,
  });
  final int round;
  final int total;
  final int correctCount;

  @override
  Widget build(BuildContext context) {
    final isLast = round >= total;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.challengeCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.challengeGold.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.challengeGold.withValues(alpha: 0.15),
                blurRadius: 36,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text(
                'نهاية الجولة $round',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.challengeGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.challengeGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'الإجابات الصحيحة: $correctCount',
                  style: const TextStyle(
                    color: AppColors.challengeGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isLast
                    ? 'انتهت اللعبة! جارٍ احتساب النتائج...'
                    : 'في انتظار الجولة ${round + 1}...',
                style: const TextStyle(
                  color: AppColors.challengeGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.challengeGold,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Misc
// ════════════════════════════════════════════════════════════════════════════

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.challengeCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.challengeGray, fontSize: 14),
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.challengeGold,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
