import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../models/game_character.dart';
import '../models/lucky_wheel_prize.dart';
import 'lucky_wheel_artwork.dart';

class LuckyWheelTitle extends StatelessWidget {
  const LuckyWheelTitle({super.key, this.scale = 1});
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 78 * scale,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Stack(children: [
            Text('دولاب الحظ',
                style: TextStyle(
                    fontSize: 49,
                    height: 1.4,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 5
                      ..color = const Color(0xFF6B2843),
                    shadows: const [
                      Shadow(color: Color(0xFF351126), offset: Offset(0, 5)),
                      Shadow(
                          color: Color(0xFFCF6592),
                          offset: Offset(0, 3),
                          blurRadius: 2),
                      Shadow(color: Color(0x80F8A73E), blurRadius: 19),
                    ])),
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF5D3),
                  Color(0xFFFFE7A5),
                  Color(0xFFF5BA53)
                ],
              ).createShader(rect),
              child: const Text('دولاب الحظ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 49,
                      height: 1.4,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}

/// The interaction remains live; only the metallic surfaces are decorative.
class LuckyWheelActionButton extends StatelessWidget {
  const LuckyWheelActionButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.badge = 0,
      this.subtitle,
      this.pulse = 0,
      this.scale = 1});

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final int badge;
  final double pulse;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: 270 * scale,
      height: (subtitle == null ? 76 : 88) * scale,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 3, 3, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? const [
                            Color(0xFFFFF9CB),
                            Color(0xFFE6B545),
                            Color(0xFF9E641D),
                            Color(0xFFFFECA6)
                          ]
                        : const [
                            Color(0xFFC0AB7B),
                            Color(0xFF756649),
                            Color(0xFFA08B5D)
                          ]),
                border: Border.all(color: const Color(0xFF84551C)),
                boxShadow: [
                  const BoxShadow(
                      color: Color(0xFF4C2616), offset: Offset(0, 5)),
                  const BoxShadow(
                      color: Color(0xA6080317),
                      blurRadius: 13,
                      offset: Offset(0, 9)),
                  if (enabled)
                    const BoxShadow(color: Color(0x45ECBE50), blurRadius: 19),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: enabled
                            ? const Color(0xFFD0FFB0)
                            : const Color(0xFF90A389)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .25, .58, 1],
                        colors: enabled
                            ? const [
                                Color(0xFFA4EE6A),
                                Color(0xFF32B943),
                                Color(0xFF098435),
                                Color(0xFF07542B)
                              ]
                            : const [
                                Color(0xFF72936B),
                                Color(0xFF4F6C50),
                                Color(0xFF3C5543),
                                Color(0xFF293F34)
                              ]),
                  ),
                  child: InkWell(
                    key: const ValueKey('lucky-wheel-spin'),
                    onTap: !enabled
                        ? null
                        : () {
                            AppSettings.playClick();
                            onPressed!();
                          },
                    child: Stack(children: [
                      Positioned(
                          left: 5,
                          right: 5,
                          top: 3,
                          height: 22 * scale,
                          child: IgnorePointer(
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x55FFFFFF),
                                            Color(0x00FFFFFF)
                                          ]))))),
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(label,
                                            style: const TextStyle(
                                                color: Color(0xFFFFF4BD),
                                                fontSize: 29,
                                                height: 1.35,
                                                fontWeight: FontWeight.w900,
                                                shadows: [
                                                  Shadow(
                                                      color: Color(0xFF1F4A1C),
                                                      offset: Offset(0, 3),
                                                      blurRadius: 2)
                                                ])),
                                        if (subtitle != null)
                                          Text(subtitle!,
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                  color: Color(0xFFFFF6D6),
                                                  height: 1.15,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800)),
                                      ])))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (enabled)
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(painter: _ButtonGlintsPainter(pulse)))),
          if (badge > 0)
            Positioned(
                right: -9,
                top: -9,
                child: Container(
                    width: 31 * scale,
                    height: 31 * scale,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                            center: Alignment(-.4, -.5),
                            radius: 1.1,
                            colors: [
                              Color(0xFFFFB1A5),
                              Color(0xFFF64C48),
                              Color(0xFFAD1735)
                            ]),
                        border: Border.all(
                            color: const Color(0xFFFFF5D5), width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xA5ED594C), blurRadius: 9),
                          BoxShadow(
                              color: Color(0xFF5C1834), offset: Offset(0, 3))
                        ]),
                    child: Text(badge > 99 ? '99+' : '$badge',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19 * scale,
                            height: 1,
                            fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }
}

class LuckyWheelPrizeLegend extends StatelessWidget {
  const LuckyWheelPrizeLegend(
      {super.key, required this.character, this.scale = 1});
  final GameCharacter? character;
  final double scale;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        const LuckyWheelGoldDivider(),
        Padding(
            padding: EdgeInsets.symmetric(vertical: 12 * scale),
            child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10 * scale,
                runSpacing: 8 * scale,
                children: [
                  for (final prize in LuckyWheelPrize.catalog.take(6))
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox.square(
                          dimension: 24 * scale,
                          child: LuckyWheelPrizeIcon(
                              prize: prize,
                              character: character,
                              characterCompensation: character == null)),
                      const SizedBox(width: 4),
                      Text(prize.title,
                          style: TextStyle(
                              color: const Color(0xFFF0D9A5),
                              fontSize: 11 * scale,
                              fontWeight: FontWeight.w700)),
                    ]),
                ])),
        const LuckyWheelGoldDivider(),
      ]);
}

class LuckyWheelGoldDivider extends StatelessWidget {
  const LuckyWheelGoldDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(
      height: 1,
      decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
        Color(0x00DDB56A),
        Color(0x66DDB56A),
        Color(0xFFFFE7A6),
        Color(0x66DDB56A),
        Color(0x00DDB56A)
      ])));
}

class _ButtonGlintsPainter extends CustomPainter {
  const _ButtonGlintsPainter(this.pulse);
  final double pulse;
  @override
  void paint(Canvas canvas, Size size) {
    for (final point in [const Offset(.035, .13), const Offset(.76, .91)]) {
      final center = Offset(size.width * point.dx, size.height * point.dy);
      final radius = 3 + (math.sin(pulse * math.pi * 2 + point.dx * 4) + 1) * 2;
      canvas.drawCircle(
          center,
          radius * 1.6,
          Paint()
            ..color = const Color(0x99FFE98B)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawLine(
          center - Offset(radius * 1.6, 0),
          center + Offset(radius * 1.6, 0),
          Paint()
            ..color = const Color(0xFFFFF7C6)
            ..strokeWidth = 1);
      canvas.drawLine(
          center - Offset(0, radius * 1.6),
          center + Offset(0, radius * 1.6),
          Paint()
            ..color = const Color(0xFFFFF7C6)
            ..strokeWidth = 1);
      canvas.drawCircle(center, 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_ButtonGlintsPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
