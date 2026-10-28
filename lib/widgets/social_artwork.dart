import 'game_back_button.dart';
import '../core/app_settings.dart';
import 'package:flutter/material.dart';
import 'adaptive_asset_image.dart';

const socialArtworkAsset = 'assets/social/friends_challenges.jfif';
const socialGold = Color(0xFFE7C27C);

/// Draw a source region without altering the supplied reference image.
class SocialArtworkSlice extends StatelessWidget {
  const SocialArtworkSlice(this.source, {super.key});
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
                    child: adaptiveAssetImage(socialArtworkAsset,
                        fit: BoxFit.fill, excludeFromSemantics: true)),
              ])));
}

/// Rebuild the star field and ornamental frame from clear image regions, so
/// no sample players, counts, filters or account details enter the live page.
class SocialArtworkFrame extends StatelessWidget {
  const SocialArtworkFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        const Positioned.fill(child: _StarField()),
        const Positioned.fill(child: ColoredBox(color: Color(0x33100B24))),
        const Positioned.fill(child: CustomPaint(painter: _GoldFramePainter())),
        for (final corner in [
          (false, false, const Rect.fromLTRB(.044, .010, .103, .081)),
          (true, false, const Rect.fromLTRB(.933, .010, .994, .081)),
          (false, true, const Rect.fromLTRB(.044, .942, .103, .993)),
          (true, true, const Rect.fromLTRB(.933, .942, .994, .993)),
        ])
          Positioned(
              left: corner.$1 ? null : 0,
              right: corner.$1 ? 0 : null,
              top: corner.$2 ? null : 0,
              bottom: corner.$2 ? 0 : null,
              width: 40,
              height: 34,
              child: ClipPath(
                  clipper: _CornerClipper(corner.$1, corner.$2),
                  child: SocialArtworkSlice(corner.$3))),
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 12), child: child),
      ]));
}

class _StarField extends StatelessWidget {
  const _StarField();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        final tileHeight = area.maxWidth * (.195 * 1536) / (.385 * 2752);
        return ClipRect(
            child: Stack(children: [
          for (var row = 0; row < (area.maxHeight / tileHeight).ceil(); row++)
            Positioned(
                left: 0,
                right: 0,
                top: row * tileHeight,
                height: tileHeight + .5,
                child: Transform.flip(
                    flipY: row.isOdd,
                    child: const SocialArtworkSlice(
                        Rect.fromLTRB(.225, .035, .61, .23)))),
        ]));
      });
}

class _GoldFramePainter extends CustomPainter {
  const _GoldFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    void rim(double inset, double radius, double width, Paint paint) =>
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.deflate(inset), Radius.circular(radius)),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = width);
    rim(1, 21, 2, Paint()..color = const Color(0xFF735337));
    rim(
        4,
        19,
        5,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFEAC2),
                Color(0xFFC59A58),
                Color(0xFFFFE6B0)
              ]).createShader(rect));
    rim(7, 17, 1.5, Paint()..color = const Color(0xFF8A643C));
    rim(9, 16, 1.3, Paint()..color = const Color(0xFFBA85C9));
  }

  @override
  bool shouldRepaint(_GoldFramePainter oldDelegate) => false;
}

class _CornerClipper extends CustomClipper<Path> {
  const _CornerClipper(this.right, this.bottom);
  final bool right, bottom;
  @override
  Path getClip(Size size) {
    final points = [const Offset(0, 0), const Offset(1, 0), const Offset(0, 1)];
    return Path()
      ..addPolygon(
          points
              .map((p) => Offset((right ? 1 - p.dx : p.dx) * size.width,
                  (bottom ? 1 - p.dy : p.dy) * size.height))
              .toList(),
          true);
  }

  @override
  bool shouldReclip(_CornerClipper oldClipper) =>
      right != oldClipper.right || bottom != oldClipper.bottom;
}

class SocialArtworkHeader extends StatelessWidget {
  const SocialArtworkHeader({super.key, required this.onBack, this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        Center(
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF3C3), Color(0xFFFFC94F)])
                      .createShader(rect),
                  child: const Text('الأصدقاء والتحديات',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: Color(0xFF6C4227),
                                offset: Offset(0, 3),
                                blurRadius: 2)
                          ])))),
        ),
        PositionedDirectional(
          start: 0,
          child: GameBackButton(onPressed: onBack),
        ),
        PositionedDirectional(
          end: 0,
          child: IconButton(
              tooltip: 'تحديث اللاعبين',
              onPressed: onRefresh != null ? () {
                AppSettings.playClick();
                onRefresh!();
              } : null,
              padding: const EdgeInsets.all(2),
              icon: Opacity(
                  opacity: onRefresh == null ? .45 : 1,
                  child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: ClipOval(
                          child: SocialArtworkSlice(
                              Rect.fromLTRB(.158, .046, .214, .148)))))),
        ),
      ]));
}

class SocialDiscoveryArtwork extends StatelessWidget {
  const SocialDiscoveryArtwork(
      {super.key, required this.online, required this.available});
  final int online, available;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'اختر منافسك. $online متصل الآن. $available متاح للتحدي.',
      child: AspectRatio(
          aspectRatio: (.245 * 2752) / (.289 * 1536),
          child: Stack(children: [
            const Positioned.fill(
                child: ClipPath(
                    clipper: _DiscoveryClipper(),
                    child: SocialArtworkSlice(
                        Rect.fromLTRB(.719, .206, .964, .495)))),
            Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: LayoutBuilder(
                    builder: (context, area) => Stack(children: [
                          Positioned(
                              left: area.maxWidth * .09,
                              right: area.maxWidth * .10,
                              top: area.maxHeight * .623,
                              height: area.maxHeight * .228,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                          color: const Color(0xFF7FADE9),
                                          width: 1.5),
                                      gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF526FC0),
                                            Color(0xFF2A3879)
                                          ])),
                                  child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.bolt_rounded,
                                                color: Color(0xFF56D9FF),
                                                size: 23),
                                            const SizedBox(width: 4),
                                            Text('$available متاح للتحدي',
                                                style: const TextStyle(
                                                    color: Color(0xFF61DEFF),
                                                    fontSize: 17,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                          ])))),
                        ]))),
          ])));
}

class _DiscoveryClipper extends CustomClipper<Path> {
  // The contour follows the original shield above the rectangular card.
  const _DiscoveryClipper();
  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(0, size.height * .19, size.width, size.height),
        Radius.circular(size.width * .065)))
    ..addPolygon(
        const [
          Offset(0.48990, 0.00132),
          Offset(0.49732, 0.00132),
          Offset(0.52550, 0.03511),
          Offset(0.55071, 0.05313),
          Offset(0.58334, 0.06439),
          Offset(0.60559, 0.06665),
          Offset(0.60707, 0.13197),
          Offset(0.63080, 0.10044),
          Offset(0.63970, 0.07791),
          Offset(0.64563, 0.07791),
          Offset(0.64712, 0.11846),
          Offset(0.63970, 0.16802),
          Offset(0.64712, 0.17027),
          Offset(0.64712, 0.18829),
          Offset(0.67530, 0.18604),
          Offset(0.67530, 0.20406),
          Offset(0.65157, 0.20406),
          Offset(0.64712, 0.19730),
          Offset(0.64415, 0.19730),
          Offset(0.64267, 0.20406),
          Offset(0.38905, 0.20406),
          Offset(0.38608, 0.19055),
          Offset(0.38460, 0.20406),
          Offset(0.34604, 0.20406),
          Offset(0.34307, 0.19730),
          Offset(0.33417, 0.20406),
          Offset(0.32082, 0.20406),
          Offset(0.32082, 0.18604),
          Offset(0.34010, 0.18829),
          Offset(0.34010, 0.17027),
          Offset(0.34604, 0.16802),
          Offset(0.34010, 0.12972),
          Offset(0.34010, 0.07791),
          Offset(0.34604, 0.07791),
          Offset(0.35494, 0.09818),
          Offset(0.36977, 0.12071),
          Offset(0.38015, 0.12972),
          Offset(0.38312, 0.06665),
          Offset(0.40685, 0.06439),
          Offset(0.44393, 0.04862),
          Offset(0.47062, 0.02610),
          Offset(0.48990, 0.00132),
        ].map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList(),
        true);
  @override
  bool shouldReclip(_DiscoveryClipper oldClipper) => false;
}

/// Native glass and gold row surfaces keep the reference's bevels at any width.
class SocialPlayerArtwork extends StatelessWidget {
  const SocialPlayerArtwork({super.key});
  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _PlayerSurfacePainter());
}

class _PlayerSurfacePainter extends CustomPainter {
  const _PlayerSurfacePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape =
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(12));
    canvas.drawRRect(
        shape,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFEAB4),
                Color(0xFF9F7540),
                Color(0xFFEFD194)
              ]).createShader(rect));
    final inner =
        RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(9));
    canvas.drawRRect(
        inner,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF2EDFC),
                Color(0xFFD4CEE8),
                Color(0xFFD5E5F5)
              ]).createShader(rect));
    canvas.drawRRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: .85));
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * .46),
        Paint()..color = Colors.white.withValues(alpha: .16));
    canvas.drawPath(
        Path()
          ..addPolygon([
            Offset(size.width * .52, 0),
            Offset(size.width * .61, 0),
            Offset(size.width * .48, size.height),
            Offset(size.width * .39, size.height),
          ], true),
        Paint()..color = Colors.white.withValues(alpha: .22));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlayerSurfacePainter oldDelegate) => false;
}

class SocialActionButton extends StatelessWidget {
  const SocialActionButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.green,
      this.onPressed});
  final String label;
  final IconData icon;
  final bool green;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = green
        ? const [Color(0xFF70E95A), Color(0xFF2DA94D), Color(0xFF17642D)]
        : const [Color(0xFF4FCCFF), Color(0xFF287CD2), Color(0xFF293D98)];
    return Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.first, colors.last]),
                border: Border.all(color: colors.first, width: 1.5),
                boxShadow: [
                  BoxShadow(color: colors.last, offset: const Offset(0, 3))
                ]),
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .3), width: 1.5),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors)),
                child: FilledButton(
                    onPressed: onPressed != null ? () {
                      AppSettings.playClick();
                      onPressed!();
                    } : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 24),
                          const SizedBox(width: 7),
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: Color(0xFF26314F),
                                        offset: Offset(0, 2),
                                        blurRadius: 2)
                                  ])),
                        ]))))));
  }
}
