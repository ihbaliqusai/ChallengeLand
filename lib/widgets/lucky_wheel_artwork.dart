import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_character.dart';
import '../models/lucky_wheel_prize.dart';
import 'adaptive_asset_image.dart';

/// Clockwise from the pointer. At zero turns the center of slot 0 is at 12
/// o'clock. To land slot i, the wheel's final turn fraction is (12 - i) / 12.
const luckyWheelSlots = <int>[5, 8, 0, 10, 1, 4, 9, 6, 3, 7, 2, 11];

const _stageAsset = 'assets/lucky_wheel/stage.webp';
const _wheelAsset = 'assets/lucky_wheel/wheel.webp';
const _hubAsset = 'assets/lucky_wheel/emblem.webp';
const _iconAssets = 'assets/lucky_wheel/icons';
const _discRadius = .404;

/// The supplied stage keeps its original velvet curtains and star lighting.
class LuckyWheelStageBackground extends StatelessWidget {
  const LuckyWheelStageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: adaptiveAssetImage(
              _stageAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
          child,
        ],
      );
}

/// The prize disc rotates around the source's exact (.5, .5) center. Its
/// scalloped gold frame, bulbs and brand emblem stay fixed. The pointer moves
/// around its fixed hinge in response to the rotating boundary pegs.
class LuckyWheelArtwork extends StatelessWidget {
  const LuckyWheelArtwork({
    super.key,
    required this.turns,
    required this.pulse,
    this.winningSlot,
    this.character,
    this.characterCompensation = false,
    this.pointerAngle = 0,
  });

  final double turns;
  final double pulse;
  final int? winningSlot;
  final GameCharacter? character;
  final bool characterCompensation;

  /// Mechanical deflection in radians, supplied by the spin's contact model.
  /// It is independent of the decorative light animation.
  final double pointerAngle;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox.square(
            dimension: side,
            child: ExcludeSemantics(
              child: Stack(clipBehavior: Clip.none, children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _WheelSupportPainter()),
                ),
                Positioned.fill(
                  child: Transform.rotate(
                    key: const ValueKey('lucky-wheel-rotating-disc'),
                    angle: turns * math.pi * 2,
                    alignment: Alignment.center,
                    child: ClipPath(
                      clipper: const _DiscClipper(),
                      child: Stack(fit: StackFit.expand, children: [
                        const CustomPaint(
                          key: ValueKey('lucky-wheel-disc-face'),
                          painter: _DiscFacePainter(),
                        ),
                        for (var slot = 0;
                            slot < luckyWheelSlots.length;
                            slot++)
                          _slotPrize(side, slot),
                        CustomPaint(
                          painter: _WinningSectorPainter(winningSlot, pulse),
                        ),
                        const CustomPaint(
                          key: ValueKey('lucky-wheel-disc-pegs'),
                          painter: _DiscPegsPainter(),
                        ),
                      ]),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    key: const ValueKey('lucky-wheel-fixed-rim'),
                    child: ClipPath(
                      clipper: const _RimClipper(),
                      child: _wheelImage(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _RimLightsPainter(pulse)),
                ),
                Positioned(
                  left: side * .359,
                  top: side * .359,
                  width: side * .282,
                  height: side * .282,
                  child: const _ArtworkCrop(
                    key: ValueKey('lucky-wheel-brand'),
                    asset: _hubAsset,
                    crop: Rect.fromLTRB(.015, .01923077, .985, .98557692),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                      key: const ValueKey('lucky-wheel-pointer'),
                      painter: _GoldPointerPainter(pointerAngle)),
                ),
              ]),
            ),
          );
        }),
      );

  Widget _slotPrize(double side, int slot) {
    final prize = LuckyWheelPrize.catalog[luckyWheelSlots[slot]];
    final isCharacter = prize.kind == LuckyWheelPrizeKind.character;
    final angle = slot * math.pi / 6;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final center = Offset(side * .5, side * .5);
    final iconCenter = center + direction * (side * .334);
    final labelCenter = center + direction * (side * .245);
    final label = switch (prize.kind) {
      LuckyWheelPrizeKind.character => characterCompensation
          ? '${LuckyWheelPrize.characterCompensationGems}'
          : character?.nameAr ?? 'شخصية',
      LuckyWheelPrizeKind.chest => 'صندوق الحظ',
      _ => '${prize.amount}',
    };
    return SizedBox.expand(
        key: ValueKey('lucky-wheel-prize-$slot'),
        child: _prizeContents(
            side, angle, iconCenter, labelCenter, label, prize, isCharacter));
  }

  Widget _prizeContents(
      double side,
      double angle,
      Offset iconCenter,
      Offset labelCenter,
      String label,
      LuckyWheelPrize prize,
      bool isCharacter) {
    return SizedBox.expand(
      key: isCharacter
          ? const ValueKey('lucky-wheel-character-prize')
          : ValueKey('lucky-wheel-prize-content:${prize.id}'),
      child: Stack(children: [
        Positioned(
          left: iconCenter.dx - side * .064,
          top: iconCenter.dy - side * .07,
          width: side * .128,
          height: side * .14,
          child: Transform.rotate(
            angle: angle,
            child: LuckyWheelPrizeIcon(
              key: isCharacter
                  ? const ValueKey('lucky-wheel-character-icon')
                  : ValueKey('lucky-wheel-prize-icon:${prize.id}'),
              prize: prize,
              character: character,
              characterCompensation: characterCompensation,
            ),
          ),
        ),
        Positioned(
          left: labelCenter.dx - side * .092,
          top: labelCenter.dy - side * .024,
          width: side * .184,
          height: side * .048,
          child: Transform.rotate(
            angle: angle,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                key: isCharacter
                    ? const ValueKey('lucky-wheel-character-label')
                    : ValueKey('lucky-wheel-prize-label:${prize.id}'),
                textDirection: isCharacter && !characterCompensation ||
                        prize.kind == LuckyWheelPrizeKind.chest
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: TextStyle(
                  fontSize: side * .032,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFF4CB),
                  shadows: [
                    for (final offset in const [
                      Offset(1, 1),
                      Offset(-1, -1),
                      Offset(1, -1),
                      Offset(-1, 1),
                    ])
                      Shadow(
                        color: const Color(0xFF7A3B25),
                        offset: offset * (side / 500),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _wheelImage() => adaptiveAssetImage(
        _wheelAsset,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      );
}

/// The supplied prize artwork is shared by wedges, the legend, prize details
/// and the reveal. Quantities and character portraits always stay live.
class LuckyWheelPrizeIcon extends StatelessWidget {
  const LuckyWheelPrizeIcon({
    super.key,
    required this.prize,
    this.character,
    this.characterCompensation = false,
  });

  final LuckyWheelPrize prize;
  final GameCharacter? character;
  final bool characterCompensation;

  @override
  Widget build(BuildContext context) => switch (prize.kind) {
        LuckyWheelPrizeKind.keys => _icon('key'),
        LuckyWheelPrizeKind.tickets => _icon('ticket'),
        LuckyWheelPrizeKind.coins => _icon('coins'),
        LuckyWheelPrizeKind.gems => _icon('gems'),
        LuckyWheelPrizeKind.character when characterCompensation =>
          _icon('gems'),
        LuckyWheelPrizeKind.character => _characterPortrait(),
        LuckyWheelPrizeKind.chest => _icon('chest'),
      };

  Widget _icon(String name) => adaptiveAssetImage(
        '$_iconAssets/$name.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      );

  Widget _characterPortrait() => LayoutBuilder(
        builder: (context, constraints) {
          const frameAspect = 200 / 262;
          final width = math.min(
              constraints.maxWidth, constraints.maxHeight * frameAspect);
          return Center(
            child: SizedBox(
              width: width,
              height: width / frameAspect,
              child: Stack(fit: StackFit.expand, children: [
                _icon('character_frame'),
                Positioned(
                  left: width * .13,
                  right: width * .13,
                  top: width / frameAspect * .10,
                  bottom: width / frameAspect * .10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(width * .025),
                    child: character == null
                        ? const FittedBox(
                            fit: BoxFit.contain,
                            child: Icon(Icons.person_rounded,
                                color: Color(0xFFFFEDBE)))
                        : adaptiveAssetImage(
                            character!.asset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
                  ),
                ),
              ]),
            ),
          );
        },
      );
}

class _ArtworkCrop extends StatelessWidget {
  const _ArtworkCrop({
    super.key,
    required this.asset,
    required this.crop,
  });

  final String asset;
  final Rect crop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final width = side / crop.width;
          final height = side / crop.height;
          final content = Stack(children: [
            Positioned(
              left: -crop.left * width,
              top: -crop.top * height,
              width: width,
              height: height,
              child: adaptiveAssetImage(
                asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ]);
          return Center(
            child: SizedBox.square(
              dimension: side,
              child: ClipRect(child: content),
            ),
          );
        },
      );
}

class _DiscClipper extends CustomClipper<Path> {
  const _DiscClipper();

  @override
  Path getClip(Size size) => Path()
    ..addOval(Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide * _discRadius,
    ));

  @override
  bool shouldReclip(_DiscClipper oldClipper) => false;
}

class _RimClipper extends CustomClipper<Path> {
  const _RimClipper();

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    // Preserve the scalloped silhouette and original exterior transparency.
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide * _discRadius,
    ));

  @override
  bool shouldReclip(_RimClipper oldClipper) => false;
}

Path _sector(Size size, int slot, {double innerRadius = .202}) {
  final side = size.shortestSide;
  final center = size.center(Offset.zero);
  final angle = -math.pi / 2 - math.pi / 12 + slot * math.pi / 6;
  final outer = Rect.fromCircle(center: center, radius: side * _discRadius);
  final inner = Rect.fromCircle(center: center, radius: side * innerRadius);
  return Path()
    ..moveTo(center.dx + math.cos(angle) * side * _discRadius,
        center.dy + math.sin(angle) * side * _discRadius)
    ..arcTo(outer, angle, math.pi / 6, false)
    ..lineTo(center.dx + math.cos(angle + math.pi / 6) * side * innerRadius,
        center.dy + math.sin(angle + math.pi / 6) * side * innerRadius)
    ..arcTo(inner, angle + math.pi / 6, -math.pi / 6, false)
    ..close();
}

class _DiscFacePainter extends CustomPainter {
  const _DiscFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: side * _discRadius);
    for (var slot = 0; slot < luckyWheelSlots.length; slot++) {
      final angle = -math.pi / 2 - math.pi / 12 + slot * math.pi / 6;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, angle, math.pi / 6, false)
        ..close();
      final gold = LuckyWheelPrize.catalog[luckyWheelSlots[slot]].kind ==
          LuckyWheelPrizeKind.chest;
      final light = slot.isEven;
      final colors = gold
          ? const [
              Color(0xFFFFF4C6),
              Color(0xFFFFEBA0),
              Color(0xFFFFEAA0),
              Color(0xFFFFDF76),
              Color(0xFFF6CA45),
              Color(0xFFDDA52A),
            ]
          : light
              ? const [
                  Color(0xFFFFEDF4),
                  Color(0xFFFFDFED),
                  Color(0xFFFFDEEC),
                  Color(0xFFF8AFD8),
                  Color(0xFFF49BD1),
                  Color(0xFFE77CC6),
                ]
              : const [
                  Color(0xFFFBC6E5),
                  Color(0xFFF9ACDB),
                  Color(0xFFF9A7D8),
                  Color(0xFFEC71C3),
                  Color(0xFFE859B9),
                  Color(0xFFD947AB),
                ];
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: colors,
            stops: const [0, .49, .535, .55, .82, 1],
          ).createShader(rect),
      );
      // Fine metallic seams keep the twelve equal wedges clear at small sizes.
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * side * .145,
        center + Offset(math.cos(angle), math.sin(angle)) * side * _discRadius,
        Paint()
          ..color = const Color(0x66FFF0BD)
          ..strokeWidth = side * .0018,
      );
    }
    canvas.drawCircle(
      center,
      side * (_discRadius - .002),
      Paint()
        ..color = const Color(0xFFFFDD82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .004,
    );
  }

  @override
  bool shouldRepaint(_DiscFacePainter oldDelegate) => false;
}

/// Contact pins belong to the disc, so they rotate through the stationary
/// pointer on the twelve wedge boundaries rather than following the bulbs.
class _DiscPegsPainter extends CustomPainter {
  const _DiscPegsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    for (var slot = 0; slot < luckyWheelSlots.length; slot++) {
      final angle = -math.pi / 2 - math.pi / 12 + slot * math.pi / 6;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * side * .391;
      final radius = side * .0085;
      canvas.drawCircle(
        point + Offset(0, side * .003),
        radius * 1.25,
        Paint()
          ..color = const Color(0x990F0426)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * .002),
      );
      canvas.drawCircle(
          point, radius * 1.12, Paint()..color = const Color(0xFF825322));
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFEF),
              Color(0xFFFFE9A0),
              Color(0xFFD5A351),
              Color(0xFF8E5B23),
            ],
          ).createShader(Rect.fromCircle(center: point, radius: radius)),
      );
      canvas.drawCircle(
        point - Offset(radius * .27, radius * .3),
        radius * .3,
        Paint()..color = const Color(0xE6FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_DiscPegsPainter oldDelegate) => false;
}

class _WinningSectorPainter extends CustomPainter {
  const _WinningSectorPainter(this.slot, this.pulse);
  final int? slot;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (slot == null || slot! < 0 || slot! >= luckyWheelSlots.length) return;
    final path = _sector(size, slot!, innerRadius: .148);
    final side = size.shortestSide;
    canvas.drawPath(
        path, Paint()..color = const Color(0xFFFFF4CA).withValues(alpha: .08));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD155).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .012
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * .012),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(const Color(0xFFFFD460), const Color(0xFFFFF7DB),
            .55 + .25 * math.sin(pulse * math.pi * 2))!
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .004,
    );
  }

  @override
  bool shouldRepaint(_WinningSectorPainter oldDelegate) =>
      oldDelegate.slot != slot || oldDelegate.pulse != pulse;
}

class _RimLightsPainter extends CustomPainter {
  const _RimLightsPainter(this.pulse);
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    for (var index = 0; index < 24; index++) {
      final angle = -math.pi / 2 + index * math.pi / 12;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * side * .46;
      final light =
          .5 + .5 * math.sin(pulse * math.pi * 2 - index * math.pi / 3);
      canvas.drawCircle(
        point,
        side * .015,
        Paint()
          ..color = const Color(0xFFFFD55B).withValues(alpha: .16 + light * .32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * .01),
      );
      canvas.drawCircle(
        point,
        side * .0045,
        Paint()
          ..color = const Color(0xFFFFFAE5).withValues(alpha: .2 + light * .75),
      );
    }
  }

  @override
  bool shouldRepaint(_RimLightsPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _WheelSupportPainter extends CustomPainter {
  const _WheelSupportPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final shadow = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .976),
      width: side * .5,
      height: side * .035,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = const Color(0xB0000010)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * .018),
    );
    final base =
        Rect.fromLTRB(side * .355, side * .945, side * .645, side * .985);
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(side * .015)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE8A3), Color(0xFFB5761E), Color(0xFF654012)],
        ).createShader(base),
    );
  }

  @override
  bool shouldRepaint(_WheelSupportPainter oldDelegate) => false;
}

class _GoldPointerPainter extends CustomPainter {
  const _GoldPointerPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    // The spring moves only the arrow around its physical mounting pin. The
    // mounting pin is painted after restoring this transform and stays fixed.
    canvas.save();
    canvas.translate(500, 44);
    canvas.rotate(angle.isFinite ? angle : 0);
    canvas.translate(-500, -44);
    final pointer = Path()
      ..moveTo(500, 116)
      ..cubicTo(485, 100, 460, 78, 460, 52)
      ..cubicTo(460, 1, 540, 1, 540, 52)
      ..cubicTo(540, 78, 515, 100, 500, 116)
      ..close();
    canvas.drawShadow(pointer, const Color(0xE52B100D), 8, false);
    canvas.drawPath(pointer.shift(const Offset(0, 4)),
        Paint()..color = const Color(0xFF643810));
    canvas.drawPath(
      pointer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF9D9),
            Color(0xFFFFD96C),
            Color(0xFFC48727),
            Color(0xFFFFE6A2),
            Color(0xFF9F611B),
          ],
          stops: [0, .3, .54, .73, 1],
        ).createShader(const Rect.fromLTWH(460, 12, 80, 104)),
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..color = const Color(0xFFFFE5A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
    canvas.drawCircle(
        const Offset(500, 46), 12, Paint()..color = const Color(0xFF92591D));
    canvas.drawCircle(
      const Offset(500, 44),
      10,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF5C7), Color(0xFFC18A2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(490, 34, 20, 20)),
    );
    canvas.drawCircle(
        const Offset(497, 41), 3, Paint()..color = const Color(0xFFFFFFEC));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoldPointerPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
