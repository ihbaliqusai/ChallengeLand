import 'package:flutter/material.dart';

abstract final class HomeArtwork {
  static const menu = 'assets/home/menu.webp';
  static const friends = 'assets/home/friends.webp';
  static const store = 'assets/home/store.webp';
  static const campaign = 'assets/home/campaign.webp';
  static const modes = 'assets/home/modes.webp';
  static const gems = 'assets/home/gems.webp';
  static const coins = 'assets/home/coins.webp';
  static const level = 'assets/home/level_badge.png';
  static const background = 'assets/home/lobby_background.jfif';

  static double bannerWidth(bool compact) => compact ? 190 : 209;
  static double bannerHeight(bool compact) => compact ? 60 : 68.5;
}

/// Supplied stone-and-gold frame with live level, XP and progress.
class HomeLevelBadge extends StatelessWidget {
  const HomeLevelBadge({
    super.key,
    required this.level,
    required this.xp,
    required this.requiredXp,
  });

  final int level, xp, requiredXp;

  @override
  Widget build(BuildContext context) {
    final progress = requiredXp > 0 ? (xp / requiredXp).clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: 'المستوى $level، نقاط الخبرة $xp من $requiredXp',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
            width: 841,
            height: 197,
            child: Stack(children: [
              Positioned.fill(
                  child: Image.asset(HomeArtwork.level,
                      fit: BoxFit.fill, excludeFromSemantics: true)),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(44, 77, 147, 151),
                  child: const _BalanceBackground(
                      asset: HomeArtwork.level,
                      strip: Rect.fromLTRB(
                          85 / 841, 77 / 197, 92 / 841, 151 / 197))),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(48, 78, 143, 146),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$level',
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 76,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF302118),
                              shadows: [
                                Shadow(
                                    color: Color(0xFFE8C7A6),
                                    offset: Offset(0, 1.5))
                              ])))),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(307, 68, 558, 132),
                  child: const _BalanceBackground(
                      asset: HomeArtwork.level,
                      strip: Rect.fromLTRB(
                          270 / 841, 68 / 197, 284 / 841, 132 / 197))),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(319, 74, 546, 126),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$xp/$requiredXp',
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 51,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF6C977),
                              shadows: [
                                Shadow(
                                    color: Color(0xFF21140F),
                                    offset: Offset(-1.5, -1.5)),
                                Shadow(
                                    color: Color(0xFF21140F),
                                    offset: Offset(1.5, -1.5)),
                                Shadow(
                                    color: Color(0xFF21140F),
                                    offset: Offset(-1.5, 1.5)),
                                Shadow(
                                    color: Color(0xFF21140F),
                                    offset: Offset(1.5, 1.5)),
                              ])))),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(605, 130, 697, 150),
                  child: const _BalanceBackground(
                      asset: HomeArtwork.level,
                      strip: Rect.fromLTRB(
                          581 / 841, 130 / 197, 588 / 841, 150 / 197))),
              Positioned.fromRect(
                  rect: const Rect.fromLTRB(611, 135, 690, 143),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: LinearProgressIndicator(
                              key: const ValueKey('home-level-progress'),
                              value: progress,
                              minHeight: 8,
                              backgroundColor: const Color(0xFF2B1C0F),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFF7D084)))))),
            ])),
      ),
    );
  }
}

/// Retains the supplied stone frame, currency emblem and plus button, while
/// the native label displays the actual balance rather than the printed sample.
class HomeCurrencyArtwork extends StatelessWidget {
  const HomeCurrencyArtwork(
      {super.key,
      required this.gems,
      required this.value,
      required this.onPressed,
      this.enabled = true});
  final bool gems;
  final String value;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = gems ? 'رصيد الجواهر: $value' : 'رصيد النقود: $value';
    final asset = gems ? HomeArtwork.gems : HomeArtwork.coins;
    return Semantics(
        label: label,
        hint: 'فتح المتجر',
        button: true,
        onTap: onPressed,
        excludeSemantics: true,
        child: Tooltip(
            message: label,
            child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Opacity(
                    opacity: enabled ? 1 : .65,
                    child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                            width: 769,
                            height: 224,
                            child: Stack(children: [
                              Positioned.fill(
                                  child: Image.asset(asset,
                                      fit: BoxFit.fill,
                                      excludeFromSemantics: true)),
                              Positioned.fromRect(
                                  rect: const Rect.fromLTRB(.28 * 769,
                                      .20 * 224, .813 * 769, .80 * 224),
                                  child: _BalanceBackground(
                                      asset: asset,
                                      strip: gems
                                          ? const Rect.fromLTRB(
                                              .752, .20, .766, .80)
                                          : const Rect.fromLTRB(
                                              .301, .20, .312, .80))),
                              Positioned.fromRect(
                                  rect: const Rect.fromLTRB(.30 * 769,
                                      .295 * 224, .79 * 769, .825 * 224),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(value,
                                              maxLines: 1,
                                              textDirection: TextDirection.ltr,
                                              style: TextStyle(
                                                  fontSize: 90,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.1,
                                                  color: gems
                                                      ? const Color(0xFF27261D)
                                                      : const Color(0xFF65350F),
                                                  shadows: const [
                                                    Shadow(
                                                        color:
                                                            Color(0x55FFE3A9),
                                                        offset: Offset(0, 2))
                                                  ]))))),
                            ])))))));
  }
}

class _BalanceBackground extends StatelessWidget {
  const _BalanceBackground({required this.asset, required this.strip});
  final String asset;
  final Rect strip;
  static const horizontalFeather = .06, verticalFeather = .12;
  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ], stops: [
            0,
            horizontalFeather,
            1 - horizontalFeather,
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
                    verticalFeather,
                    1 - verticalFeather,
                    1
                  ]).createShader(rect),
          child: ClipRect(
              child: LayoutBuilder(
                  builder: (context, area) => Stack(children: [
                        Positioned(
                            left: -strip.left / strip.width * area.maxWidth,
                            top: -strip.top / strip.height * area.maxHeight,
                            width: area.maxWidth / strip.width,
                            height: area.maxHeight / strip.height,
                            child: Image.asset(asset,
                                fit: BoxFit.fill, excludeFromSemantics: true)),
                      ])))));
}

class HomeBannerButton extends StatefulWidget {
  const HomeBannerButton(
      {super.key,
      required this.asset,
      required this.label,
      required this.onPressed,
      this.enabled = true,
      this.compact = false});
  final String asset, label;
  final VoidCallback onPressed;
  final bool enabled, compact;
  @override
  State<HomeBannerButton> createState() => _HomeBannerButtonState();
}

class _HomeBannerButtonState extends State<HomeBannerButton>
    with SingleTickerProviderStateMixin {
  bool pressed = false;
  late final AnimationController _pulse;
  late final CurvedAnimation _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulse();
  }

  @override
  void didUpdateWidget(HomeBannerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _updatePulse();
  }

  void _updatePulse() {
    final animate = widget.enabled &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      hint: widget.enabled ? null : 'يتطلب اتصالاً بالإنترنت',
      child: Tooltip(
          message: widget.label,
          child: AnimatedScale(
              scale: pressed ? .96 : 1,
              duration: const Duration(milliseconds: 100),
              child: GestureDetector(
                  onTapDown: (_) => setState(() => pressed = true),
                  onTapCancel: () => setState(() => pressed = false),
                  onTapUp: (_) {
                    setState(() => pressed = false);
                    widget.onPressed();
                  },
                  child: SizedBox(
                      width: HomeArtwork.bannerWidth(widget.compact),
                      height: HomeArtwork.bannerHeight(widget.compact),
                      child: Opacity(
                          opacity: widget.enabled ? 1 : .55,
                          child: RepaintBoundary(
                              child: CustomPaint(
                                  foregroundPainter: _GoldFramePulsePainter(
                                      glow: _glow,
                                      campaign:
                                          widget.asset == HomeArtwork.campaign),
                                  child: Image.asset(widget.asset,
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true)))))))));
}

/// Trace the existing gold inset, keeping the pulsing light off the text.
class _GoldFramePulsePainter extends CustomPainter {
  _GoldFramePulsePainter({required this.glow, required this.campaign})
      : super(repaint: glow);
  final Animation<double> glow;
  final bool campaign;

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = glow.value;
    if (intensity <= .001) return;
    final source = campaign ? const Size(700, 238) : const Size(678, 233);
    final fitted = applyBoxFit(BoxFit.contain, source, size).destination;
    canvas.save();
    canvas.translate(
        (size.width - fitted.width) / 2, (size.height - fitted.height) / 2);
    canvas.scale(fitted.width / source.width, fitted.height / source.height);
    final path = campaign ? _campaignFrame() : _modesFrame();
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFCA45).withValues(alpha: intensity * .75)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 15
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFDF87).withValues(alpha: intensity * .95)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 4);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFF4CF).withValues(alpha: intensity * .70)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.5);
    canvas.restore();
  }

  Path _campaignFrame() => Path()
    ..moveTo(50, 64)
    ..lineTo(80, 70)
    ..lineTo(74, 27)
    ..lineTo(151, 27)
    ..lineTo(173, 45)
    ..lineTo(192, 28)
    ..lineTo(636, 28)
    ..lineTo(627, 64)
    ..lineTo(663, 60)
    ..lineTo(663, 173)
    ..lineTo(629, 167)
    ..lineTo(637, 200)
    ..lineTo(550, 200)
    ..lineTo(528, 183)
    ..lineTo(505, 200)
    ..lineTo(74, 200)
    ..lineTo(80, 166)
    ..lineTo(50, 172)
    ..close();

  Path _modesFrame() => Path()
    ..moveTo(78, 33)
    ..lineTo(599, 33)
    ..cubicTo(603, 55, 614, 64, 643, 69)
    ..lineTo(643, 168)
    ..cubicTo(616, 171, 606, 181, 600, 198)
    ..lineTo(78, 198)
    ..cubicTo(74, 178, 60, 171, 37, 169)
    ..lineTo(37, 69)
    ..cubicTo(62, 66, 73, 54, 78, 33)
    ..close();

  @override
  bool shouldRepaint(_GoldFramePulsePainter oldDelegate) =>
      campaign != oldDelegate.campaign || glow != oldDelegate.glow;
}
