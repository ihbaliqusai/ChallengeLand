import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Presents amounts already granted by the caller. It never changes a wallet.
void showCurrencyRewardOverlay(
  BuildContext context, {
  required int coins,
  required int gems,
}) {
  if (coins <= 0 && gems <= 0) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final media = MediaQuery.maybeOf(context);
  final direction = Directionality.of(context);
  final sourceRoute = ModalRoute.of(context);
  // Claim dialogs intentionally close immediately after showing the receipt.
  // Let those rewards hand off to the stable navigator overlay, while rewards
  // originating on a full page belong to that page's lifetime.
  final ownerRoute = sourceRoute is PageRoute<dynamic> ? sourceRoute : null;
  final routeTicker =
      TickerMode.getNotifier(ownerRoute == null ? overlay.context : context);
  final source = WeakReference(context as Element);
  var removed = false;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CurrencyRewardOverlay(
      coins: coins,
      gems: gems,
      direction: direction,
      routeTicker: routeTicker,
      ownerRoute: ownerRoute,
      sourceMounted: () => ownerRoute == null || source.target?.mounted == true,
      preferStatic: media?.disableAnimations == true ||
          media?.accessibleNavigation == true,
      accessibleNavigation: media?.accessibleNavigation == true,
      onFinished: () {
        if (removed) return;
        removed = true;
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _CurrencyRewardOverlay extends StatefulWidget {
  const _CurrencyRewardOverlay({
    required this.coins,
    required this.gems,
    required this.direction,
    required this.routeTicker,
    required this.ownerRoute,
    required this.sourceMounted,
    required this.preferStatic,
    required this.accessibleNavigation,
    required this.onFinished,
  });

  final int coins, gems;
  final TextDirection direction;
  final ValueListenable<bool> routeTicker;
  final ModalRoute<dynamic>? ownerRoute;
  final bool Function() sourceMounted;
  final bool preferStatic, accessibleNavigation;
  final VoidCallback onFinished;

  @override
  State<_CurrencyRewardOverlay> createState() => _CurrencyRewardOverlayState();
}

class _CurrencyRewardOverlayState extends State<_CurrencyRewardOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Timer _expiry;
  bool _static = false, _appActive = true, _finished = false;
  bool _routeRebuildQueued = false, _listeningToRoute = false;

  bool get _sourceActive =>
      widget.sourceMounted() && (widget.ownerRoute?.isActive ?? true);
  bool get _visible => _appActive && _sourceActive && widget.routeTicker.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_static) _finish();
      });
    // Start the finite deadline before registering external listeners. The
    // source may have been removed between insertion and this first build.
    _expiry = Timer(
      Duration(seconds: widget.accessibleNavigation ? 6 : 4),
      _finish,
    );
    if (!_sourceActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    widget.routeTicker.addListener(_routeChanged);
    _listeningToRoute = true;
    // A removed route need not notify its final TickerMode value. Watch its
    // completion too, without retaining this short-lived overlay until a later pop.
    final owner = widget.ownerRoute;
    if (owner != null) {
      final weakState = WeakReference(this);
      owner.popped.then((_) => weakState.target?._finish());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static = widget.preferStatic ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _syncPlayback();
  }

  void _syncPlayback() {
    if (_static || !_visible) {
      _controller.stop();
    } else if (!_finished && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  void _routeChanged() {
    if (!mounted) return;
    _syncPlayback();
    // TickerMode can notify while a different route subtree is being built.
    // Pause immediately, then update this overlay after that build completes.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_routeRebuildQueued) return;
      _routeRebuildQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeRebuildQueued = false;
        if (mounted && !_finished) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _routeChanged();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _expiry.cancel();
    if (_listeningToRoute) widget.routeTicker.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arabic = widget.direction == TextDirection.rtl;
    final amounts = <String>[
      if (widget.coins > 0)
        arabic ? '${widget.coins} عملة' : '${widget.coins} coins',
      if (widget.gems > 0)
        arabic ? '${widget.gems} جوهرة' : '${widget.gems} gems',
    ].join(arabic ? ' و' : ' and ');
    final announcement = arabic
        ? 'تمت إضافة $amounts إلى رصيدك'
        : '$amounts added to your balance';

    return IgnorePointer(
      key: const ValueKey('currency-reward-overlay'),
      child: Offstage(
        offstage: !_visible,
        child: Directionality(
          textDirection: widget.direction,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: LayoutBuilder(builder: (context, area) {
                final width = math.min(420.0, area.maxWidth);
                return Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: AnimatedBuilder(
                        animation: _controller,
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label: announcement,
                          excludeSemantics: true,
                          child: RepaintBoundary(
                            child: _RewardCard(
                              coins: widget.coins,
                              gems: widget.gems,
                              title: arabic
                                  ? 'تمت إضافة المكافأة إلى رصيدك'
                                  : 'Reward added to your balance',
                              animation: _controller,
                              staticPresentation: _static,
                            ),
                          ),
                        ),
                        builder: (context, child) {
                          if (_static) return child!;
                          final t = _controller.value;
                          final enter = Curves.easeOutCubic
                              .transform((t / .16).clamp(0.0, 1.0));
                          final exit = Curves.easeInCubic
                              .transform(((t - .82) / .18).clamp(0.0, 1.0));
                          return Opacity(
                            opacity: enter * (1 - exit),
                            child: Transform.translate(
                              offset: Offset(0, (1 - enter) * 22 - exit * 10),
                              child: Transform.scale(
                                scale: .94 + enter * .06,
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.coins,
    required this.gems,
    required this.title,
    required this.animation,
    required this.staticPresentation,
  });
  final int coins, gems;
  final String title;
  final Animation<double> animation;
  final bool staticPresentation;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('currency-reward-card'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF193569), Color(0xFF0A1435)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB7944E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5503081A),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: CustomPaint(
            foregroundPainter:
                staticPresentation ? null : _RewardSparkles(animation),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFE5AC),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (coins > 0) _RewardAmount(amount: coins, gem: false),
                      if (gems > 0) _RewardAmount(amount: gems, gem: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount({required this.amount, required this.gem});
  final int amount;
  final bool gem;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey(gem ? 'currency-reward-gems' : 'currency-reward-coins'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x55030C25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: gem ? const Color(0xFF78D8EF) : const Color(0xFFECC875),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: const Size.square(32), painter: _Medallion(gem)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+$amount',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Independently drawn vector marks; no external artwork or font glyphs.
class _Medallion extends CustomPainter {
  const _Medallion(this.gem);
  final bool gem;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .45;
    final paint = Paint();
    if (gem) {
      final shape = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy - radius * .25)
        ..lineTo(center.dx + radius * .6, center.dy + radius * .55)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius * .6, center.dy + radius * .55)
        ..lineTo(center.dx - radius, center.dy - radius * .25)
        ..close();
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD5FCFF), Color(0xFF41B9E1), Color(0xFF257BB5)],
      ).createShader(Offset.zero & size);
      canvas.drawPath(shape, paint);
      paint
        ..shader = null
        ..color = const Color(0xFFB8F6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(shape, paint);
      canvas.drawLine(Offset(center.dx - radius, center.dy - radius * .25),
          Offset(center.dx + radius, center.dy - radius * .25), paint);
      canvas.drawLine(Offset(center.dx, center.dy - radius),
          Offset(center.dx, center.dy + radius), paint);
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEDAE), Color(0xFFEFC053), Color(0xFFB57620)],
      ).createShader(Offset.zero & size);
      canvas.drawCircle(center, radius, paint);
      paint
        ..shader = null
        ..color = const Color(0xFF875512)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, radius * .76, paint);
      paint
        ..color = const Color(0xFFFFE9A1)
        ..style = PaintingStyle.fill;
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final length = radius * (i.isEven ? .5 : .22);
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * length;
        if (i == 0) {
          star.moveTo(point.dx, point.dy);
        } else {
          star.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(star..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_Medallion oldDelegate) => oldDelegate.gem != gem;
}

class _RewardSparkles extends CustomPainter {
  _RewardSparkles(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (animation.value / .45).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color =
          Color.lerp(const Color(0xFFFFDF8D), const Color(0x00FFDF8D), t)!;
    for (var i = 0; i < 12; i++) {
      final fromLeft = i.isEven;
      final origin = Offset(fromLeft ? 0 : size.width, size.height * .55);
      final horizontal = (fromLeft ? 1 : -1) * (22 + i * 8) * t;
      final vertical = -(12 + (i % 5) * 12) * math.sin(t * math.pi);
      final position = origin + Offset(horizontal, vertical);
      canvas.drawLine(position, position + const Offset(2, -3), paint);
    }
  }

  @override
  bool shouldRepaint(_RewardSparkles oldDelegate) =>
      oldDelegate.animation != animation;
}
