import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import 'home_guide_tour_overlay.dart';

/// Exposes a page's real targets to the one, pre-sign-in onboarding overlay.
class GuidePageController {
  final _ready = Completer<void>();
  List<GuideStep> _steps = const [];
  bool _disposed = false;

  Future<void> get ready => _ready.future;
  List<GuideStep> get steps => _steps;

  void _attach(List<GuideStep> steps) {
    if (_disposed || _ready.isCompleted) return;
    _steps = List.unmodifiable(steps);
    _ready.complete();
  }

  void dispose() => _disposed = true;
}

/// Each page introduces its own controls once and keeps a replay button nearby.
class PageGuide extends StatefulWidget {
  const PageGuide({
    super.key,
    required this.id,
    required this.steps,
    required this.child,
    this.enabled = true,
    this.onStart,
    this.onFinish,
    this.completionLabel = 'ابدأ الاستكشاف',
    this.controller,
    this.autoStart = true,
  });

  final String id, completionLabel;
  final List<GuideStep> steps;
  final Widget child;
  final bool enabled;
  final bool autoStart;
  final GuidePageController? controller;
  final VoidCallback? onStart, onFinish;

  static String preferenceKey(String id) => 'has_completed_page_guide_${id}_v1';

  @override
  State<PageGuide> createState() => PageGuideState();
}

class PageGuideState extends State<PageGuide> {
  bool _showing = false, _checked = false, _checking = false;
  bool _attached = false;
  List<GuideStep> _activeSteps = const [];
  bool get isShowing => _showing || widget.controller != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachController();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant PageGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachController();
    if (widget.enabled && !oldWidget.enabled) _scheduleCheck();
  }

  void _attachController() {
    if (widget.controller == null || _attached) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _attached || widget.controller == null) return;
      _attached = true;
      widget.onStart?.call();
      widget.controller!._attach(widget.steps);
    });
  }

  void _scheduleCheck() {
    if (widget.controller != null ||
        !widget.autoStart ||
        !widget.enabled ||
        _checked ||
        _checking) {
      return;
    }
    try {
      final appState = context.read<AppState>();
      if (appState.user != null) {
        _checked = true;
        return;
      }
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstVisit());
  }

  Future<void> _checkFirstVisit() async {
    if (!mounted ||
        widget.controller != null ||
        !widget.autoStart ||
        _checked ||
        _checking ||
        !widget.enabled) {
      return;
    }
    try {
      final appState = context.read<AppState>();
      if (appState.user != null) {
        _checked = true;
        return;
      }
    } catch (_) {}
    if (ModalRoute.of(context)?.isCurrent == false || !TickerMode.of(context)) {
      return;
    }
    _checking = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || !widget.enabled || _checked) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _checked = true;
      if (!(preferences.getBool(PageGuide.preferenceKey(widget.id)) ?? false)) {
        start();
      }
    } catch (_) {
      // Manual help remains available if local preferences cannot be read.
      _checked = true;
    } finally {
      _checking = false;
    }
  }

  void start() {
    if (!mounted ||
        widget.controller != null ||
        !widget.enabled ||
        _showing ||
        widget.steps.isEmpty) {
      return;
    }
    _checked = true;
    _activeSteps = List.of(widget.steps);
    widget.onStart?.call();
    setState(() => _showing = true);
  }

  void _finish() {
    if (!_showing) return;
    setState(() => _showing = false);
    widget.onFinish?.call();
    unawaited(_remember());
  }

  Future<void> _remember() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(PageGuide.preferenceKey(widget.id), true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        if (_showing)
          Positioned.fill(
            child: HomeGuideTourOverlay(
              key: ValueKey('page-guide-${widget.id}'),
              steps: _activeSteps,
              showFinalChoices: false,
              completionLabel: widget.completionLabel,
              onComplete: _finish,
              onSkip: _finish,
            ),
          ),
      ]);
}

class PageGuideHelpButton extends StatelessWidget {
  const PageGuideHelpButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: 'شرح الصفحة',
          onPressed: onPressed,
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFFFDE83),
            backgroundColor: const Color(0xED16213C),
            side: const BorderSide(color: Color(0x887FA3CB)),
          ),
          icon: const Icon(Icons.help_outline_rounded, size: 23),
        ),
      );
}

/// Scroll before speaking, so the spotlight never points at an offscreen item.
Future<void> revealGuideTarget(GlobalKey key, {double alignment = .4}) async {
  await WidgetsBinding.instance.endOfFrame;
  final context = key.currentContext;
  if (context == null || !context.mounted) return;
  await Scrollable.ensureVisible(context,
      alignment: alignment, duration: Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
}
