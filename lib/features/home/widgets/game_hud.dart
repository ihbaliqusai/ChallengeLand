import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.username,
    required this.trophies,
    required this.energy,
    required this.coins,
    required this.onMenu,
  });

  final String username;
  final int trophies;
  final int energy;
  final int coins;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 8,
          left: compact ? 6 : 8,
          right: compact ? 6 : 8,
          bottom: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1CC2FF), Color(0xFF1267F0), Color(0xFF164AC9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            bottom: BorderSide(
              color: AppColors.challengeNavy.withValues(alpha: 0.82),
              width: 2.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Tooltip(
              message: username,
              child: _PlayerPortrait(size: compact ? 52 : 62),
            ),
            SizedBox(width: compact ? 5 : 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _HudCounter(
                      tooltip: AppStrings.trophies,
                      value: '$trophies',
                      icon: Icons.emoji_events_rounded,
                      iconColors: const [Color(0xFFFFF769), Color(0xFFFFB000)],
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Expanded(
                    child: _HudCounter(
                      tooltip: AppStrings.energy,
                      value: '$energy',
                      icon: Icons.local_fire_department_rounded,
                      iconColors: const [Color(0xFF05B6F4), Color(0xFF0B55B7)],
                      locked: true,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Expanded(
                    child: _HudCounter(
                      tooltip: AppStrings.coins,
                      value: '$coins',
                      icon: Icons.monetization_on_rounded,
                      iconColors: const [Color(0xFFFFD74A), Color(0xFFD37600)],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 5 : 8),
            Tooltip(
              message: AppStrings.menu,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onMenu,
                  child: Ink(
                    width: compact ? 42 : 50,
                    height: compact ? 42 : 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F7FDB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.challengeNavy.withValues(alpha: 0.55),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.16),
                          blurRadius: 0,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudCounter extends StatelessWidget {
  const _HudCounter({
    required this.tooltip,
    required this.value,
    required this.icon,
    required this.iconColors,
    this.locked = false,
  });

  final String tooltip;
  final String value;
  final IconData icon;
  final List<Color> iconColors;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              left: 18,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF122860), Color(0xFF06236E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF001F5D).withValues(alpha: 0.86),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 7,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.14),
                      blurRadius: 0,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: locked
                    ? Icon(
                        Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.30),
                        size: 25,
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 13, left: 26),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF00113F),
                                    blurRadius: 2,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            _RoundIcon(icon: icon, colors: iconColors, locked: locked),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.colors,
    required this.locked,
  });

  final IconData icon;
  final List<Color> colors;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 41,
      height: 41,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: locked
              ? [
                  colors.first.withValues(alpha: 0.45),
                  colors.last.withValues(alpha: 0.5),
                ]
              : colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: AppColors.challengeNavy.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: locked ? Colors.white.withValues(alpha: 0.24) : Colors.white,
        size: 27,
        shadows: const [
          Shadow(
            color: Color(0xFF5B2A00),
            blurRadius: 2,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
    );
  }
}

class _PlayerPortrait extends StatelessWidget {
  const _PlayerPortrait({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF39C7FF), Color(0xFF2548D8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF08266B), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.20),
            blurRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: const _MiniLion(),
    );
  }
}

class _MiniLion extends StatelessWidget {
  const _MiniLion();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniLionPainter());
  }
}

class _MiniLionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    paint.color = const Color(0xFF7A3E22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.58, w * 0.64, h * 0.36),
        Radius.circular(w * 0.10),
      ),
      paint,
    );

    paint.color = const Color(0xFF8F4B16);
    final mane = Path();
    final center = Offset(w * 0.50, h * 0.42);
    for (var i = 0; i < 18; i++) {
      final radius = i.isEven ? w * 0.39 : w * 0.30;
      final angle = -1.5708 + (6.28318 * i / 18);
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

    paint.color = const Color(0xFFF6A43B);
    canvas.drawCircle(Offset(w * 0.50, h * 0.42), w * 0.32, paint);

    paint.color = const Color(0xFFE17E22);
    canvas.drawCircle(Offset(w * 0.32, h * 0.27), w * 0.13, paint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.27), w * 0.13, paint);
    paint.color = const Color(0xFFFFC66B);
    canvas.drawCircle(Offset(w * 0.33, h * 0.29), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.67, h * 0.29), w * 0.07, paint);

    paint.color = const Color(0xFFFFC66B);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.51),
        width: w * 0.40,
        height: h * 0.25,
      ),
      paint,
    );

    paint.color = const Color(0xFF351B2D);
    canvas.drawCircle(Offset(w * 0.39, h * 0.39), w * 0.035, paint);
    canvas.drawCircle(Offset(w * 0.61, h * 0.39), w * 0.035, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.50),
        width: w * 0.18,
        height: h * 0.09,
      ),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF351B2D);
    canvas.drawArc(
      Rect.fromLTWH(w * 0.38, h * 0.50, w * 0.12, h * 0.10),
      0,
      1.45,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.50, h * 0.50, w * 0.12, h * 0.10),
      1.7,
      1.45,
      false,
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF26162C);
    canvas.drawLine(
      Offset(w * 0.31, h * 0.31),
      Offset(w * 0.43, h * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.69, h * 0.31),
      Offset(w * 0.57, h * 0.35),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
