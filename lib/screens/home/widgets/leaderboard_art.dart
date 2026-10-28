import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bundled flags render consistently even when the device has no emoji font.
class LeaderboardCountryFlag extends StatelessWidget {
  const LeaderboardCountryFlag({
    super.key,
    required this.code,
    this.width = 16,
  });

  final String code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final normalized = code.trim().toUpperCase();
    Widget fallback() => ColoredBox(
          color: const Color(0xFF213971),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                normalized,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: width * .5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );

    return Semantics(
      label: normalized,
      image: true,
      child: SizedBox(
        width: width,
        height: width * 2 / 3,
        child: RegExp(r'^[A-Z]{2}$').hasMatch(normalized)
            ? Image.asset(
                'assets/flags/${normalized.toLowerCase()}.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

/// A quiet violet night sky behind the leaderboard's bright blue controls.
class LeaderboardBackdrop extends StatelessWidget {
  const LeaderboardBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: SizedBox.expand(
          child: CustomPaint(painter: _LeaderboardBackdropPainter()),
        ),
      );
}

class _LeaderboardBackdropPainter extends CustomPainter {
  const _LeaderboardBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF090317),
            Color(0xFF18083E),
            Color(0xFF21104B),
            Color(0xFF0D061F),
          ],
          stops: [0, .3, .67, 1],
        ).createShader(bounds),
    );

    void glow(double x, double y, double radius, Color color) {
      final center = Offset(size.width * x, size.height * y);
      final scaledRadius = size.shortestSide * radius;
      canvas.drawCircle(
        center,
        scaledRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(
            center: center,
            radius: scaledRadius,
          )),
      );
    }

    glow(.18, .08, .25, const Color(0xFF210078));
    glow(.61, .24, .37, const Color(0x552E0767));
    glow(.13, .59, .39, const Color(0x663D137A));
    glow(.74, .71, .42, const Color(0x554A177C));
    glow(.3, .88, .27, const Color(0x55371475));

    // Fixed positions keep the sky still when rows or tabs rebuild.
    final random = math.Random(47);
    final paint = Paint();
    for (var i = 0; i < 58; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = i % 9 == 0 ? 1.3 : .45 + random.nextDouble() * .6;
      paint.color =
          Color.fromRGBO(210, 190, 255, .06 + random.nextDouble() * .14);
      canvas.drawCircle(center, radius, paint);
      if (i % 9 == 0) {
        paint.color = const Color(0x0DE0CCFF);
        canvas.drawCircle(center, radius * 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LeaderboardBackdropPainter oldDelegate) => false;
}

/// A glossy, outlined game trophy that stays sharp at any display density.
class LeaderboardTrophy extends StatelessWidget {
  const LeaderboardTrophy({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _LeaderboardTrophyPainter()),
      );
}

class _LeaderboardTrophyPainter extends CustomPainter {
  const _LeaderboardTrophyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);

    final outline = Paint()
      ..color = const Color(0xFF623905)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEC69), Color(0xFFFFC400), Color(0xFFE69200)],
        stops: [0, .42, 1],
      ).createShader(const Rect.fromLTWH(8, 10, 48, 48));

    final shadow = Path()..addOval(const Rect.fromLTWH(20, 55, 29, 7));
    canvas.drawPath(shadow, Paint()..color = const Color(0x7005061C));

    final handles = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(17, 19)
      ..cubicTo(1, 16, 2, 38, 20, 39)
      ..lineTo(21, 33)
      ..cubicTo(9, 33, 9, 22, 17, 25)
      ..close()
      ..moveTo(47, 19)
      ..cubicTo(63, 16, 62, 38, 44, 39)
      ..lineTo(43, 33)
      ..cubicTo(55, 33, 55, 22, 47, 25)
      ..close();
    canvas.drawPath(handles, gold);
    canvas.drawPath(handles, outline);

    final stem = Path()
      ..moveTo(28, 42)
      ..lineTo(36, 42)
      ..lineTo(36, 49)
      ..quadraticBezierTo(37, 52, 42, 53)
      ..lineTo(22, 53)
      ..quadraticBezierTo(27, 52, 28, 49)
      ..close();
    canvas.drawPath(stem, gold);
    canvas.drawPath(stem, outline);

    final foot = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 52, 25, 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(foot, gold);
    canvas.drawRRect(foot, outline);
    canvas.drawLine(
      const Offset(24, 54),
      const Offset(40, 54),
      Paint()
        ..color = const Color(0xFFFFEF81)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );

    final bowl = Path()
      ..moveTo(15, 15)
      ..lineTo(49, 15)
      ..cubicTo(48, 33, 45, 45, 32, 46)
      ..cubicTo(19, 45, 16, 33, 15, 15)
      ..close();
    canvas.drawPath(bowl, gold);
    canvas.drawPath(bowl, outline);

    final shine = Path()
      ..moveTo(20, 20)
      ..quadraticBezierTo(20, 34, 26, 39)
      ..quadraticBezierTo(24, 32, 24, 20)
      ..close();
    canvas.drawPath(shine, Paint()..color = const Color(0xFFFFF19B));
    canvas.drawPath(
      Path()
        ..moveTo(43, 22)
        ..quadraticBezierTo(42, 37, 35, 41),
      Paint()
        ..color = const Color(0xAAE88D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    const lip = Rect.fromLTWH(13, 10, 38, 9);
    canvas.drawOval(lip, gold);
    canvas.drawOval(lip, outline);
    canvas.drawOval(
      const Rect.fromLTWH(17, 12.3, 30, 3.4),
      Paint()..color = const Color(0xFFAC6604),
    );
    canvas.drawArc(
      const Rect.fromLTWH(15, 11, 34, 6),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFFF5AC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LeaderboardTrophyPainter oldDelegate) => false;
}
