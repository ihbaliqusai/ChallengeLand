import 'dart:math' as math;

import 'package:flutter/material.dart';

class MascotAvatar extends StatefulWidget {
  const MascotAvatar({super.key, this.size = 300});

  final double size;

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
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
      builder: (context, child) {
        final strain = math.sin(_controller.value * math.pi);
        return Transform.translate(
          offset: Offset(0, -5 * strain),
          child: Transform.rotate(
            angle: -0.008 + (0.016 * strain),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.08,
        child: CustomPaint(painter: _LionWeightlifterPainter()),
      ),
    );
  }
}

class _LionWeightlifterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 346);

    _drawShadow(canvas);
    _drawBarbell(canvas);
    _drawLegs(canvas);
    _drawBody(canvas);
    _drawArms(canvas);
    _drawHead(canvas);
    _drawFace(canvas);

    canvas.restore();
  }

  void _drawShadow(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(68, 315, 184, 28), paint);
  }

  void _drawBarbell(Canvas canvas) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    paint
      ..strokeWidth = 15
      ..color = const Color(0xFF3B3552);
    canvas.drawLine(const Offset(34, 183), const Offset(286, 183), paint);

    paint
      ..strokeWidth = 6
      ..color = const Color(0xFF6E6A83);
    canvas.drawLine(const Offset(50, 176), const Offset(270, 176), paint);

    _drawWeight(canvas, const Offset(37, 183), -1);
    _drawWeight(canvas, const Offset(283, 183), 1);
  }

  void _drawWeight(Canvas canvas, Offset center, int side) {
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? 50.0 : 30.0;
      final angle = (-math.pi / 2) + (i * math.pi / 5);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(side.toDouble(), 1);
    canvas.translate(-center.dx, -center.dy);

    paint.color = const Color(0xFF228BFF);
    canvas.drawPath(path, paint);
    paint.color = const Color(0xFF1D55C8);
    canvas.drawPath(
      Path.combine(
        PathOperation.intersect,
        path,
        Path()..addRect(Rect.fromLTWH(center.dx - 48, center.dy, 96, 55)),
      ),
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF0E3B91);
    canvas.drawPath(path, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFBBD7FF);
    canvas.drawCircle(center, 13, paint);
    paint.color = const Color(0xFF6F7694);
    canvas.drawCircle(center, 8, paint);
    canvas.restore();
  }

  void _drawLegs(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFF6A43B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(104, 246, 45, 61),
        const Radius.circular(18),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(176, 246, 45, 61),
        const Radius.circular(18),
      ),
      paint,
    );

    paint.color = const Color(0xFF22305F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(95, 232, 130, 55),
        const Radius.circular(24),
      ),
      paint,
    );

    _drawShoe(canvas, const Rect.fromLTWH(78, 294, 76, 33));
    _drawShoe(canvas, const Rect.fromLTWH(168, 294, 76, 33));
  }

  void _drawShoe(Canvas canvas, Rect rect) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF2792FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(15)),
      paint,
    );
    paint.color = const Color(0xFF1149B5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top + 17, rect.width, 14),
        const Radius.circular(12),
      ),
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white;
    canvas.drawLine(
      Offset(rect.left + 16, rect.top + 12),
      Offset(rect.left + 46, rect.top + 12),
      paint,
    );
  }

  void _drawBody(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFF6A43B);
    canvas.drawOval(const Rect.fromLTWH(96, 180, 128, 112), paint);

    paint.color = const Color(0xFFE9E6EF);
    final tank = Path()
      ..moveTo(110, 186)
      ..quadraticBezierTo(160, 206, 210, 186)
      ..lineTo(204, 270)
      ..quadraticBezierTo(160, 286, 116, 270)
      ..close();
    canvas.drawPath(tank, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFC5BFCD);
    canvas.drawPath(tank, paint);
  }

  void _drawArms(Canvas canvas) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..color = const Color(0xFFF6A43B);

    canvas.drawLine(const Offset(105, 205), const Offset(68, 184), paint);
    canvas.drawLine(const Offset(215, 205), const Offset(252, 184), paint);

    paint
      ..strokeWidth = 20
      ..color = const Color(0xFFD77A21);
    canvas.drawLine(const Offset(101, 207), const Offset(70, 188), paint);
    canvas.drawLine(const Offset(219, 207), const Offset(250, 188), paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFC064);
    canvas.drawCircle(const Offset(70, 184), 18, paint);
    canvas.drawCircle(const Offset(250, 184), 18, paint);
  }

  void _drawHead(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF8F4B16);
    final mane = Path();
    const center = Offset(160, 128);
    for (var i = 0; i < 26; i++) {
      final radius = i.isEven ? 100.0 : 76.0;
      final angle = -math.pi / 2 + (math.pi * 2 * i / 26);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        mane.moveTo(point.dx, point.dy);
      } else {
        mane.lineTo(point.dx, point.dy);
      }
    }
    mane.close();
    canvas.drawPath(mane, paint);

    paint.color = const Color(0xFFE17E22);
    canvas.drawCircle(const Offset(100, 72), 28, paint);
    canvas.drawCircle(const Offset(220, 72), 28, paint);
    paint.color = const Color(0xFFFFC66B);
    canvas.drawCircle(const Offset(103, 76), 14, paint);
    canvas.drawCircle(const Offset(217, 76), 14, paint);

    paint.color = const Color(0xFFF7A53E);
    canvas.drawOval(const Rect.fromLTWH(64, 54, 192, 158), paint);
    paint.color = const Color(0xFFFFC66B);
    canvas.drawOval(const Rect.fromLTWH(92, 122, 136, 70), paint);
    canvas.drawOval(const Rect.fromLTWH(112, 94, 96, 78), paint);

    paint.color = const Color(0xFFB75E17);
    canvas.drawPath(
      Path()
        ..moveTo(160, 52)
        ..quadraticBezierTo(145, 78, 160, 102)
        ..quadraticBezierTo(175, 78, 160, 52),
      paint,
    );
  }

  void _drawFace(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.black;
    canvas.drawLine(const Offset(98, 106), const Offset(132, 122), paint);
    canvas.drawLine(const Offset(222, 106), const Offset(188, 122), paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF311824);
    canvas.drawOval(const Rect.fromLTWH(104, 132, 30, 43), paint);
    canvas.drawOval(const Rect.fromLTWH(186, 132, 30, 43), paint);

    paint.color = const Color(0xFF3A1B15);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(160, 154), width: 34, height: 24),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A1B15);
    canvas.drawArc(
      const Rect.fromLTWH(130, 154, 30, 26),
      0.1,
      1.4,
      false,
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(160, 154, 30, 26),
      1.6,
      1.4,
      false,
      paint,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(130, 172)
        ..lineTo(140, 172)
        ..lineTo(135, 188)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(180, 172)
        ..lineTo(190, 172)
        ..lineTo(185, 188)
        ..close(),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF74D7FF);
    canvas.drawLine(const Offset(229, 108), const Offset(226, 133), paint);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(226, 139), 5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
