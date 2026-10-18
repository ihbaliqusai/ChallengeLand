import 'package:flutter/material.dart';

/// Flat, cut-corner lobby card with an inset frame and a heraldic shield.
class LobbyActionPanel extends StatelessWidget {
  const LobbyActionPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.gold = false,
    this.badge,
    this.showNotification = false,
  });

  final String title, subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool gold, showNotification;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = gold ? const Color(0xFFFFE18B) : const Color(0xFFE7BE96);
    return Semantics(
      button: true,
      label: '$title، $subtitle',
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: title,
        child: SizedBox(
          width: 270,
          height: 66,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: ClipPath(
                clipper: const LobbyCornerClipper(),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gold
                            ? const [
                                Color(0xFFB79839),
                                Color(0xFF73622E),
                                Color(0xFFAD9142)
                              ]
                            : const [
                                Color(0xFFAB8067),
                                Color(0xFF694635),
                                Color(0xFF392D29)
                              ],
                      ),
                    ),
                    child: InkWell(
                      onTap: onPressed,
                      child: CustomPaint(
                        painter: _LobbyPanelLines(accent),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 7, 70, 7),
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                  width: 186,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                              color: accent,
                                              fontSize: 20,
                                              height: 1.2,
                                              fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text(subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                              color:
                                                  accent.withValues(alpha: .85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
                right: 12,
                top: -5,
                bottom: 6,
                child: SizedBox(
                    width: 48,
                    child: LobbyShield(
                        color: accent,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon,
                                  color: const Color(0xFF3E3020), size: 25),
                              if (badge != null)
                                Text(badge!,
                                    style: const TextStyle(
                                        color: Color(0xFF3E3020),
                                        fontSize: 10,
                                        height: 1,
                                        fontWeight: FontWeight.w900)),
                            ])))),
            if (showNotification)
              const Positioned(
                  top: -2,
                  right: 2,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0xFFFF4F56), shape: BoxShape.circle),
                      child: SizedBox.square(dimension: 9))),
          ]),
        ),
      ),
    );
  }
}

class LobbyShield extends StatelessWidget {
  const LobbyShield(
      {super.key, required this.child, this.color = const Color(0xFFF2D376)});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipPath(
      clipper: const LobbyShieldClipper(),
      child: ColoredBox(
          color: const Color(0xFF675329),
          child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipPath(
                  clipper: const LobbyShieldClipper(),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                            color,
                            Color.lerp(color, const Color(0xFF5D4718), .55)!
                          ])),
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: child))))));
}

class LobbyShieldClipper extends CustomClipper<Path> {
  const LobbyShieldClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width * .93, s.height * .78)
    ..lineTo(s.width * .5, s.height)
    ..lineTo(s.width * .07, s.height * .78)
    ..close();
  @override
  bool shouldReclip(LobbyShieldClipper oldClipper) => false;
}

class LobbyCornerClipper extends CustomClipper<Path> {
  const LobbyCornerClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(6, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height - 6)
    ..lineTo(s.width - 6, s.height)
    ..lineTo(0, s.height)
    ..lineTo(0, 6)
    ..close();
  @override
  bool shouldReclip(LobbyCornerClipper oldClipper) => false;
}

class _LobbyPanelLines extends CustomPainter {
  const _LobbyPanelLines(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = color.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6), border);
    final lines = Paint()
      ..color = color.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(size.width * .90, size.height * .30),
          size.height * (.45 + i * .19), lines);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height - 4, size.width, 4),
        Paint()..color = color.withValues(alpha: .5));
  }

  @override
  bool shouldRepaint(_LobbyPanelLines oldDelegate) =>
      color != oldDelegate.color;
}
