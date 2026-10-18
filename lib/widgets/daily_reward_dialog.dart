import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_settings.dart';
import '../core/app_state.dart';
import 'currency_reward_overlay.dart';
import 'weekly_reward_artwork.dart';

/// A single claim action with a receipt-backed reveal and a weekly roadmap.
class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({super.key, this.autoOpen = false});
  final bool autoOpen;
  static bool _isShowing = false;

  static Future<void> show(BuildContext context,
      {bool autoOpen = false}) async {
    if (_isShowing) return;
    _isShowing = true;
    final state = context.read<AppState>();
    final settings = context.read<AppSettings>();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: DailyRewardDialog(autoOpen: autoOpen),
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _gold = weeklyRewardGold;
  late final AnimationController _reveal;
  Timer? _timer;
  bool _loading = true;
  bool _claiming = false;
  bool _revealed = false;
  String? _error;
  int _day = 1;
  Map<String, int>? _award;
  DateTime _date = DateTime.now().toUtc();
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_claiming || !mounted) return;
    try {
      await context
          .read<AppState>()
          .loadLevelData()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'تعذّر تحديث الصندوق. تحقق من الاتصال وأعد المحاولة.');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _day = context.read<AppState>().streakDay.clamp(1, 30);
    });
    _tick();
    if (widget.autoOpen &&
        !context.read<AppState>().claimedToday &&
        !_revealed) {
      await _claim();
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now().toUtc();
    final changedDay = now.year != _date.year ||
        now.month != _date.month ||
        now.day != _date.day;
    _date = now;
    setState(() => _remaining =
        DateTime.utc(now.year, now.month, now.day + 1).difference(now));
    if (changedDay && !_claiming) {
      setState(() {
        _loading = true;
        _revealed = false;
        _award = null;
        _error = null;
      });
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      unawaited(_refresh());
    }
  }

  Future<void> _claim() async {
    if (_loading || _claiming || _revealed) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final award = await state.claimDailyStreak();
    if (!mounted) return;
    setState(() {
      _claiming = false;
      if (award == null) {
        _error = state.dailyRewardError ?? 'تعذّر الاستلام. حاول مجددًا.';
      } else {
        _award = award;
        _day = state.streakDay;
        _revealed = true;
      }
    });
    if (award != null) {
      unawaited(context
          .read<AppSettings>()
          .playHaptic(style: 'medium')
          .catchError((_) => false));
      if (MediaQuery.of(context).disableAnimations) {
        _reveal.value = 1;
      } else {
        unawaited(_reveal.forward(from: 0));
      }
    }
  }

  void _close() {
    if (_claiming) return;
    if (_award != null) {
      showCurrencyRewardOverlay(context,
          coins: _award!['coins']!, gems: _award!['gems']!);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  String get _countdown {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_remaining.inHours)}:${two(_remaining.inMinutes % 60)}:${two(_remaining.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claimed = state.claimedToday && !_revealed && _error == null;
    final reward = _award ?? AppState.getRewardForDay(_day);
    final weekStart = ((_day - 1) ~/ 7) * 7 + 1;
    final weekEnd = math.min(weekStart + 6, 30);
    final completed = (_day - weekStart + (state.claimedToday ? 1 : 0))
        .clamp(0, weekEnd - weekStart + 1);
    final wide = MediaQuery.sizeOf(context).width >= 650;
    final compact = wide && MediaQuery.sizeOf(context).height < 500;

    return PopScope(
      canPop: !_claiming,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: RepaintBoundary(
                key: const ValueKey('weekly-reward-artwork'),
                child: WeeklyRewardFrame(
                    child: SingleChildScrollView(
                  padding: EdgeInsets.all(compact
                      ? 12
                      : wide
                          ? 20
                          : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('صندوق الأسبوع',
                                      style: TextStyle(
                                          color: _gold,
                                          fontSize: compact ? 22 : 26,
                                          height: 1.2,
                                          fontWeight: FontWeight.w900,
                                          shadows: const [
                                            Shadow(
                                                color: Color(0xFF754218),
                                                offset: Offset(0, 2),
                                                blurRadius: 2)
                                          ])),
                                  const SizedBox(height: 2),
                                  Text(
                                      'الأسبوع ${((_day - 1) ~/ 7) + 1} • الأيام $weekStart–$weekEnd من سلسلة 30 يومًا',
                                      style: TextStyle(
                                          color: const Color(0xFFD2C4E7),
                                          height: 1.25,
                                          fontSize: compact ? 11 : 12)),
                                ])),
                            const SizedBox(width: 12),
                            WeeklyRewardClose(
                                onPressed: _claiming ? null : _close),
                          ]),
                      SizedBox(height: compact ? 8 : 12),
                      if (wide)
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _hero(claimed)),
                              const SizedBox(width: 24),
                              Expanded(child: _details(reward, claimed)),
                            ])
                      else ...[_hero(claimed), _details(reward, claimed)],
                      SizedBox(height: compact ? 8 : 14),
                      Row(children: [
                        const Expanded(
                            child: Text('مسار هذا الأسبوع',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800))),
                        Text('$completed / ${weekEnd - weekStart + 1}',
                            style: const TextStyle(
                                color: _gold, fontWeight: FontWeight.w800)),
                      ]),
                      SizedBox(height: compact ? 4 : 8),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                              value: completed / (weekEnd - weekStart + 1),
                              minHeight: 5,
                              color: _gold,
                              backgroundColor: Colors.white10)),
                      SizedBox(height: compact ? 8 : 12),
                      LayoutBuilder(builder: (context, constraints) {
                        final count = weekEnd - weekStart + 1;
                        final columns = constraints.maxWidth < 420
                            ? math.min(count, 4)
                            : count;
                        return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(count, (index) {
                              final day = weekStart + index;
                              return SizedBox(
                                  width: math.min(
                                      140.0,
                                      (constraints.maxWidth -
                                              (columns - 1) * 6) /
                                          columns),
                                  child: _dayTile(day, state.claimedToday));
                            }));
                      }),
                      SizedBox(height: compact ? 8 : 14),
                      const Text(
                          'استلم مكافأة واحدة كل يوم. تتجدد عند منتصف الليل بتوقيت جهازك. تفويت يوم يعيد السلسلة إلى اليوم الأول.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              height: 1.6)),
                    ],
                  ),
                ))),
          ),
        ),
      ),
    );
  }

  Widget _hero(bool claimed) {
    final open = _revealed || claimed;
    return SizedBox(
        height: MediaQuery.sizeOf(context).height < 500 ? 114 : 176,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
              animation: _reveal,
              builder: (_, child) => Transform.scale(
                  scale: _revealed
                      ? 0.9 + Curves.easeOutBack.transform(_reveal.value) * 0.1
                      : 1,
                  child: child),
              child: WeeklyRewardChest(open: open)),
          if (_claiming)
            const Positioned(
                bottom: 4,
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _gold))),
        ]));
  }

  Widget _details(Map<String, int> reward, bool claimed) {
    final compact = MediaQuery.sizeOf(context).width >= 650 &&
        MediaQuery.sizeOf(context).height < 500;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          _revealed
              ? 'أُضيفت المكافأة إلى رصيدك!'
              : claimed
                  ? 'تم استلام مكافأة اليوم'
                  : 'مكافأة اليوم $_day',
          textAlign: TextAlign.center,
          style: TextStyle(
              color:
                  _revealed || claimed ? const Color(0xFF72DDB1) : Colors.white,
              fontSize: compact ? 16 : 18,
              height: 1.2,
              fontWeight: FontWeight.w900)),
      SizedBox(height: compact ? 6 : 12),
      Row(children: [
        Expanded(
            child: _currency(Icons.monetization_on_rounded,
                '${reward['coins']}', 'عملة', _gold)),
        if (reward['gems']! > 0) ...[
          const SizedBox(width: 8),
          Expanded(
              child: _currency(Icons.diamond_rounded, '${reward['gems']}',
                  'جوهرة', const Color(0xFF7DD9FF)))
        ],
      ]),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
                liveRegion: true,
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFFFB2AA), fontSize: 12)))),
      SizedBox(height: compact ? 8 : 14),
      if (claimed) ...[
        const Text('الصندوق التالي خلال',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        Text(_countdown,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _gold, fontSize: 26, fontWeight: FontWeight.w900)),
      ] else
        WeeklyRewardAction(
          onPressed: _loading || _claiming
              ? null
              : _revealed
                  ? _close
                  : _claim,
          icon: _revealed
              ? Icons.check_circle_rounded
              : Icons.inventory_2_rounded,
          label: _loading
              ? 'جارٍ تحميل الصندوق…'
              : _claiming
                  ? 'جارٍ استلام المكافأة…'
                  : _revealed
                      ? 'رائع، متابعة'
                      : _error != null
                          ? 'إعادة المحاولة'
                          : 'افتح واستلم',
        ),
    ]);
  }

  Widget _currency(IconData icon, String value, String label, Color color) {
    final compact = MediaQuery.sizeOf(context).width >= 650 &&
        MediaQuery.sizeOf(context).height < 500;
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 5 : 10, horizontal: 8),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A263F), Color(0xFF211B38)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF8B805E).withValues(alpha: .65),
              width: 1.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Flexible(
            child: Text('$value $label',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    fontSize: compact ? 14 : 16)))
      ]),
    );
  }

  Widget _dayTile(int day, bool claimedToday) {
    final compact = MediaQuery.sizeOf(context).width >= 650 &&
        MediaQuery.sizeOf(context).height < 500;
    final claimed = day < _day || (day == _day && claimedToday);
    final current = day == _day;
    final milestone = day % 7 == 0 || day == 30;
    final reward = AppState.getRewardForDay(day);
    final accent = claimed
        ? const Color(0xFF72DDB1)
        : current || milestone
            ? _gold
            : Colors.white38;
    return Semantics(
        label:
            'اليوم $day، ${reward['coins']} عملة، ${reward['gems']} جوهرة، ${claimed ? 'تم الاستلام' : current ? 'متاح اليوم' : 'قادم'}',
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: compact ? 6 : 10, horizontal: 3),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: current ? .22 : .12),
                    const Color(0xCC18263D)
                  ]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: current
                  ? [
                      BoxShadow(
                          color: _gold.withValues(alpha: .3), blurRadius: 10)
                    ]
                  : null,
              border: Border.all(
                  color: accent.withValues(alpha: current ? .95 : .6),
                  width: current ? 2 : 1.5)),
          child: Column(children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('اليوم $day',
                    style: TextStyle(
                        color: accent,
                        fontSize: compact ? 11 : 13,
                        height: 1.2,
                        fontWeight: FontWeight.w900))),
            SizedBox(height: compact ? 4 : 6),
            Icon(
                claimed
                    ? Icons.check_circle_rounded
                    : milestone
                        ? Icons.workspace_premium_rounded
                        : current
                            ? Icons.inventory_2_rounded
                            : Icons.lock_outline_rounded,
                color: accent,
                size: compact ? 22 : 28),
            SizedBox(height: compact ? 4 : 6),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${reward['coins']}',
                    style: TextStyle(
                        color: Colors.white,
                        height: 1.2,
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w900))),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${reward['gems']} ◆',
                    style: TextStyle(
                        color: const Color(0xFF7DD9FF),
                        height: 1.2,
                        fontSize: compact ? 10 : 12))),
          ]),
        ));
  }
}
