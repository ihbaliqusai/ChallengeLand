import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single entrance timeline keeps the portrait, scores and rewards in rhythm.
class VictoryReveal extends StatelessWidget {
  const VictoryReveal({
    super.key,
    required this.animation,
    required this.child,
    this.start = 0,
    this.end = .5,
    this.distance = 18,
    this.pop = false,
  });

  final Animation<double> animation;
  final Widget child;
  final double start, end, distance;
  final bool pop;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (_, child) {
          final progress = Interval(start, end).transform(animation.value);
          final eased = Curves.easeOutCubic.transform(progress);
          return Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0, distance * (1 - eased)),
              child: Transform.scale(
                scale:
                    pop ? .8 + .2 * Curves.easeOutBack.transform(progress) : 1,
                child: child,
              ),
            ),
          );
        },
      );
}

/// Painted separately from the artwork, so the image and controls stay cached.
class VictoryBackdropEffects extends StatelessWidget {
  const VictoryBackdropEffects({
    super.key,
    required this.ambience,
    required this.celebration,
    required this.reducedMotion,
  });

  final Animation<double> ambience, celebration;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('victory-celebration'),
              painter: _BackdropPainter(ambience, celebration, reducedMotion),
            ),
          ),
        ),
      );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.ambience, this.celebration, this.reducedMotion)
      : super(repaint: Listenable.merge([ambience, celebration]));

  final Animation<double> ambience, celebration;
  final bool reducedMotion;

  static const colors = [
    Color(0xFFFFD76A),
    Color(0xFF78E9FF),
    Color(0xFFF39FFF),
    Color(0xFFFFF2BF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width / 960, size.height / 540);
    final phase = ambience.value * math.pi * 2;
    final paint = Paint();
    // Slow beams remain behind the result board and leave the text untouched.
    for (var side = 0; side < 2; side++) {
      final origin = Offset(size.width * (side == 0 ? .08 : .92), 0);
      final sway = math.sin(phase + side * math.pi) * size.width * .08;
      final beam = Path()
        ..moveTo(origin.dx, 0)
        ..lineTo(size.width * .5 + sway - 110 * unit, size.height)
        ..lineTo(size.width * .5 + sway + 110 * unit, size.height)
        ..close();
      canvas.drawPath(
          beam,
          paint
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors[side].withValues(alpha: .10),
                colors[side].withValues(alpha: 0),
              ],
            ).createShader(Offset.zero & size));
    }
    paint.shader = null;
    if (reducedMotion) return;

    for (var i = 0; i < 22; i++) {
      final x = (i * .6180339 + math.sin(phase + i) * .015) % 1;
      final y = (i * .381966 + 1 - ambience.value) % 1;
      final alpha = .12 + .22 * (1 + math.sin(phase + i * 1.7)) / 2;
      canvas.drawCircle(
          Offset(size.width * x, size.height * y),
          (1 + i % 3) * unit,
          paint..color = colors[i % 4].withValues(alpha: alpha));
    }

    final progress = celebration.value;
    if (progress <= 0 || progress >= 1) return;
    // Two short, deterministic confetti volleys rise from the stage corners.
    for (var i = 0; i < 76; i++) {
      final delay = (i % 5) * .025;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final side = i.isEven ? 1.0 : -1.0;
      final speed = .16 + (i * .137 % 1) * .28;
      final x = size.width * ((side > 0 ? .04 : .96) + side * speed * t) +
          math.sin(t * 9 + i) * 12 * unit;
      final lift = .85 + (i * .173 % 1) * .8;
      final y = size.height * (.9 - lift * t * 2.3 + 2.2 * t * t);
      final fade = (1 - const Interval(.65, 1).transform(t)) * .85;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i + t * (i.isEven ? 9 : -11));
      canvas.scale(1, .35 + .65 * math.cos(t * 15 + i).abs());
      paint.color = colors[i % 4].withValues(alpha: fade);
      if (i % 4 == 0) {
        canvas.drawCircle(Offset.zero, 2.4 * unit, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: 4 * unit, height: 9 * unit),
                Radius.circular(unit)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.ambience != ambience ||
      old.celebration != celebration ||
      old.reducedMotion != reducedMotion;
}

class VictoryPanelEffects extends StatelessWidget {
  const VictoryPanelEffects({super.key, required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(painter: _PanelPainter(animation)),
          ),
        ),
      );
}

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value * math.pi * 2;
    const gold = Color(0xFFFFD973);
    const center = Offset(276.5, 268.5);
    final halo = Rect.fromCircle(center: center, radius: 93);
    canvas.drawCircle(
        center,
        93,
        Paint()
          ..shader = RadialGradient(colors: [
            gold.withValues(alpha: 0),
            gold.withValues(alpha: .02),
            gold.withValues(alpha: .18 + math.sin(phase) * .06),
            gold.withValues(alpha: 0),
          ], stops: const [
            0,
            .55,
            .72,
            1
          ]).createShader(halo));

    for (var i = 0; i < 6; i++) {
      final angle = phase + i * math.pi / 3;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * 71;
      _glint(canvas, point, 2 + (1 + math.sin(phase + i)) * 1.3, gold);
    }
    for (var i = 0; i < 5; i++) {
      final point = Offset(378 + i * 51.0, i.isEven ? 81 : 57);
      _glint(canvas, point, 1.3 + (1 + math.sin(phase + i * 2)) * 1.5, gold);
    }
    final border = Path()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(108, 147, 744, 331), const Radius.circular(22)));
    final metric = border.computeMetrics().first;
    for (var i = 0; i < 3; i++) {
      final distance = ((animation.value + i / 3) % 1) * metric.length;
      final position = metric.getTangentForOffset(distance)!.position;
      _glint(canvas, position, 4, const Color(0xFFFFF2B5));
    }
  }

  void _glint(Canvas canvas, Offset point, double radius, Color color) {
    final paint = Paint()..color = color.withValues(alpha: .85);
    final path = Path()
      ..moveTo(point.dx, point.dy - radius * 2)
      ..quadraticBezierTo(point.dx + radius * .2, point.dy - radius * .2,
          point.dx + radius * 2, point.dy)
      ..quadraticBezierTo(point.dx + radius * .2, point.dy + radius * .2,
          point.dx, point.dy + radius * 2)
      ..quadraticBezierTo(point.dx - radius * .2, point.dy + radius * .2,
          point.dx - radius * 2, point.dy)
      ..quadraticBezierTo(point.dx - radius * .2, point.dy - radius * .2,
          point.dx, point.dy - radius * 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.animation != animation;
}

class VictoryCollectButton extends StatefulWidget {
  const VictoryCollectButton({
    super.key,
    required this.animation,
    required this.saving,
    required this.collected,
    required this.onPressed,
  });

  final Animation<double> animation;
  final bool saving, collected;
  final VoidCallback onPressed;

  @override
  State<VictoryCollectButton> createState() => _VictoryCollectButtonState();
}

class _VictoryCollectButtonState extends State<VictoryCollectButton> {
  bool _pressed = false;

  void _collect() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final active = !widget.saving && !widget.collected;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final label = widget.saving
        ? 'جارٍ حفظ النتيجة...'
        : widget.collected
            ? 'تم جمع المكافآت'
            : 'اجمع المكافآت';
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFFFDF89), width: 2.5));
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      excludeSemantics: true,
      onTap: active ? _collect : null,
      child: AnimatedBuilder(
        animation: widget.animation,
        child: Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: ShapeDecoration(
              shape: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.collected
                    ? const [Color(0xFF36D8B1), Color(0xFF087E77)]
                    : const [
                        Color(0xFF67E9FF),
                        Color(0xFF118EF5),
                        Color(0xFF1246B6)
                      ],
                stops: widget.collected ? null : const [0, .46, 1],
              ),
            ),
            child: InkWell(
              key: const ValueKey('victory-collect'),
              onTap: active ? _collect : null,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              splashColor: const Color(0x66FFFFFF),
              child: Stack(fit: StackFit.expand, children: [
                if (active && !reduced)
                  IgnorePointer(
                    child: CustomPaint(painter: _ButtonShine(widget.animation)),
                  ),
                AnimatedScale(
                  scale: _pressed ? .95 : 1,
                  duration: Duration(milliseconds: reduced ? 0 : 100),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.saving)
                          const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        else
                          Icon(
                              widget.collected
                                  ? Icons.check_circle_rounded
                                  : Icons.redeem_rounded,
                              size: 29,
                              color: const Color(0xFFFFEFAC)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: Color(0xFF064583),
                                        blurRadius: 3,
                                        offset: Offset(0, 2))
                                  ])),
                        ),
                      ]),
                ),
              ]),
            ),
          ),
        ),
        builder: (_, child) {
          final pulse = active && !reduced
              ? (1 + math.sin(widget.animation.value * math.pi * 4)) / 2
              : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF40DFFF)
                        .withValues(alpha: .2 + pulse * .25),
                    blurRadius: 12 + pulse * 12,
                    spreadRadius: pulse * 1.5),
                const BoxShadow(
                    color: Color(0x88031545),
                    offset: Offset(0, 5),
                    blurRadius: 5),
              ],
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _ButtonShine extends CustomPainter {
  _ButtonShine(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (animation.value * 2) % 1;
    if (t > .6) return;
    final x = -size.width * .4 + size.width * 1.8 * t / .6;
    final rect = Rect.fromLTWH(x, 0, size.width * .3, size.height);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)],
            transform: GradientRotation(-.35),
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _ButtonShine old) => old.animation != animation;
}
