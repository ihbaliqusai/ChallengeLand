import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/app_state.dart';
import '../../state/guest_guide_provider.dart';
import 'game_presenter.dart';
import 'guide_steps.dart';
import 'guide_target.dart';

class GuestGuideHost extends StatefulWidget {
  const GuestGuideHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.onTrial,
    required this.onSignIn,
    this.onContact,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final VoidCallback onTrial;
  final VoidCallback onSignIn;
  final VoidCallback? onContact;

  @override
  State<GuestGuideHost> createState() => _GuestGuideHostState();
}

class _GuestGuideHostState extends State<GuestGuideHost>
    with WidgetsBindingObserver {
  GuestGuideProvider? _guide;
  Rect? _target;
  int _revision = 0;
  bool _syncScheduled = false;
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: _buildGuide);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final guide = context.read<GuestGuideProvider>();
    if (_guide == guide) return;
    _guide?.removeListener(_scheduleSync);
    _guide = guide..addListener(_scheduleSync);
    _scheduleSync();
  }

  @override
  void didChangeMetrics() => _scheduleSync();

  void _scheduleSync() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) unawaited(_synchronize());
    });
  }

  Future<void> _synchronize() async {
    final revision = ++_revision;
    final guide = _guide!;
    if (!guide.loaded ||
        !guide.expanded ||
        (context.read<AppState?>()?.user?.isAnonymous == false)) {
      return;
    }
    if (guide.route == AppRoutes.splash ||
        guide.route == AppRoutes.guestTrial ||
        guide.route == AppRoutes.guestSignIn ||
        guide.route == 'dialog') {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (guide.route != guide.step.route && navigator != null) {
      if (guide.navigateTo != null) {
        guide.navigateTo!(guide.step.route);
        return;
      }
      if (guide.step.route == AppRoutes.gameModes) {
        navigator.pushNamed(AppRoutes.gameModes);
      } else {
        navigator.popUntil(
          (route) => route.settings.name == AppRoutes.home || route.isFirst,
        );
      }
      return;
    }
    final targetContext = guide.targetContext();
    if (targetContext == null) {
      if (_target != null) setState(() => _target = null);
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      alignment: .03,
      curve: Curves.easeOutCubic,
    );
    if (!mounted || revision != _revision || !targetContext.mounted) return;
    final box = targetContext.findRenderObject();
    final host = context.findRenderObject();
    if (box is! RenderBox || host is! RenderBox || !box.hasSize) return;
    final offset = host.globalToLocal(box.localToGlobal(Offset.zero));
    setState(() => _target = (offset & box.size).inflate(6));
  }

  @override
  void dispose() {
    _revision++;
    _guide?.removeListener(_scheduleSync);
    WidgetsBinding.instance.removeObserver(this);
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _entry.markNeedsBuild();
    return Overlay(initialEntries: [_entry]);
  }

  Widget _buildGuide(BuildContext context) {
    final guide = context.watch<GuestGuideProvider>();
    final visitor = isGuideVisitor(context);
    final visible =
        visitor &&
        guide.lobbyReady &&
        guide.loaded &&
        guide.route != AppRoutes.splash &&
        guide.route != AppRoutes.login &&
        guide.route != AppRoutes.guestTrial &&
        guide.route != AppRoutes.guestSignIn &&
        guide.route != 'dialog';
    return Stack(
      children: [
        widget.child,
        if (visible)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: LayoutBuilder(
                  builder: (context, area) {
                    if (!guide.expanded) {
                      return Stack(
                        children: [
                          Positioned(
                            left: MediaQuery.paddingOf(context).left + 10,
                            bottom: MediaQuery.paddingOf(context).bottom + 8,
                            child: Semantics(
                              button: true,
                              label: AppStrings.guideOpen,
                              child: InkWell(
                                key: const ValueKey('guest-guide-minimized'),
                                onTap: guide.resume,
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: 124,
                                  height: 108,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFDF8),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          AppStrings.guideName,
                                          style: TextStyle(
                                            color: Color(0xFF263754),
                                            fontFamily: 'NotoSansArabic',
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: GamePresenter()),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final landscape = area.maxWidth > area.maxHeight;
                    final width = math.min(
                      440.0,
                      landscape ? area.maxWidth * .48 : area.maxWidth - 24,
                    );
                    final safe = MediaQuery.paddingOf(context);
                    final height = math.min(
                      landscape ? 380.0 : 440.0,
                      area.maxHeight - safe.vertical - 24,
                    );
                    final left =
                        landscape &&
                            _target != null &&
                            _target!.center.dx < area.maxWidth / 2
                        ? area.maxWidth - width - safe.right - 12
                        : landscape
                        ? safe.left + 12
                        : (area.maxWidth - width) / 2;
                    final hostHeight = landscape ? 86.0 : 112.0;
                    final bottomTop =
                        area.maxHeight - safe.bottom - 12 - height;
                    final topTop = safe.top + 12;
                    double overlapAt(double top) {
                      if (_target == null) return 0;
                      final panel = Rect.fromLTWH(left, top, width, height);
                      if (!panel.overlaps(_target!)) return 0;
                      final overlap = panel.intersect(_target!);
                      return overlap.width * overlap.height;
                    }

                    final panelTop = overlapAt(topTop) < overlapAt(bottomTop)
                        ? topTop
                        : bottomTop;
                    return PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) unawaited(guide.minimize());
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                if (_target?.contains(details.localPosition) ==
                                    true) {
                                  guide.next();
                                }
                              },
                              child: CustomPaint(
                                key: const ValueKey('guest-guide-spotlight'),
                                painter: _SpotlightPainter(_target),
                              ),
                            ),
                          ),
                          if (_target != null)
                            Positioned(
                              left: (_target!.right - 25).clamp(
                                8,
                                area.maxWidth - 40,
                              ),
                              top: (_target!.bottom - 8).clamp(
                                8,
                                area.maxHeight - 42,
                              ),
                              child: const IgnorePointer(
                                child: Icon(
                                  Icons.touch_app_rounded,
                                  color: Color(0xFFFFD761),
                                  size: 34,
                                ),
                              ),
                            ),
                          Positioned(
                            left: left,
                            top: panelTop,
                            width: width,
                            height: height,
                            child: Column(
                              children: [
                                Expanded(
                                  child: _GuideBubble(
                                    key: const ValueKey('guest-guide-bubble'),
                                    child: _GuidePanel(
                                      guide: guide,
                                      onTrial: widget.onTrial,
                                      onSignIn: widget.onSignIn,
                                      onContact: widget.onContact,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: hostHeight,
                                  width: hostHeight * 208 / 141,
                                  child: GamePresenter(
                                    message: guide.step.message,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.guide,
    required this.onTrial,
    required this.onSignIn,
    this.onContact,
  });
  final GuestGuideProvider guide;
  final VoidCallback onTrial;
  final VoidCallback onSignIn;
  final VoidCallback? onContact;
  static const ink = Color(0xFF263754);

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: const TextStyle(
      fontFamily: 'NotoSansArabic',
      color: ink,
      fontSize: 13,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: ink, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  AppStrings.guideName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const ValueKey('guest-guide-close'),
                tooltip: AppStrings.guideSkip,
                onPressed: guide.minimize,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: ink),
              ),
            ],
          ),
          Text(
            guide.step.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _SpokenText(
            key: ValueKey(guide.step.target),
            message: guide.step.message,
          ),
          const SizedBox(height: 12),
          if (guide.step.target == GuideTargets.help && onContact != null)
            TextButton(
              onPressed: onContact,
              child: const Text(AppStrings.guideContact),
            ),
          if (guide.isLast)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('guest-guide-try'),
                  onPressed: onTrial,
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    AppStrings.guideTry,
                    style: TextStyle(fontFamily: 'NotoSansArabic'),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('guest-guide-google'),
                  onPressed: onSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: const BorderSide(color: Color(0xFFB3A5D7)),
                  ),
                  child: const Text(
                    AppStrings.loginWithGoogle,
                    style: TextStyle(fontFamily: 'NotoSansArabic'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                if (guide.stepIndex > 0)
                  IconButton(
                    key: const ValueKey('guest-guide-previous'),
                    tooltip: AppStrings.guidePrevious,
                    onPressed: guide.previous,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: ink,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${AppStrings.guideStepLabel} '
                    '${guide.stepIndex + 1} / ${guestGuideSteps.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('guest-guide-next'),
                  onPressed: guide.next,
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text(
                    AppStrings.guideNext,
                    style: TextStyle(fontFamily: 'NotoSansArabic'),
                  ),
                ),
              ],
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              if (!guide.isLast)
                TextButton(
                  key: const ValueKey('guest-guide-try-shortcut'),
                  onPressed: onTrial,
                  style: TextButton.styleFrom(foregroundColor: ink),
                  child: const Text(
                    AppStrings.guideTry,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              TextButton(
                key: const ValueKey('guest-guide-skip'),
                onPressed: guide.minimize,
                style: TextButton.styleFrom(foregroundColor: ink),
                child: const Text(
                  AppStrings.guideSkip,
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SpokenText extends StatefulWidget {
  const _SpokenText({super.key, required this.message});
  final String message;
  @override
  State<_SpokenText> createState() => _SpokenTextState();
}

class _SpokenTextState extends State<_SpokenText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing;
  late final List<int> _runes;
  @override
  void initState() {
    super.initState();
    _runes = widget.message.runes.toList();
    _typing = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _runes.length * 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _typing.value = 1;
    } else if (_typing.value == 0) {
      _typing.forward();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.message,
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: () => _typing.value = 1,
        child: AnimatedBuilder(
          animation: _typing,
          builder: (_, __) => Text(
            String.fromCharCodes(
              _runes.take((_runes.length * _typing.value).ceil()),
            ),
            style: const TextStyle(fontSize: 13, height: 1.75),
          ),
        ),
      ),
    ),
  );
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _BubblePainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 18),
      child: child,
    ),
  );
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, math.max(1, size.height - 18)),
      const Radius.circular(18),
    );
    final outline = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      Path()..addPolygon([
        Offset(size.width * .5 - 12, size.height - 19),
        Offset(size.width * .5, size.height - 1),
        Offset(size.width * .5 + 12, size.height - 19),
      ], true),
    );
    canvas.drawShadow(outline, Colors.black87, 8, false);
    canvas.drawPath(outline, Paint()..color = const Color(0xFFFFFDF8));
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFF263754)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.target);
  final Rect? target;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    final hole = target == null
        ? null
        : RRect.fromRectAndRadius(target!, const Radius.circular(14));
    if (hole != null) path.addRRect(hole);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .66));
    if (hole != null) {
      canvas.drawRRect(
        hole,
        Paint()
          ..color = const Color(0xFFFFD761)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      target != oldDelegate.target;
}
