import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot_avatar.dart';

class HomeScene extends StatelessWidget {
  const HomeScene({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final compact = height < 700;
        final mascotSize = (width * (compact ? 0.68 : 0.74)).clamp(
          compact ? 230.0 : 270.0,
          compact ? 270.0 : 318.0,
        );
        final mascotTop = (height * (compact ? 0.33 : 0.35)).clamp(
          compact ? 218.0 : 256.0,
          compact ? 270.0 : 305.0,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const _GymBackground(),
            const _SoftLightBeams(),
            Positioned(
              top: height * (compact ? 0.17 : 0.16),
              left: width * 0.08,
              child: _WallShelf(compact: compact),
            ),
            Positioned(
              top: height * (compact ? 0.20 : 0.22),
              right: width * 0.22,
              child: _ChampionPoster(compact: compact),
            ),
            Positioned(
              top: mascotTop + (compact ? 4 : 10),
              left: 0,
              right: 0,
              child: Center(
                child: _SquatRack(
                  width: mascotSize * 0.88,
                  height: mascotSize * 0.96,
                ),
              ),
            ),
            Positioned(
              top: mascotTop,
              left: 0,
              right: 0,
              child: Center(child: MascotAvatar(size: mascotSize)),
            ),
            Positioned(
              left: compact ? -24 : -28,
              bottom: compact ? 92 : 122,
              child: _LeftBench(compact: compact),
            ),
            Positioned(
              right: compact ? -30 : -18,
              bottom: compact ? 92 : 118,
              child: _ForegroundWeights(compact: compact),
            ),
          ],
        );
      },
    );
  }
}

class _GymBackground extends StatelessWidget {
  const _GymBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GymBackgroundPainter());
  }
}

class _GymBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final wall = Rect.fromLTWH(0, 0, size.width, size.height * 0.62);
    paint.shader = const LinearGradient(
      colors: [Color(0xFFB996CE), Color(0xFFA78DC3), Color(0xFF8F7CAC)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(wall);
    canvas.drawRect(wall, paint);
    paint.shader = null;

    paint.color = const Color(0xFF765995).withValues(alpha: 0.54);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.10)
        ..lineTo(size.width * 0.22, size.height * 0.24)
        ..lineTo(size.width * 0.12, size.height * 0.62)
        ..lineTo(0, size.height * 0.72)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF72578F).withValues(alpha: 0.38);
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height * 0.20)
        ..lineTo(size.width * 0.86, size.height * 0.28)
        ..lineTo(size.width * 0.88, size.height * 0.62)
        ..lineTo(size.width, size.height * 0.58)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFFE7D39D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.40, size.width * 0.44, 9),
        const Radius.circular(999),
      ),
      paint,
    );
    paint.color = const Color(0xFF9B784A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.414, size.width * 0.43, 6),
        const Radius.circular(999),
      ),
      paint,
    );

    paint.color = const Color(0xFF544762);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.60, size.width, size.height * 0.40),
      paint,
    );
    paint.shader =
        const LinearGradient(
          colors: [Color(0xFF7E788E), Color(0xFF4F4A59)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
          Rect.fromLTWH(0, size.height * 0.58, size.width, size.height),
        );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.58)
        ..lineTo(size.width, size.height * 0.55)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      paint,
    );
    paint.shader = null;

    paint.color = Colors.black.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, size.height * 0.63),
          width: size.width * 0.58,
          height: size.height * 0.12,
        ),
        const Radius.circular(8),
      ),
      paint,
    );
    paint.color = const Color(0xFF60566D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, size.height * 0.62),
          width: size.width * 0.55,
          height: size.height * 0.11,
        ),
        const Radius.circular(8),
      ),
      paint,
    );

    paint.color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.72),
        width: size.width * 0.54,
        height: 44,
      ),
      paint,
    );

    paint.color = Colors.white.withValues(alpha: 0.11);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.06, size.height * 0.12)
        ..lineTo(size.width * 0.22, size.height)
        ..lineTo(size.width * 0.33, size.height)
        ..lineTo(size.width * 0.16, size.height * 0.12)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SoftLightBeams extends StatelessWidget {
  const _SoftLightBeams();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _LightBeamPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LightBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.28),
        Colors.white.withValues(alpha: 0.02),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.39, size.height * 0.11)
        ..lineTo(size.width * 0.54, size.height * 0.11)
        ..lineTo(size.width * 0.64, size.height * 0.72)
        ..lineTo(size.width * 0.18, size.height * 0.96)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WallShelf extends StatelessWidget {
  const _WallShelf({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 120 : 146,
      height: compact ? 62 : 76,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Container(
              height: compact ? 9 : 11,
              decoration: BoxDecoration(
                color: const Color(0xFFE6C983),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 20 : 27,
            bottom: compact ? 18 : 22,
            child: Icon(
              Icons.emoji_events_rounded,
              color: const Color(0xFFFFC12F),
              size: compact ? 45 : 56,
              shadows: const [
                Shadow(
                  color: Color(0xFF8B5300),
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionPoster extends StatelessWidget {
  const _ChampionPoster({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 92.0 : 116.0;
    return Transform.rotate(
      angle: 0.012,
      child: Container(
        width: width,
        height: compact ? 84 : 108,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D2676), Color(0xFF9E48CD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2C174B), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 7,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.emoji_events_rounded,
            color: const Color(0xFFFFD06E),
            size: compact ? 52 : 68,
          ),
        ),
      ),
    );
  }
}

class _SquatRack extends StatelessWidget {
  const _SquatRack({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SquatRackPainter()),
    );
  }
}

class _SquatRackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final left = size.width * 0.14;
    final right = size.width * 0.86;
    final top = size.height * 0.05;
    final bottom = size.height * 0.88;

    paint
      ..strokeWidth = 9
      ..color = const Color(0xFF19191F);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(
      Offset(left - 18, bottom),
      Offset(left + 24, bottom + 8),
      paint,
    );
    canvas.drawLine(
      Offset(right - 24, bottom + 8),
      Offset(right + 18, bottom),
      paint,
    );

    paint
      ..strokeWidth = 4
      ..color = const Color(0xFF4E4F62);
    canvas.drawLine(Offset(left, top + 5), Offset(left, bottom - 8), paint);
    canvas.drawLine(Offset(right, top + 5), Offset(right, bottom - 8), paint);

    final holePaint = Paint()..color = const Color(0xFF6E6F7E);
    for (var i = 0; i < 7; i++) {
      final y = top + 16 + (i * (bottom - top - 42) / 6);
      canvas.drawCircle(Offset(left, y), 3.2, holePaint);
      canvas.drawCircle(Offset(right, y), 3.2, holePaint);
    }

    paint
      ..strokeWidth = 8
      ..color = const Color(0xFF2B2833);
    canvas.drawLine(
      Offset(size.width * 0.20, size.height * 0.42),
      Offset(size.width * 0.80, size.height * 0.42),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeftBench extends StatelessWidget {
  const _LeftBench({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 112 : 138,
      height: compact ? 126 : 154,
      child: CustomPaint(painter: _LeftBenchPainter()),
    );
  }
}

class _LeftBenchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF7F3146);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.18)
        ..lineTo(size.width * 0.92, size.height * 0.76)
        ..lineTo(size.width * 0.68, size.height * 0.88)
        ..lineTo(size.width * 0.02, size.height * 0.34)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFFBA6B43);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.10, size.height * 0.34)
        ..lineTo(size.width * 0.76, size.height * 0.88)
        ..lineTo(size.width * 0.60, size.height)
        ..lineTo(0, size.height * 0.46)
        ..close(),
      paint,
    );
    paint.color = Colors.black.withValues(alpha: 0.20);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.04, size.height * 0.49)
        ..lineTo(size.width * 0.60, size.height * 0.98)
        ..lineTo(size.width * 0.50, size.height)
        ..lineTo(0, size.height * 0.58)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ForegroundWeights extends StatelessWidget {
  const _ForegroundWeights({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 170 : 214,
      height: compact ? 150 : 186,
      child: CustomPaint(painter: _ForegroundWeightsPainter()),
    );
  }
}

class _ForegroundWeightsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final baseY = size.height * 0.68;

    paint.color = const Color(0xFF111017);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.60, baseY),
        width: size.width * 0.74,
        height: size.height * 0.24,
      ),
      paint,
    );
    paint.color = const Color(0xFF24212A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.60, baseY - 9),
          width: size.width * 0.72,
          height: size.height * 0.24,
        ),
        Radius.circular(size.height * 0.08),
      ),
      paint,
    );

    _drawKettlebell(
      canvas,
      Offset(size.width * 0.54, size.height * 0.30),
      size,
    );
    _drawBarbell(canvas, size);
  }

  void _drawKettlebell(Canvas canvas, Offset center, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final r = size.width * 0.22;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7F6BCB);
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, -r * 0.16),
        width: r * 1.55,
        height: r * 1.35,
      ),
      math.pi,
      math.pi,
      false,
      paint,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF7868C9);
    canvas.drawCircle(center.translate(0, r * 0.40), r, paint);
    paint.color = const Color(0xFF533187);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - r * 0.60, center.dy + r * 0.10)
        ..quadraticBezierTo(
          center.dx + r * 0.20,
          center.dy + r * 1.50,
          center.dx + r * 0.90,
          center.dy + r * 0.65,
        )
        ..quadraticBezierTo(
          center.dx + r * 0.70,
          center.dy + r * 1.25,
          center.dx - r * 0.45,
          center.dy + r * 1.18,
        )
        ..close(),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..color = const Color(0xFF1546A7);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r * 0.52 : r * 0.24;
      final angle = -math.pi / 2 + (math.pi * 2 * i / 10);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + r * 0.42 + math.sin(angle) * radius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, paint);
  }

  void _drawBarbell(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13
      ..color = const Color(0xFF3D3B52);
    final y = size.height * 0.92;
    canvas.drawLine(
      Offset(size.width * 0.18, y),
      Offset(size.width * 1.02, y),
      paint,
    );
    paint
      ..strokeWidth = 35
      ..color = const Color(0xFF1F7BEE);
    canvas.drawLine(
      Offset(size.width * 0.16, y),
      Offset(size.width * 0.22, y),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, y),
      Offset(size.width * 0.90, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
