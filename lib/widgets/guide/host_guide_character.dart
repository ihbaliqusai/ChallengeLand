import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gameplay_presenter.dart';
import 'host_podium_plate.dart';

export 'gameplay_presenter.dart';
export 'host_podium_plate.dart';

/// Painter for the speech bubble tail that points downwards towards the host's head.
class SpeechBubbleTailPainter extends CustomPainter {
  const SpeechBubbleTailPainter({
    required this.fillColor,
    this.borderColor = const Color(0xFFFACC15),
    this.borderWidth = 1.6,
  });

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final borderPath = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);

      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpeechBubbleTailPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// The Presenter / Host Character with speech bubble directly above his head.
/// Accurately matches the native gameplay host (`Person.java`) with full lip-sync mouth,
/// body hand gestures, blinking eyes, eyebrows, breathing physics, and the iconic podium plate.
class HostGuideBubble extends StatefulWidget {
  const HostGuideBubble({
    super.key,
    required this.text,
    this.title,
    this.actions,
    this.hostHeight = 160,
    this.bubbleWidth = 320,
    this.showHost = true,
    this.showPodium = true,
    this.podiumText = 'أرض التحدي',
    this.hostFlipped = true,
    this.isTalking = true,
    this.gesture = PresenterGesture.showHand,
    this.enableBlinking = true,
    this.enableEyebrows = true,
    this.enableBreathing = true,
    this.enableTypewriter = true,
    this.controller,
    this.bubbleColor = Colors.white,
    this.textColor = const Color(0xFF0F172A),
    this.borderColor = const Color(0xFFFACC15),
  });

  final String text;
  final String? title;
  final Widget? actions;
  final double hostHeight;
  final double bubbleWidth;
  final bool showHost;
  final bool showPodium;
  final String? podiumText;
  final bool hostFlipped;
  final bool isTalking;
  final PresenterGesture gesture;
  final bool enableBlinking;
  final bool enableEyebrows;
  final bool enableBreathing;
  final bool enableTypewriter;
  final GameplayPresenterController? controller;
  final Color bubbleColor;
  final Color textColor;
  final Color borderColor;

  @override
  State<HostGuideBubble> createState() => _HostGuideBubbleState();
}

class _HostGuideBubbleState extends State<HostGuideBubble> {
  int _displayedChars = 0;
  bool _isSpeaking = false;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _startSpeakingSequence();
  }

  @override
  void didUpdateWidget(covariant HostGuideBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startSpeakingSequence();
    } else if (oldWidget.isTalking != widget.isTalking &&
        !widget.enableTypewriter) {
      _isSpeaking = widget.isTalking;
    }
  }

  void _startSpeakingSequence() {
    _typewriterTimer?.cancel();

    if (!widget.enableTypewriter) {
      _displayedChars = widget.text.characters.length;
      _isSpeaking = widget.isTalking;
      if (mounted) setState(() {});
      return;
    }

    // Reset typewriter state
    _displayedChars = 0;
    _isSpeaking = true;
    if (mounted) setState(() {});

    final total = widget.text.characters.length;
    if (total == 0) {
      _isSpeaking = false;
      return;
    }

    // Match the native presenter's 18ms character delay.
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_displayedChars < total) {
        setState(() {
          _displayedChars++;
        });
      } else {
        timer.cancel();
        // SPEECH FINISHED: STOP MOVING MOUTH IMMEDIATELY!
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  void _skipTypewriter() {
    if (!_isSpeaking) return;
    _typewriterTimer?.cancel();
    setState(() {
      _displayedChars = widget.text.characters.length;
      _isSpeaking = false; // Stop talking immediately
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentText = widget.enableTypewriter
        ? widget.text.characters.take(_displayedChars).toString()
        : widget.text;
    final remainingText = widget.enableTypewriter
        ? widget.text.characters.skip(_displayedChars).toString()
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Speech Bubble Box
        GestureDetector(
          onTap: _skipTypewriter,
          child: Container(
            width: widget.bubbleWidth,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: widget.bubbleColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.borderColor.withValues(alpha: 0.65),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: widget.borderColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.title != null &&
                    widget.title!.trim().isNotEmpty) ...[
                  Text(
                    widget.title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B4B),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: currentText),
                    if (remainingText.isNotEmpty)
                      TextSpan(
                        text: remainingText,
                        style: const TextStyle(color: Colors.transparent),
                      ),
                  ]),
                  semanticsLabel: widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.38,
                    color: widget.textColor,
                  ),
                ),
                if (widget.actions != null) ...[
                  const SizedBox(height: 12),
                  widget.actions!,
                ],
              ],
            ),
          ),
        ),

        // Downward Triangle Tail pointing right to the host's head
        CustomPaint(
          size: const Size(22, 12),
          painter: SpeechBubbleTailPainter(
            fillColor: widget.bubbleColor,
            borderColor: widget.borderColor.withValues(alpha: 0.65),
            borderWidth: 1.8,
          ),
        ),

        // Animated Gameplay Host Presenter with Podium Nameplate
        if (widget.showHost) ...[
          const SizedBox(height: 2),
          SizedBox(
              width: widget.hostHeight * 208 / 141,
              height: widget.hostHeight +
                  (widget.showPodium ? widget.hostHeight * 64 / 141 - 6 : 0),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                    left: 0,
                    top: 0,
                    child: GameplayPresenter(
                        height: widget.hostHeight,
                        isTalking: _isSpeaking,
                        gesture: widget.gesture,
                        isFlipped: widget.hostFlipped,
                        enableBlinking: widget.enableBlinking,
                        enableEyebrows: widget.enableEyebrows,
                        enableBreathing: widget.enableBreathing,
                        controller: widget.controller)),
                if (widget.showPodium)
                  Positioned(
                      top: widget.hostHeight - 6,
                      left: widget.hostHeight *
                          ((widget.hostFlipped ? 89.8 : 118.2) - 76) /
                          141,
                      child: HostPodiumPlate(
                          width: widget.hostHeight * 152 / 141,
                          title: widget.podiumText ?? 'أرض التحدي')),
              ])),
        ],
      ],
    );
  }
}

/// Animated pointing finger / hand that bounces towards the target element.
class PointingHandWidget extends StatefulWidget {
  const PointingHandWidget({
    super.key,
    this.direction = AxisDirection.right,
    this.size = 54,
  });

  final AxisDirection direction;
  final double size;

  @override
  State<PointingHandWidget> createState() => _PointingHandWidgetState();
}

class _PointingHandWidgetState extends State<PointingHandWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final bounce = math.sin(_animCtrl.value * math.pi) * 12.0;
        Offset translation;
        double angle = 0;

        switch (widget.direction) {
          case AxisDirection.right:
            translation = Offset(bounce, 0);
            angle = math.pi / 2; // pointing right
            break;
          case AxisDirection.left:
            translation = Offset(-bounce, 0);
            angle = -math.pi / 2; // pointing left
            break;
          case AxisDirection.up:
            translation = Offset(0, -bounce);
            angle = 0; // pointing up
            break;
          case AxisDirection.down:
            translation = Offset(0, bounce);
            angle = math.pi; // pointing down
            break;
        }

        return Transform.translate(
          offset: translation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow aura around pointer tip
              Container(
                width: widget.size * 0.9,
                height: widget.size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15)
                          .withValues(alpha: 0.35 + _animCtrl.value * 0.4),
                      blurRadius: 18 + _animCtrl.value * 10,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // Animated Hand Icon
              Transform.rotate(
                angle: angle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFACC15),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.pan_tool_alt_rounded,
                    size: widget.size * 0.65,
                    color: const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
