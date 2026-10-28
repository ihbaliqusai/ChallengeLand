import 'package:flutter/material.dart';

import '../core/app_settings.dart';

/// Shared page navigation control. Callers keep their own leave/save guards.
class GameBackButton extends StatelessWidget {
  const GameBackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      tooltip: rtl ? 'رجوع' : 'Back',
      onPressed: onPressed == null
          ? null
          : () {
              AppSettings.playClick();
              onPressed!();
            },
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        maximumSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: Opacity(
        opacity: onPressed == null ? 0.38 : 1,
        child: Transform.flip(
          flipX: rtl,
          child: const SizedBox.square(
            dimension: 44,
            child: CustomPaint(painter: _GameBackArrowPainter()),
          ),
        ),
      ),
    );
  }
}

class _GameBackArrowPainter extends CustomPainter {
  const _GameBackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final arrow = Path()
      ..moveTo(3, 20.5)
      ..lineTo(20, 5)
      ..cubicTo(23, 2.3, 27, 3.5, 27, 7.5)
      ..lineTo(27, 11)
      ..lineTo(37, 11)
      ..quadraticBezierTo(44, 11, 44, 18)
      ..lineTo(44, 30)
      ..quadraticBezierTo(44, 37, 37, 37)
      ..lineTo(27, 37)
      ..lineTo(27, 40.5)
      ..cubicTo(27, 44.5, 23, 45.7, 20, 43)
      ..lineTo(3, 27.5)
      ..quadraticBezierTo(-.5, 24, 3, 20.5)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0x883F36A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(arrow, Paint()..color = Colors.white);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xFF2B285F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GameBackArrowPainter oldDelegate) => false;
}
