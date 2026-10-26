import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/lucky_wheel_prize.dart';
import '../models/game_character.dart';
import 'adaptive_asset_image.dart';

/// Clockwise from the pointer. At zero turns the center of slot 0 is at 12
/// o'clock. To land slot i, the wheel's final turn fraction is (12 - i) / 12.
const luckyWheelSlots = <int>[5, 8, 0, 10, 1, 4, 9, 6, 3, 7, 2, 11];

/// The velvet-curtain stage in the reference animation, drawn at any viewport.
class LuckyWheelStageBackground extends StatelessWidget {
  const LuckyWheelStageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _StagePainter(),
        child: child,
      );
}

/// Only the prize disc rotates. The light bulbs, game emblem and top pointer remain
/// attached to the frame, exactly as on a mechanical prize wheel.
class LuckyWheelArtwork extends StatelessWidget {
  const LuckyWheelArtwork({
    super.key,
    required this.turns,
    required this.pulse,
    this.winningSlot,
    this.character,
    this.characterCompensation = false,
  });

  final double turns;
  final double pulse;
  final int? winningSlot;
  final GameCharacter? character;
  final bool characterCompensation;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox.square(
            dimension: side,
            child: ExcludeSemantics(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WheelFramePainter(pulse)),
                  ),
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: turns * math.pi * 2,
                      origin: Offset(0, side * .02),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DiscPainter(winningSlot),
                            ),
                          ),
                          for (var slot = 0;
                              slot < luckyWheelSlots.length;
                              slot++)
                            _slotPrize(side, slot),
                        ],
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: CustomPaint(painter: _HubPainter()),
                  ),
                  Positioned(
                    left: side * .38,
                    top: side * .4,
                    width: side * .24,
                    height: side * .24,
                    child: ClipOval(
                      child: adaptiveAssetImage(
                        'assets/presenter/head.png',
                        key: const ValueKey('lucky-wheel-brand'),
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _PointerPainter(pulse)),
                  ),
                ],
              ),
            ),
          );
        }),
      );

  Widget _slotPrize(double side, int slot) {
    final angle = slot * math.pi / 6;
    final prize = LuckyWheelPrize.catalog[luckyWheelSlots[slot]];
    final center = Offset(side * .5 + math.sin(angle) * side * .316,
        side * .52 - math.cos(angle) * side * .316);
    final size = side * .127;
    final winning = winningSlot == slot;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size * .57,
      width: size,
      height: size * 1.23,
      child: Transform.rotate(
        angle: angle,
        child: AnimatedScale(
          scale: winning ? 1.18 : 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: Column(
            children: [
              Expanded(
                  child: LuckyWheelPrizeIcon(
                      prize: prize,
                      character: character,
                      characterCompensation: characterCompensation)),
              SizedBox(
                height: side * .032,
                child: FittedBox(
                  child: Text(
                    switch (prize.kind) {
                      LuckyWheelPrizeKind.character => characterCompensation
                          ? '100'
                          : character?.nameAr ?? 'شخصية',
                      LuckyWheelPrizeKind.chest => 'صندوق الحظ',
                      _ => '${prize.amount}',
                    },
                    style: TextStyle(
                      fontSize: side * .031,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFF7D4),
                      shadows: const [
                        Shadow(color: Color(0xFF4E215B), offset: Offset(1, 1)),
                        Shadow(
                            color: Color(0xFF4E215B), offset: Offset(-1, -1)),
                        Shadow(color: Color(0xFF4E215B), offset: Offset(1, -1)),
                        Shadow(color: Color(0xFF4E215B), offset: Offset(-1, 1)),
                      ],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses the existing game artwork, cropping currency/resource emblems from
/// their source atlases instead of displaying the printed sample balances.
class LuckyWheelPrizeIcon extends StatelessWidget {
  const LuckyWheelPrizeIcon(
      {super.key,
      required this.prize,
      this.character,
      this.characterCompensation = false});
  final LuckyWheelPrize prize;
  final GameCharacter? character;
  final bool characterCompensation;

  @override
  Widget build(BuildContext context) => switch (prize.kind) {
        LuckyWheelPrizeKind.keys => const _EmblemCrop(
            asset: 'assets/store/hud_keys.webp',
            crop: Rect.fromLTRB(.365, .045, .633, .375),
          ),
        LuckyWheelPrizeKind.tickets => const _EmblemCrop(
            asset: 'assets/store/hud_tickets.webp',
            crop: Rect.fromLTRB(.365, .045, .633, .39),
          ),
        LuckyWheelPrizeKind.coins => const _EmblemCrop(
            asset: 'assets/home/coins.webp',
            crop: Rect.fromLTRB(.028, .11, .25, .87),
          ),
        LuckyWheelPrizeKind.gems => const _EmblemCrop(
            asset: 'assets/home/gems.webp',
            crop: Rect.fromLTRB(.028, .11, .25, .87),
          ),
        LuckyWheelPrizeKind.character when characterCompensation =>
          const _EmblemCrop(
            asset: 'assets/home/gems.webp',
            crop: Rect.fromLTRB(.028, .11, .25, .87),
          ),
        LuckyWheelPrizeKind.character => Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF9843D3),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFFFEBA3), width: 1.3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: adaptiveAssetImage(
                  character?.asset ?? 'assets/characters/fahad.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true),
            ),
          ),
        LuckyWheelPrizeKind.chest => adaptiveAssetImage('assets/ui/box1.png',
            fit: BoxFit.contain, excludeFromSemantics: true),
      };
}

class _EmblemCrop extends StatelessWidget {
  const _EmblemCrop({required this.asset, required this.crop});
  final String asset;
  final Rect crop;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final width = side / crop.width;
          final height = side / crop.height;
          return SizedBox.square(
            dimension: side,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -crop.left * width,
                  top: -crop.top * height,
                  width: width,
                  height: height,
                  child: adaptiveAssetImage(asset,
                      fit: BoxFit.fill, excludeFromSemantics: true),
                ),
              ],
            ),
          );
        }),
      );
}

class _StagePainter extends CustomPainter {
  const _StagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -.15),
            radius: .85,
            colors: [Color(0xFF3F147C), Color(0xFF1C064B), Color(0xFF0B0229)],
            stops: [0, .55, 1],
          ).createShader(rect));
    final random = math.Random(730);
    for (var i = 0; i < 100; i++) {
      final point = Offset(
          random.nextDouble() * size.width, random.nextDouble() * size.height);
      final radius = 1 + random.nextDouble() * size.shortestSide * .014;
      canvas.drawCircle(
          point,
          radius,
          Paint()
            ..color =
                (i.isEven ? const Color(0xFF9E3EFF) : const Color(0xFF6454FF))
                    .withValues(alpha: .04 + random.nextDouble() * .16));
      if (i % 7 == 0) {
        canvas.drawCircle(point, math.max(.6, radius * .16),
            Paint()..color = const Color(0xFFD9B5FF).withValues(alpha: .5));
      }
    }
    _curtain(canvas, size, false);
    _curtain(canvas, size, true);
  }

  void _curtain(Canvas canvas, Size size, bool right) {
    canvas.save();
    if (right) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final width = math.min(90.0, size.width * .105);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(width * 1.1, 0)
      ..cubicTo(width * .92, size.height * .27, width * .73, size.height * .61,
          width * .8, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0xFF050010), width * .25, false);
    canvas.clipPath(path);
    final curtainRect = Rect.fromLTWH(0, 0, width * 1.1, size.height);
    canvas.drawRect(
        curtainRect,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFF7D0939),
            Color(0xFFFA2866),
            Color(0xFFB80E48),
            Color(0xFFFD3D76),
            Color(0xFF8D0B3A),
            Color(0xFFEB265F),
            Color(0xFF550527),
          ], stops: [
            0,
            .17,
            .32,
            .45,
            .63,
            .82,
            1
          ]).createShader(curtainRect));
    for (var i = 0; i < 6; i++) {
      final x = width * (i / 6);
      final fold = Path()
        ..moveTo(x, 0)
        ..cubicTo(x - width * .04, size.height * .38, x - width * .1,
            size.height * .7, x - width * .06, size.height);
      canvas.drawPath(
          fold,
          Paint()
            ..color = const Color(0xFFFF77A1).withValues(alpha: .18)
            ..strokeWidth = width * .045
            ..style = PaintingStyle.stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => false;
}

class _WheelFramePainter extends CustomPainter {
  const _WheelFramePainter(this.pulse);
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    const center = Offset(500, 520);
    canvas.drawOval(
        const Rect.fromLTWH(117, 909, 766, 49),
        Paint()
          ..color = const Color(0xFF060018).withValues(alpha: .45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final point = center + Offset(math.cos(a), math.sin(a)) * 457;
      canvas.drawCircle(point + const Offset(0, 8), 15,
          Paint()..color = const Color(0xFF3D1B76));
      canvas.drawCircle(point, 13, Paint()..color = const Color(0xFF8557C6));
    }
    canvas.drawCircle(center + const Offset(0, 9), 452,
        Paint()..color = const Color(0xFF190E55));
    canvas.drawCircle(
        center,
        450,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFCDB4FF), Color(0xFF8F70E6), Color(0xFF6843B2)],
          ).createShader(const Rect.fromLTWH(50, 70, 900, 900)));
    canvas.drawCircle(
        center,
        444,
        Paint()
          ..color = const Color(0xFF321264)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    canvas.drawCircle(
        center,
        432,
        Paint()
          ..color = const Color(0xFFD7C2FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    canvas.drawCircle(
        center,
        415,
        Paint()
          ..color = const Color(0xFF22105D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12 - math.pi / 2;
      final point = center + Offset(math.cos(a), math.sin(a)) * 465;
      final lit = (i + (pulse * 8).floor()) % 4 < 2;
      if (lit) {
        canvas.drawCircle(
            point,
            15,
            Paint()
              ..color = const Color(0xFFFFE99A).withValues(alpha: .75)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      }
      canvas.drawCircle(
          point,
          8.5,
          Paint()
            ..color = lit ? const Color(0xFFFFFCE2) : const Color(0xFF9B72B9));
      if (lit) {
        canvas.drawCircle(
            point - const Offset(1, 2), 4, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelFramePainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter(this.winningSlot);
  final int? winningSlot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    const center = Offset(500, 520);
    const rect = Rect.fromLTWH(93, 113, 814, 814);
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 - math.pi / 12 + i * math.pi / 6;
      final gold = luckyWheelSlots[i] == 5;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, angle, math.pi / 6, false)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 0),
              colors: gold
                  ? const [
                      Color(0xFFFFF0AF),
                      Color(0xFFFFCD35),
                      Color(0xFFD99500)
                    ]
                  : i.isEven
                      ? const [
                          Color(0xFFFFEEF3),
                          Color(0xFFFFD1E4),
                          Color(0xFFF4A8D3)
                        ]
                      : const [
                          Color(0xFFFFCDE8),
                          Color(0xFFF285C6),
                          Color(0xFFE254AC)
                        ],
              stops: const [0, .48, 1],
            ).createShader(rect));
      if (gold || winningSlot == i) {
        canvas.drawPath(
            path,
            Paint()
              ..color = winningSlot == i
                  ? const Color(0xFFFFFFCB)
                  : const Color(0xFFFFF2AD)
              ..strokeWidth = winningSlot == i ? 6 : 4
              ..style = PaintingStyle.stroke);
      }
    }
    canvas.drawCircle(center, 215,
        Paint()..color = const Color(0xFFFFF3ED).withValues(alpha: .43));
    canvas.drawCircle(
        center,
        405,
        Paint()
          ..color = const Color(0xFFFFD7F3).withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiscPainter oldDelegate) =>
      oldDelegate.winningSlot != winningSlot;
}

class _HubPainter extends CustomPainter {
  const _HubPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    const center = Offset(500, 520);
    canvas.drawCircle(center + const Offset(0, 9), 131,
        Paint()..color = const Color(0xFF431B83));
    canvas.drawCircle(
        center,
        130,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC1AEFF), Color(0xFF9A79F3), Color(0xFF7954CA)],
          ).createShader(const Rect.fromLTWH(370, 390, 260, 260)));
    canvas.drawCircle(
        center,
        126,
        Paint()
          ..color = const Color(0xFF6140A7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    canvas.drawArc(
        const Rect.fromLTWH(382, 403, 236, 232),
        math.pi * 1.13,
        math.pi * .8,
        false,
        Paint()
          ..color = const Color(0xFFE5D7FF).withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HubPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.pulse);
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    final path = Path()
      ..moveTo(500, 145)
      ..cubicTo(484, 129, 470, 111, 473, 91)
      ..cubicTo(476, 61, 524, 61, 527, 91)
      ..cubicTo(530, 111, 516, 129, 500, 145)
      ..close();
    canvas.drawShadow(path, const Color(0xFF22103F), 5, false);
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFEF), Color(0xFFFFE6A1)],
          ).createShader(const Rect.fromLTWH(473, 68, 54, 77)));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF624B5B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    canvas.drawCircle(
        const Offset(500, 91), 6, Paint()..color = const Color(0xFF877086));
    canvas.drawCircle(const Offset(498, 89), 2, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
