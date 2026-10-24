import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../home/widgets/game_page_shell.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GamePageShell(
      selectedIndex: 4,
      showHud: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Column(
                children: [
                  SizedBox(height: 18),
                  _StickerScene(),
                  SizedBox(height: 28),
                  _AlbumsTitle(),
                  SizedBox(height: 18),
                  _FeatureLine(
                    icon: Icons.help_rounded,
                    text: AppStrings.collectAlbums,
                  ),
                  _FeatureLine(
                    icon: Icons.swap_horizontal_circle_rounded,
                    text: AppStrings.tradeWithFriends,
                  ),
                  _FeatureLine(
                    icon: Icons.card_giftcard_rounded,
                    text: AppStrings.winFreePrizes,
                  ),
                  SizedBox(height: 28),
                  LockedRibbon(text: AppStrings.unlockStickerAlbums),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StickerScene extends StatelessWidget {
  const _StickerScene();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            left: -28,
            child: Transform.rotate(angle: -0.35, child: const _AlbumCover()),
          ),
          Positioned(
            top: 84,
            child: Transform.rotate(angle: -0.12, child: const _OpenAlbum()),
          ),
          const Positioned(
            top: 22,
            right: 26,
            child: _StickerBadge(icon: Icons.child_care_rounded),
          ),
          const Positioned(
            top: 136,
            left: 18,
            child: _StickerBadge(icon: Icons.directions_car_rounded),
          ),
          const Positioned(
            top: 184,
            right: 22,
            child: _StickerBadge(icon: Icons.sports_kabaddi_rounded),
          ),
          const Positioned(
            bottom: 28,
            left: 48,
            child: _StickerBadge(icon: Icons.pets_rounded),
          ),
          const Positioned(
            bottom: 12,
            right: 8,
            child: _StickerBadge(icon: Icons.local_florist_rounded),
          ),
        ],
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF0E898F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          AppStrings.stickerSea,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Color(0xFF14315D),
                blurRadius: 2,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenAlbum extends StatelessWidget {
  const _OpenAlbum();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 210,
      child: CustomPaint(painter: _OpenAlbumPainter()),
    );
  }
}

class _OpenAlbumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = Colors.black.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.52, size.height * 0.85),
        width: size.width * 0.88,
        height: 30,
      ),
      paint,
    );

    paint.color = const Color(0xFFB88966);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 22, size.width - 16, size.height - 36),
        const Radius.circular(8),
      ),
      paint,
    );

    paint.color = const Color(0xFFFFF7DC);
    canvas.drawPath(
      Path()
        ..moveTo(18, 30)
        ..quadraticBezierTo(size.width * 0.28, 10, size.width * 0.50, 38)
        ..lineTo(size.width * 0.50, size.height - 22)
        ..quadraticBezierTo(
          size.width * 0.28,
          size.height - 4,
          26,
          size.height - 28,
        )
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, 38)
        ..quadraticBezierTo(size.width * 0.72, 10, size.width - 18, 30)
        ..lineTo(size.width - 26, size.height - 28)
        ..quadraticBezierTo(
          size.width * 0.72,
          size.height - 4,
          size.width * 0.50,
          size.height - 22,
        )
        ..close(),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFE6D6B8);
    canvas.drawLine(
      Offset(size.width * 0.50, 39),
      Offset(size.width * 0.50, size.height - 25),
      paint,
    );
    paint.style = PaintingStyle.fill;

    _drawSmallSticker(
      canvas,
      const Offset(78, 84),
      Icons.local_pizza_rounded,
      const Color(0xFFFF458C),
    );
    _drawSmallSticker(
      canvas,
      const Offset(132, 132),
      Icons.flutter_dash_rounded,
      const Color(0xFF00BFFF),
    );
    _drawSmallSticker(
      canvas,
      const Offset(228, 94),
      Icons.music_note_rounded,
      const Color(0xFFFFCB3F),
    );
    _drawSmallSticker(
      canvas,
      const Offset(246, 156),
      Icons.shield_rounded,
      const Color(0xFFFFA800),
    );
  }

  void _drawSmallSticker(
    Canvas canvas,
    Offset center,
    IconData icon,
    Color color,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(center, 31, paint);
    paint.color = color;
    canvas.drawCircle(center, 26, paint);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
        fontSize: 31,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StickerBadge extends StatelessWidget {
  const _StickerBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.sin(icon.codePoint.toDouble()) * 0.18,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFFFF4CA8), size: 46),
      ),
    );
  }
}

class _AlbumsTitle extends StatelessWidget {
  const _AlbumsTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      AppStrings.stickerAlbums,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFFFFE33D),
        fontSize: 42,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Color(0xFFFF2D86), blurRadius: 0, offset: Offset(2, 3)),
          Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 3)),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFE63D), size: 36),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
