import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_colors.dart';
import 'sound_service.dart';

enum AnswerFeedbackType { correct, wrong, skip }

class AnimatedTimerCircle extends StatelessWidget {
  const AnimatedTimerCircle({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 92,
    this.strokeWidth = 8,
    this.child,
  });

  final Duration remaining;
  final Duration total;
  final double size;
  final double strokeWidth;
  final Widget? child;

  double get _progress {
    if (total.inMilliseconds <= 0) return 0;
    return (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  Color get _color {
    if (_progress <= 0.2) return AppColors.challengeRed;
    if (_progress <= 0.5) return AppColors.challengeGold;
    return AppColors.challengeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final shouldShake = remaining.inSeconds <= 5 && remaining.inSeconds > 0;
    final timer = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TimerArcPainter(
          progress: _progress,
          color: _color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child:
              child ??
              Text(
                '${remaining.inSeconds.clamp(0, total.inSeconds)}',
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.32,
                ),
              ),
        ),
      ),
    );

    if (!shouldShake) return timer;
    return _Shake(child: timer);
  }
}

class AnswerFeedbackCard extends StatefulWidget {
  const AnswerFeedbackCard({
    super.key,
    required this.type,
    required this.child,
    this.playSound = true,
    this.duration = const Duration(milliseconds: 650),
    this.onCompleted,
  });

  final AnswerFeedbackType type;
  final Widget child;
  final bool playSound;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<AnswerFeedbackCard> createState() => _AnswerFeedbackCardState();
}

class _AnswerFeedbackCardState extends State<AnswerFeedbackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted?.call();
    });
    if (widget.playSound) _playFeedbackSound();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.type) {
      AnswerFeedbackType.correct => AppColors.challengeGreen,
      AnswerFeedbackType.wrong => AppColors.challengeRed,
      AnswerFeedbackType.skip => AppColors.challengeCyan,
    };

    final decorated = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        final offset = switch (widget.type) {
          AnswerFeedbackType.skip => Offset(-220 * value, 0),
          AnswerFeedbackType.wrong => Offset(
            math.sin(value * math.pi * 8) * 8,
            0,
          ),
          AnswerFeedbackType.correct => Offset.zero,
        };
        return Transform.translate(
          offset: offset,
          child: Opacity(
            opacity: widget.type == AnswerFeedbackType.skip
                ? (1 - value * 0.7).clamp(0.0, 1.0)
                : 1,
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.26),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: widget.child,
          ),
          if (widget.type == AnswerFeedbackType.correct)
            const Positioned.fill(child: IgnorePointer(child: FlyingStars())),
        ],
      ),
    );

    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 180)),
        ScaleEffect(
          begin: Offset(0.96, 0.96),
          end: Offset(1, 1),
          duration: Duration(milliseconds: 220),
        ),
      ],
      child: decorated,
    );
  }

  void _playFeedbackSound() {
    final sound = switch (widget.type) {
      AnswerFeedbackType.correct => GameSound.correct,
      AnswerFeedbackType.wrong => GameSound.wrong,
      AnswerFeedbackType.skip => GameSound.skip,
    };
    SoundService.instance.play(sound);
  }
}

class AnimatedPointsCounter extends StatelessWidget {
  const AnimatedPointsCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 650),
    this.style,
  });

  final int value;
  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, points, _) {
        return Text(
          '$points',
          style:
              style ??
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
        );
      },
    );
  }
}

class FloatingPoints extends StatelessWidget {
  const FloatingPoints({
    super.key,
    required this.points,
    this.color = AppColors.challengeGreen,
    this.duration = const Duration(milliseconds: 900),
  });

  final int points;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -44 * value),
          child: Opacity(opacity: (1 - value).clamp(0.0, 1.0), child: child),
        );
      },
      child: Text(
        points >= 0 ? '+$points ⬆️' : '$points',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }
}

class WinCelebrationOverlay extends StatefulWidget {
  const WinCelebrationOverlay({
    super.key,
    this.trophy,
    this.lottieAsset,
    this.playSound = true,
  });

  final Widget? trophy;
  final String? lottieAsset;
  final bool playSound;

  @override
  State<WinCelebrationOverlay> createState() => _WinCelebrationOverlayState();
}

class _WinCelebrationOverlayState extends State<WinCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    if (widget.playSound) SoundService.instance.play(GameSound.win);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConfettiPainter(progress: _controller.value),
              );
            },
          ),
        ),
        if (widget.lottieAsset != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset(widget.lottieAsset!, repeat: false),
            ),
          ),
        ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.14).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          ),
          child:
              widget.trophy ??
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.challengeGold,
                size: 132,
              ),
        ),
      ],
    );
  }
}

class FlyingStars extends StatefulWidget {
  const FlyingStars({super.key, this.count = 12});

  final int count;

  @override
  State<FlyingStars> createState() => _FlyingStarsState();
}

class _FlyingStarsState extends State<FlyingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _StarsPainter(
            progress: Curves.easeOutCubic.transform(_controller.value),
            count: widget.count,
          ),
        );
      },
    );
  }
}

class TimerSoundTicker {
  TimerSoundTicker({
    this.lastSeconds = 5,
    this.tickSound = GameSound.timerTick,
    this.endSound = GameSound.timerEnd,
  });

  final int lastSeconds;
  final GameSound tickSound;
  final GameSound endSound;
  int? _lastSecond;
  bool _ended = false;

  void update(Duration remaining) {
    final seconds = remaining.inSeconds;
    if (seconds <= 0) {
      if (!_ended) {
        _ended = true;
        SoundService.instance.play(endSound);
      }
      return;
    }

    if (seconds <= lastSeconds && _lastSecond != seconds) {
      _lastSecond = seconds;
      SoundService.instance.play(tickSound, volume: 0.55);
    }
  }

  void reset() {
    _lastSecond = null;
    _ended = false;
  }
}

class _TimerArcPainter extends CustomPainter {
  const _TimerArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bgPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _Shake extends StatefulWidget {
  const _Shake({required this.child});

  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dx = math.sin(_controller.value * math.pi * 2) * 4;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter({required this.progress, required this.count});

  final double progress;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.challengeGold;
    final center = size.center(Offset.zero);
    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i;
      final distance = 18 + progress * (34 + i % 3 * 8);
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      paint.color = [
        AppColors.challengeGold,
        AppColors.challengeCyan,
        AppColors.challengeGreen,
      ][i % 3].withValues(alpha: 1 - progress);
      _drawStar(canvas, position, 4 + (i % 2), paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.count != count;
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = const [
      AppColors.challengeGold,
      AppColors.challengeCyan,
      AppColors.challengePink,
      AppColors.challengeGreen,
      AppColors.challengeOrange,
      AppColors.challengePurple,
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 72; i++) {
      final lane = i / 72;
      final x = ((lane * 997) % 1) * size.width;
      final fall = (progress + (i % 9) * 0.04).clamp(0.0, 1.0);
      final y = -24 + fall * (size.height + 48);
      final rotation = progress * math.pi * 4 + i;
      paint.color = colors[i % colors.length].withValues(
        alpha: 1 - progress * 0.25,
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 13),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
