import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gameplay_presenter.dart';
import 'host_podium_plate.dart';

/// Explicit replay/reveal commands; the scene owns and cancels speech timers.
class GuideSpeechController extends ChangeNotifier {
  bool _replay = false;
  void replay() {
    _replay = true;
    notifyListeners();
  }

  void reveal() {
    _replay = false;
    notifyListeners();
  }
}

/// The gameplay composition: callout above the head, full torso, podium below.
/// Speech types at 18 ms/character and stays visible until the step changes.
class GuidePresenterScene extends StatefulWidget {
  const GuidePresenterScene(
      {super.key,
      required this.title,
      required this.text,
      required this.width,
      required this.presenterHeight,
      required this.bubbleHeight,
      this.flipped = true,
      this.showTitle = true,
      this.controller,
      this.onSpeakingChanged});

  final String title, text;
  final double width, presenterHeight, bubbleHeight;
  final bool flipped, showTitle;
  final GuideSpeechController? controller;
  final ValueChanged<bool>? onSpeakingChanged;

  static const characterDelay = Duration(milliseconds: 18);

  static double bubbleHeightFor(String title, String text, double width,
      {bool showTitle = true}) {
    double measure(String value, TextStyle style) {
      final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: TextDirection.rtl)
        ..layout(maxWidth: width - 32);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    return ((showTitle ? measure(title, _titleStyle) + 6 : 0) +
            measure(text, _textStyle) +
            34)
        .clamp(88.0, 168.0);
  }

  static const _titleStyle = TextStyle(
      fontFamily: 'NotoSansArabic',
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w800,
      color: Color(0xFF263754));
  static const _textStyle = TextStyle(
      fontFamily: 'NotoSansArabic',
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w600,
      color: Color(0xFF17233B));

  @override
  State<GuidePresenterScene> createState() => _GuidePresenterSceneState();
}

class _GuidePresenterSceneState extends State<GuidePresenterScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _bubble;
  Timer? _typing, _transition;
  String _text = '', _title = '';
  List<String> _characters = const [];
  int _shown = 0;
  bool _speaking = false, _paused = false;
  bool _routeActive = true, _appActive = true;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bubble = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _paused = !_appActive;
    widget.controller?.addListener(_command);
    _beginLine();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion && _shown < _characters.length) _reveal();
    _routeActive = TickerMode.of(context);
    _syncPause();
  }

  @override
  void didUpdateWidget(covariant GuidePresenterScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_command);
      widget.controller?.addListener(_command);
    }
    if (oldWidget.text != widget.text || oldWidget.title != widget.title) {
      _cancelTimers();
      _setSpeaking(false);
      if (_reducedMotion) {
        _beginLine();
      } else {
        _bubble.reverse();
        _transition = Timer(const Duration(milliseconds: 160), _beginLine);
      }
    }
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    widget.onSpeakingChanged?.call(value);
  }

  void _cancelTimers() {
    _typing?.cancel();
    _transition?.cancel();
  }

  void _beginLine() {
    if (!mounted) return;
    _cancelTimers();
    _text = widget.text;
    _title = widget.title;
    _characters = _text.characters.toList();
    _shown = _reducedMotion ? _characters.length : 0;
    _setSpeaking(!_reducedMotion && _characters.isNotEmpty && !_paused);
    if (_reducedMotion) {
      _bubble.value = 1;
    } else {
      _bubble.forward(from: 0);
    }
    if (_shown < _characters.length) {
      _startTyping();
    }
    setState(() {});
  }

  void _startTyping() {
    if (_paused) return;
    _typing?.cancel();
    _typing = Timer.periodic(GuidePresenterScene.characterDelay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _shown = math.min(_shown + 1, _characters.length);
        if (_shown == _characters.length) {
          timer.cancel();
          _setSpeaking(false);
        }
      });
    });
  }

  void _reveal() {
    _typing?.cancel();
    setState(() {
      _shown = _characters.length;
      _setSpeaking(false);
    });
  }

  void _command() {
    if (widget.controller!._replay) {
      _beginLine();
    } else {
      _reveal();
    }
  }

  void _pause() {
    _paused = true;
    _typing?.cancel();
    _setSpeaking(false);
  }

  void _syncPause() {
    final shouldPause = !_routeActive || !_appActive;
    if (shouldPause == _paused) return;
    shouldPause ? _pause() : _resume();
  }

  void _resume() {
    _paused = false;
    if (_shown < _characters.length) {
      _setSpeaking(!_reducedMotion);
      _startTyping();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncPause();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelTimers();
    widget.controller?.removeListener(_command);
    WidgetsBinding.instance.removeObserver(this);
    _bubble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostHeight = widget.presenterHeight;
    final hostWidth = hostHeight * 208 / 141;
    final hostLeft = (widget.width - hostWidth) / 2;
    final headX = hostLeft + hostWidth * (widget.flipped ? 89.8 : 118.2) / 208;
    final hostTop = widget.bubbleHeight + 12;
    final plateWidth = hostHeight * 152 / 141;
    final height = hostTop +
        hostHeight -
        6 +
        plateWidth / HostPodiumPlate.nativeAspectRatio;
    final shown = _characters.take(_shown).join();
    final remaining = _characters.skip(_shown).join();
    return SizedBox(
        key: const ValueKey('guide-presenter-scene'),
        width: widget.width,
        height: height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
              left: hostLeft,
              top: hostTop,
              width: hostWidth,
              height: hostHeight,
              child: ExcludeSemantics(
                  child: SizedBox(
                      key: const ValueKey('guide-presenter'),
                      child: GameplayPresenter(
                          height: hostHeight,
                          isTalking: _speaking,
                          isFlipped: widget.flipped,
                          gesture: PresenterGesture.showHand,
                          enableBlinking: !_reducedMotion && !_paused,
                          enableEyebrows: !_reducedMotion && !_paused,
                          enableBreathing: !_reducedMotion && !_paused)))),
          Positioned(
              top: hostTop + hostHeight - 6,
              left: headX - plateWidth / 2,
              child: HostPodiumPlate(
                  key: const ValueKey('guide-podium'), width: plateWidth)),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.bubbleHeight + 12,
              child: FadeTransition(
                  key: const ValueKey('guide-speech-visibility'),
                  opacity: _bubble,
                  child: Semantics(
                      liveRegion: true,
                      label: '$_title. $_text',
                      excludeSemantics: true,
                      child: GestureDetector(
                          key: const ValueKey('guide-speech-bubble'),
                          onTap: _reveal,
                          child: CustomPaint(
                              key: const ValueKey('guide-dialogue-panel'),
                              painter: _GameplayBubblePainter(tailX: headX),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 10, 16, 24),
                                  child: Column(children: [
                                    if (widget.showTitle) ...[
                                      Text(_title,
                                          textAlign: TextAlign.center,
                                          style:
                                              GuidePresenterScene._titleStyle),
                                      const SizedBox(height: 6),
                                    ],
                                    Expanded(
                                        child: SingleChildScrollView(
                                            key: ValueKey(_text),
                                            child: Text.rich(
                                                TextSpan(children: [
                                                  TextSpan(text: shown),
                                                  TextSpan(
                                                      text: remaining,
                                                      style: const TextStyle(
                                                          color: Colors
                                                              .transparent))
                                                ]),
                                                key: const ValueKey(
                                                    'guide-spoken-text'),
                                                textAlign: TextAlign.center,
                                                style: GuidePresenterScene
                                                    ._textStyle))),
                                  ]))))))),
        ]));
  }
}

class _GameplayBubblePainter extends CustomPainter {
  const _GameplayBubblePainter({required this.tailX});
  final double tailX;
  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 12;
    final x = tailX.clamp(18.0, size.width - 18);
    final path = Path()
      ..moveTo(11, 1)
      ..lineTo(size.width - 11, 1)
      ..quadraticBezierTo(size.width - 1, 1, size.width - 1, 11)
      ..lineTo(size.width - 1, bottom - 10)
      ..quadraticBezierTo(size.width - 1, bottom, size.width - 11, bottom)
      ..lineTo(x + 8, bottom)
      ..lineTo(x, size.height - 1)
      ..lineTo(x - 8, bottom)
      ..lineTo(11, bottom)
      ..quadraticBezierTo(1, bottom, 1, bottom - 10)
      ..lineTo(1, 11)
      ..quadraticBezierTo(1, 1, 11, 1)
      ..close();
    canvas.drawShadow(path, Colors.black54, 5, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFDF8));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF263754)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _GameplayBubblePainter old) =>
      old.tailX != tailX;
}
