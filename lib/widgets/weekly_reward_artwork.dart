import 'package:flutter/material.dart';
import 'adaptive_asset_image.dart';

const weeklyRewardAsset = 'assets/ui/weekly_reward.webp';
const weeklyRewardGold = Color(0xFFF8CE77);

/// Source regions compose the supplied artwork without baking account data
/// into the reward UI. The original PNG and its transparency stay intact.
class WeeklyArtworkSlice extends StatelessWidget {
  const WeeklyArtworkSlice(this.source, {super.key});
  final Rect source;

  @override
  Widget build(BuildContext context) => ClipRect(
      child: LayoutBuilder(
          builder: (context, area) => Stack(children: [
                Positioned(
                    left: -source.left / source.width * area.maxWidth,
                    top: -source.top / source.height * area.maxHeight,
                    width: area.maxWidth / source.width,
                    height: area.maxHeight / source.height,
                    child: adaptiveAssetImage(weeklyRewardAsset,
                        fit: BoxFit.fill, excludeFromSemantics: true)),
              ])));
}

class WeeklyRewardFrame extends StatelessWidget {
  const WeeklyRewardFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        const Positioned.fill(
            child: WeeklyArtworkSlice(Rect.fromLTRB(.23, .04, .62, .255))),
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0x2222538A), Color(0x55341050)])))),
        Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _WeeklyRim()))),
        for (final corner in [
          (Alignment.topLeft, const Rect.fromLTRB(.087, .017, .150, .113)),
          (Alignment.topRight, const Rect.fromLTRB(.908, .017, .971, .113)),
          (Alignment.bottomLeft, const Rect.fromLTRB(.087, .881, .150, .984)),
          (Alignment.bottomRight, const Rect.fromLTRB(.908, .881, .971, .984)),
        ])
          Positioned.fill(
              child: Align(
                  alignment: corner.$1,
                  child: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipPath(
                          clipper: _WeeklyCorner(corner.$1),
                          child: WeeklyArtworkSlice(corner.$2))))),
        child,
      ]));
}

class _WeeklyRim extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    void rim(double inset, double width, List<Color> colors) =>
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.deflate(inset), Radius.circular(22 - inset)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..shader = LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colors)
                  .createShader(rect));
    rim(2, 4, const [Color(0xFFFFF5C4), Color(0xFF9D6D31), Color(0xFFF5D985)]);
    rim(5, 3, const [Color(0xFFC88B31), Color(0xFFFFDB8C), Color(0xFF98672B)]);
    rim(8, 2, const [Color(0xFF8B87C9), Color(0xFF283D79), Color(0xFFA26AC9)]);
    rim(10, 1, const [Color(0xFF21367B), Color(0xFF34245E)]);
  }

  @override
  bool shouldRepaint(_WeeklyRim oldDelegate) => false;
}

class _WeeklyCorner extends CustomClipper<Path> {
  const _WeeklyCorner(this.alignment);
  final Alignment alignment;
  @override
  Path getClip(Size size) => Path()
    ..addPolygon([
      for (final point in [
        const Offset(0, 0),
        const Offset(1, 0),
        const Offset(0, 1)
      ])
        Offset((alignment.x > 0 ? 1 - point.dx : point.dx) * size.width,
            (alignment.y > 0 ? 1 - point.dy : point.dy) * size.height),
    ], true);
  @override
  bool shouldReclip(_WeeklyCorner oldClipper) =>
      oldClipper.alignment != alignment;
}

class WeeklyRewardClose extends StatelessWidget {
  const WeeklyRewardClose({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'إغلاق',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: const ClipOval(
          child: SizedBox.square(
              dimension: 48,
              child:
                  WeeklyArtworkSlice(Rect.fromLTRB(.112, .068, .171, .175)))));
}

class WeeklyRewardChest extends StatelessWidget {
  const WeeklyRewardChest({super.key, required this.open});
  final bool open;
  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        colors: [Color(0x88FCA8FF), Colors.transparent])))),
        const AspectRatio(
          aspectRatio: (688 / 531),
          child: ClipPath(
            clipper: _ChestOutline(),
            child: WeeklyArtworkSlice(Rect.fromLTRB(
                1720 / 2752, 424 / 1536, 2408 / 2752, 955 / 1536)),
          ),
        ),
        if (open)
          const Positioned(
              right: 10,
              bottom: 8,
              child: Icon(Icons.check_circle_rounded,
                  size: 32,
                  color: Color(0xFF72DDB1),
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
      ]);
}

// The supplied chest silhouette, traced in source coordinates. Native clipping
// removes the screenshot background without altering the original raster asset.
class _ChestOutline extends CustomClipper<Path> {
  const _ChestOutline();
  @override
  Path getClip(Size size) => Path()
    ..addPolygon([
      for (final p in const [
        Offset(.2137, .028),
        Offset(.173, .050),
        Offset(.1395, .091),
        Offset(.110, .15),
        Offset(.0974, .2109),
        Offset(.0843, .2938),
        Offset(.074, .4426),
        Offset(.0785, .516),
        Offset(.11, .72),
        Offset(.1032, .7608),
        Offset(.1119, .8606),
        Offset(.2035, .8832),
        Offset(.3256, .8851),
        Offset(.5625, .9303),
        Offset(.5785, .9341),
        Offset(.5799, .951),
        Offset(.5858, .9586),
        Offset(.6788, .9774),
        Offset(.7151, .9774),
        Offset(.7747, .9209),
        Offset(.7849, .8776),
        Offset(.8314, .8362),
        Offset(.8634, .8343),
        Offset(.9084, .7891),
        Offset(.9157, .6704),
        Offset(.9172, .4896),
        Offset(.936, .4614),
        Offset(.9375, .3503),
        Offset(.9259, .2147),
        Offset(.9041, .1318),
        Offset(.8677, .0829),
        Offset(.6076, .081),
        Offset(.577, .0565),
        Offset(.5087, .049),
        Offset(.3343, .0471),
        Offset(.3183, .0377),
        Offset(.2907, .0339),
      ])
        Offset(p.dx * size.width, p.dy * size.height),
    ], true);
  @override
  bool shouldReclip(_ChestOutline oldClipper) => false;
}

/// The source's glossy gold button, with a clean strip under native state text.
class WeeklyRewardAction extends StatelessWidget {
  const WeeklyRewardAction(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 48,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(children: [
            const Positioned.fill(
                child:
                    WeeklyArtworkSlice(Rect.fromLTRB(.120, .476, .520, .587))),
            Positioned.fill(
                child: FractionallySizedBox(
                    widthFactor: .55,
                    heightFactor: .72,
                    child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent
                            ], stops: [
                              0,
                              .06,
                              .94,
                              1
                            ]).createShader(rect),
                        child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (rect) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white,
                                      Colors.white,
                                      Colors.transparent
                                    ],
                                    stops: [
                                      0,
                                      .10,
                                      .90,
                                      1
                                    ]).createShader(rect),
                            child:
                                const WeeklyArtworkSlice(Rect.fromLTRB(.170, .49154, .174, .57146)))))),
            Positioned.fill(
                child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: const Color(0x552C2347),
                        foregroundColor: const Color(0xFF141D30),
                        disabledForegroundColor: const Color(0xFF5B543B),
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 23),
                          const SizedBox(width: 8),
                          Text(label,
                              style: const TextStyle(
                                  color: Color(0xFF141D30),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ])))),
          ])));
}
