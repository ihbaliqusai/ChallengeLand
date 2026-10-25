import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_state.dart';
import '../../screens/auth/first_run_challenge_screen.dart';
import 'guide_presenter_scene.dart';

class GuideStep {
  const GuideStep(
      {required this.title,
      required this.text,
      this.chapter = 'اكتشف الساحة',
      this.targetKey,
      this.onEnter,
      this.pageLayout = false,
      this.isFinalChoiceStep = false});
  final String title, text, chapter;
  final GlobalKey? targetKey;
  final Future<void> Function()? onEnter;
  final bool isFinalChoiceStep;
  final bool pageLayout;
}

/// Geometry stays in the overlay's coordinates, including scaled artwork.
class GuideTourPlacement {
  const GuideTourPlacement._();
  static Rect panelFor(Rect bounds, Rect? target,
      {double unit = 1, bool finalStep = false, bool allowShortPanel = false}) {
    final gap = 24 * unit;
    final maxHeight = (finalStep ? 680.0 : 510.0) * unit;
    final compact = bounds.height / unit < 430 && bounds.width > bounds.height;
    final maxWidth = (finalStep
            ? 760.0
            : compact
                ? 520.0
                : 360.0) *
        unit;
    final candidates = target == null
        ? [bounds]
        : [
            Rect.fromLTRB(bounds.left, bounds.top,
                math.max(bounds.left, target.left - gap), bounds.bottom),
            Rect.fromLTRB(math.min(bounds.right, target.right + gap),
                bounds.top, bounds.right, bounds.bottom),
            Rect.fromLTRB(bounds.left, bounds.top, bounds.right,
                math.max(bounds.top, target.top - gap)),
            Rect.fromLTRB(
                bounds.left,
                math.min(bounds.bottom, target.bottom + gap),
                bounds.right,
                bounds.bottom),
          ];
    final minimumHeight =
        allowShortPanel && bounds.width > bounds.height ? 200.0 : 300.0;
    double score(Rect r) =>
        r.width < 250 * unit || r.height < minimumHeight * unit
            ? 0
            : math.min(r.width, maxWidth) * math.min(r.height, maxHeight);
    final region = candidates.reduce((a, b) => score(b) > score(a) ? b : a);
    final usable = score(region) > 0 ? region : bounds;
    return Rect.fromCenter(
        center: usable.center,
        width: math.min(maxWidth, usable.width),
        height: math.min(maxHeight, usable.height));
  }
}

class SpotlightPainter extends CustomPainter {
  const SpotlightPainter(
      {required this.targetRect,
      this.panelRect,
      this.borderRadius = 18,
      this.overlayColor = const Color(0xD9081020),
      this.glowColor = const Color(0xFFFFD878),
      this.animationValue = 1});
  final Rect? targetRect, panelRect;
  final double borderRadius, animationValue;
  final Color overlayColor, glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Path()..addRect(Offset.zero & size);
    final target = targetRect;
    if (target == null) {
      canvas.drawPath(background, Paint()..color = overlayColor);
      return;
    }
    final hole = RRect.fromRectAndRadius(target.inflate(7),
        Radius.circular(math.min(borderRadius, target.height / 2 + 7)));
    canvas.drawPath(
        Path.combine(
            PathOperation.difference, background, Path()..addRRect(hole)),
        Paint()..color = overlayColor);
    canvas.drawRRect(
        hole,
        Paint()
          ..color = glowColor.withValues(alpha: .30 + animationValue * .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawRRect(
        hole,
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + animationValue);
    final panel = panelRect;
    if (panel == null || panel.overlaps(target.inflate(12))) return;
    Offset edge(Rect rect, Offset toward) {
      final delta = toward - rect.center;
      final ratio = math.min(
          delta.dx == 0 ? double.infinity : rect.width / 2 / delta.dx.abs(),
          delta.dy == 0 ? double.infinity : rect.height / 2 / delta.dy.abs());
      return rect.center + delta * ratio;
    }

    final start = edge(panel, target.center);
    final end = edge(target.inflate(12), panel.center);
    canvas.drawLine(
        start,
        end,
        Paint()
          ..color = glowColor.withValues(alpha: .65)
          ..strokeWidth = 1.5);
    canvas.drawCircle(end, 4, Paint()..color = glowColor);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter old) =>
      old.targetRect != targetRect ||
      old.panelRect != panelRect ||
      old.animationValue != animationValue ||
      old.overlayColor != overlayColor ||
      old.glowColor != glowColor ||
      old.borderRadius != borderRadius;
}

class HomeGuideTourOverlay extends StatefulWidget {
  const HomeGuideTourOverlay(
      {super.key,
      required this.steps,
      required this.onComplete,
      this.onSkip,
      this.showFinalChoices = true,
      this.completionLabel = 'استكشف الساحة'})
      : assert(steps.length > 0);
  final List<GuideStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final bool showFinalChoices;
  final String completionLabel;
  @override
  State<HomeGuideTourOverlay> createState() => _HomeGuideTourOverlayState();
}

class _HomeGuideTourOverlayState extends State<HomeGuideTourOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _surfaceKey = GlobalKey();
  final _speech = GuideSpeechController();
  late final AnimationController _pulse;
  int _index = 0;
  Rect? _target;
  bool _measurementPending = false, _signingIn = false, _finished = false;
  bool _preparing = false;
  bool get _busy => _signingIn || _preparing;
  String? _signInError;
  GuideStep get _step => widget.steps[_index];
  bool get _usePageLayout => _step.pageLayout || !widget.showFinalChoices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_scheduleMeasurement);
    _scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant HomeGuideTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _index = math.min(_index, widget.steps.length - 1);
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() => _scheduleMeasurement();

  void _scheduleMeasurement() {
    if (_measurementPending) return;
    _measurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementPending = false;
      if (!mounted) return;
      final measured = _readTargetRect();
      if (measured != _target) setState(() => _target = measured);
    });
  }

  Rect? _readTargetRect() {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    final object = _step.targetKey?.currentContext?.findRenderObject();
    Rect? measured;
    if (surface is RenderBox &&
        surface.hasSize &&
        object is RenderBox &&
        object.attached &&
        object.hasSize &&
        !object.size.isEmpty) {
      final rect = MatrixUtils.transformRect(
          object.getTransformTo(surface), Offset.zero & object.size);
      final visible = rect.intersect(Offset.zero & surface.size);
      if (visible.isFinite && !visible.isEmpty) measured = visible;
    }
    return measured;
  }

  Future<void> _move(int offset) async {
    if (_busy || _finished) return;
    final next = _index + offset;
    if (next < 0 || next >= widget.steps.length) return;
    final prepare = widget.steps[next].onEnter;
    if (prepare != null) {
      setState(() {
        _preparing = true;
        _target = null;
      });
      try {
        await prepare();
      } catch (_) {
        // The explanation still works when its optional control is unavailable.
      }
      if (!mounted) return;
      _preparing = false;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _index = next;
      _target = _readTargetRect();
      _signInError = null;
    });
    _scheduleMeasurement();
  }

  void _finish({bool skipped = false}) {
    if (_finished || _busy) return;
    _finished = true;
    HapticFeedback.lightImpact();
    (skipped ? widget.onSkip ?? widget.onComplete : widget.onComplete)();
  }

  void _demo() {
    final navigator = Navigator.of(context);
    _finish();
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const FirstRunChallengeScreen()));
  }

  Future<void> _signIn() async {
    if (_signingIn) return;
    final app = context.read<AppState>();
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await app.signInWithGoogle();
      if (!mounted) return;
      setState(() => _signingIn = false);
      // Cancelling the account picker must leave the tour open.
      if (app.user != null) {
        _finish();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _signingIn = false;
          _signInError =
              error is FirebaseAuthException && error.code == 'cancelled'
                  ? null
                  : 'تعذّر تسجيل الدخول. حاول مجددًا أو تابع استكشاف الساحة.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _speech.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalStep =
        _index == widget.steps.length - 1 || _step.isFinalChoiceStep;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                if (_index > 0) {
                  _move(-1);
                } else {
                  _finish(skipped: true);
                }
              }
            },
            child: BlockSemantics(
                child: Material(
                    key: _surfaceKey,
                    color: Colors.transparent,
                    child: LayoutBuilder(builder: (context, area) {
                      final padding = MediaQuery.paddingOf(context);
                      final unit = (View.of(context).devicePixelRatio /
                              MediaQuery.devicePixelRatioOf(context))
                          .clamp(1.0, 3.0);
                      final bounds = Rect.fromLTRB(
                          padding.left + 12 * unit,
                          12 * unit,
                          area.maxWidth - padding.right - 12 * unit,
                          area.maxHeight - 12 * unit);
                      final stage = GuideTourPlacement.panelFor(bounds, _target,
                          unit: unit,
                          allowShortPanel: _usePageLayout,
                          finalStep: finalStep && widget.showFinalChoices);
                      return Stack(children: [
                        Positioned.fill(
                            child: AnimatedBuilder(
                                animation: _pulse,
                                builder: (_, __) => CustomPaint(
                                    key: const ValueKey('guide-spotlight'),
                                    painter: SpotlightPainter(
                                        targetRect: _target,
                                        panelRect: stage,
                                        animationValue: _pulse.value)))),
                        Positioned.fill(
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {})),
                        if (_target != null && !finalStep)
                          Positioned.fromRect(
                              rect: _target!,
                              child: Semantics(
                                  button: true,
                                  label: 'متابعة شرح ${_step.title}',
                                  child: GestureDetector(
                                      key:
                                          const ValueKey('guide-target-action'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _move(1)))),
                        Positioned.fromRect(
                            rect: stage,
                            child: SizedBox(
                                key: const ValueKey('guide-stage'),
                                child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: SizedBox(
                                        width: stage.width / unit,
                                        height: stage.height / unit,
                                        child: _buildStage(
                                            stage.size / unit,
                                            finalStep,
                                            _target != null &&
                                                _target!.center.dx >
                                                    stage.center.dx))))),
                      ]);
                    })))));
  }

  Widget _buildStage(Size size, bool finalStep, bool flipped) {
    final showChoices = finalStep && widget.showFinalChoices;
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final compact = landscape && size.height < 430;
    final sideBySide = showChoices && size.width >= 620;
    final controlsWidth = compact
        ? (showChoices
            ? math.min(300.0, size.width * .42)
            : !_usePageLayout
                ? math.min(112.0, size.width * .30)
                : 112.0)
        : 0.0;
    final sceneWidth = compact
        ? size.width - controlsWidth - 12
        : sideBySide
            ? 340.0
            : size.width;
    const navigationHeight = 76.0;
    final choicesHeight = showChoices && !sideBySide && !compact
        ? (_signInError == null ? 108.0 : 142.0)
        : 0.0;
    final available =
        compact ? size.height : size.height - navigationHeight - choicesHeight;
    final bubbleHeight = math.max(
        compact ? 88.0 : 126.0,
        GuidePresenterScene.bubbleHeightFor(_step.title, _step.text, sceneWidth,
            showTitle: false));
    final hostHeight = math.min(math.min(210.0, sceneWidth * 141 / 208),
        math.max(1.0, (available - bubbleHeight - 6) / (1 + 64 / 141)));
    final scene = GuidePresenterScene(
        title: _step.title,
        text: _step.text,
        width: sceneWidth,
        presenterHeight: hostHeight,
        bubbleHeight: bubbleHeight,
        flipped: flipped,
        showTitle: false,
        controller: _speech);
    if (compact) {
      return Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            scene,
            const SizedBox(width: 12),
            SizedBox(
                width: controlsWidth,
                child: showChoices
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        _buildFinalChoices(),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: navigationHeight,
                            child: _buildNavigation(true)),
                      ])
                    : !_usePageLayout
                        ? _buildCompactNavigation(finalStep)
                        : _buildPageCompactNavigation(finalStep))
          ]);
    }
    return Column(children: [
      Expanded(
          child: sideBySide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                      scene,
                      const SizedBox(width: 16),
                      Expanded(child: _buildFinalChoices()),
                    ])
              : Align(alignment: Alignment.center, child: scene)),
      if (showChoices && !sideBySide)
        SizedBox(height: choicesHeight, child: _buildFinalChoices()),
      SizedBox(height: navigationHeight, child: _buildNavigation(finalStep)),
    ]);
  }

  Widget _buildPageCompactNavigation(bool finalStep) => Container(
      key: const ValueKey('guide-navigation'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xF00D1B31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x887FA3CB))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
              child: Text('${_index + 1} من ${widget.steps.length}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFFFFD878), fontSize: 10))),
          SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                  tooltip: 'تخطي الجولة',
                  onPressed: _busy ? null : () => _finish(skipped: true),
                  color: Colors.white70,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded))),
        ]),
        Text(_step.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Colors.white,
                fontSize: 10,
                height: 1.4)),
        const SizedBox(height: 6),
        SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
                onPressed: _busy
                    ? null
                    : finalStep
                        ? _finish
                        : () => _move(1),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: const Color(0xFFFFD878),
                    foregroundColor: const Color(0xFF142139)),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                        finalStep
                            ? widget.completionLabel
                            : _index == 0
                                ? 'ابدأ الجولة'
                                : 'التالي',
                        style: const TextStyle(
                            fontFamily: 'NotoSansArabic', fontSize: 13))))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                  tooltip: 'السابق',
                  onPressed: _index == 0 || _busy ? null : () => _move(-1),
                  color: Colors.white70,
                  iconSize: 20,
                  icon: const Icon(Icons.arrow_forward_rounded))),
          SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                  tooltip: 'إعادة الشرح',
                  onPressed: _busy ? null : _speech.replay,
                  color: Colors.white,
                  iconSize: 20,
                  icon: const Icon(Icons.replay_rounded))),
        ]),
      ]));

  Widget _buildCompactNavigation(bool finalStep) => Container(
      key: const ValueKey('guide-navigation'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xF00D1B31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x887FA3CB))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Colors.white,
                fontSize: 11,
                height: 1.5)),
        const SizedBox(height: 4),
        Text('${_index + 1} من ${widget.steps.length}',
            style: const TextStyle(color: Color(0xFFFFD878), fontSize: 10)),
        const SizedBox(height: 8),
        SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
                onPressed: _busy
                    ? null
                    : finalStep
                        ? _finish
                        : () => _move(1),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: const Color(0xFFFFD878),
                    foregroundColor: const Color(0xFF142139)),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                        finalStep
                            ? widget.completionLabel
                            : _index == 0
                                ? 'ابدأ الجولة'
                                : 'التالي',
                        style: const TextStyle(
                            fontFamily: 'NotoSansArabic', fontSize: 14))))),
        SizedBox(
            height: 48,
            width: double.infinity,
            child: TextButton(
                onPressed: _index == 0 || _busy ? null : () => _move(-1),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('السابق',
                    style: TextStyle(
                        fontFamily: 'NotoSansArabic', fontSize: 13)))),
        IconButton(
            tooltip: 'إعادة الشرح',
            onPressed: _busy ? null : _speech.replay,
            color: Colors.white,
            icon: const Icon(Icons.replay_rounded)),
        IconButton(
            tooltip: 'تخطي الجولة',
            onPressed: _busy ? null : () => _finish(skipped: true),
            color: Colors.white54,
            icon: const Icon(Icons.close_rounded)),
      ]));

  Widget _buildFinalChoices() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
                onPressed: _busy ? null : _demo,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF137B61),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('جرّب التحدي مجانًا')),
            const SizedBox(height: 6),
            OutlinedButton.icon(
                onPressed: _busy ? null : _signIn,
                style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xF0122138),
                    foregroundColor: Colors.white),
                icon: _signingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login_rounded),
                label: const Text('المتابعة بحساب Google')),
            if (_signInError != null)
              Text(_signInError!,
                  style:
                      const TextStyle(color: Color(0xFFFFB8B8), fontSize: 11)),
          ]);

  Widget _buildNavigation(bool finalStep) => Container(
      key: const ValueKey('guide-navigation'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xF00D1B31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x887FA3CB))),
      child: Column(children: [
        SizedBox(
            height: 14,
            child: Row(children: [
              Text('${_index + 1} من ${widget.steps.length}',
                  style: const TextStyle(
                      color: Color(0xFFFFD878), fontSize: 10, height: 1)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_step.title,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1))),
            ])),
        Expanded(
            child: Row(key: const ValueKey('guide-navigation-row'), children: [
          SizedBox(
              width: 64,
              height: 48,
              child: TextButton(
                  onPressed: _index == 0 || _busy ? null : () => _move(-1),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('السابق',
                          style: TextStyle(
                              fontFamily: 'NotoSansArabic', fontSize: 13))))),
          Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                    tooltip: 'إعادة الشرح',
                    onPressed: _busy ? null : _speech.replay,
                    color: Colors.white,
                    icon: const Icon(Icons.replay_rounded, size: 19))),
            SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                    tooltip: 'تخطي الجولة',
                    onPressed: _busy ? null : () => _finish(skipped: true),
                    color: Colors.white54,
                    icon: const Icon(Icons.close_rounded, size: 19))),
            const SizedBox(width: 4),
            Flexible(
                child: SizedBox(
                    width: finalStep ? 148 : 128,
                    height: 48,
                    child: FilledButton(
                        onPressed: _busy
                            ? null
                            : finalStep
                                ? _finish
                                : () => _move(1),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD878),
                            foregroundColor: const Color(0xFF142139),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                                finalStep
                                    ? widget.completionLabel
                                    : _index == 0
                                        ? 'ابدأ الجولة'
                                        : 'التالي',
                                style: const TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    fontSize: 14)))))),
          ])),
        ])),
      ]));
}
