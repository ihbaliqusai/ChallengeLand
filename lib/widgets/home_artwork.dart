import 'package:flutter/material.dart';

abstract final class HomeArtwork {
  static const menu = 'assets/home/menu.webp';
  static const friends = 'assets/home/friends.webp';
  static const store = 'assets/home/store.webp';
  static const campaign = 'assets/home/campaign.webp';
  static const modes = 'assets/home/modes.webp';
  static const gems = 'assets/home/gems.webp';
  static const coins = 'assets/home/coins.webp';

  static double bannerWidth(bool compact) => compact ? 190 : 209;
  static double bannerHeight(bool compact) => compact ? 60 : 68.5;
}

/// The original compact level badge, with live XP and progress.
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFACC15).withValues(alpha: .6),
              width: 1.5,
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFACC15), size: 18),
              const SizedBox(width: 6),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('المستوى $level',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    )),
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      key: const ValueKey('home-level-progress'),
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: .15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFACC15)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 6),
              Text('$xp/$requiredXp',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .7),
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
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

class _HomeBannerButtonState extends State<HomeBannerButton> {
  bool pressed = false;
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
                          child: Image.asset(widget.asset,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true)))))));
}
