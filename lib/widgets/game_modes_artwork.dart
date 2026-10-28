import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import 'adaptive_asset_image.dart';
import 'guide/page_guide_steps.dart';

/// The original artwork, with independent moving cards and native controls.
class GameModesArtwork extends StatefulWidget {
  const GameModesArtwork({
    super.key,
    required this.isOnline,
    required this.onClose,
    required this.onMainChallenge,
    required this.onGroupChallenge,
    required this.onFriendChallenge,
    required this.onOffline,
    required this.onUnavailable,
    this.guideTargets = const {},
  });

  static const asset = 'assets/ui/game_modes.webp';
  static const _frame = Rect.fromLTRB(.032, .046, .968, .955);
  static const aspectRatio = (2400 * .936) / (1792 * .909);

  final bool isOnline;
  final VoidCallback onClose;
  final VoidCallback onMainChallenge;
  final VoidCallback onGroupChallenge;
  final VoidCallback onFriendChallenge;
  final VoidCallback onOffline;
  final VoidCallback onUnavailable;
  final Map<ModeGuideTarget, GlobalKey> guideTargets;

  @override
  State<GameModesArtwork> createState() => _GameModesArtworkState();
}

class _GameModesArtworkState extends State<GameModesArtwork>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      if (!_entrance.isCompleted) _entrance.forward();
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _entrance.stop();
      _entrance.value = 1;
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: const ValueKey('game-modes-artwork'),
          child: AspectRatio(
            aspectRatio: GameModesArtwork.aspectRatio,
            child: LayoutBuilder(builder: (context, area) {
              Rect map(Rect rect) => Rect.fromLTRB(
                    (rect.left - GameModesArtwork._frame.left) /
                        GameModesArtwork._frame.width *
                        area.maxWidth,
                    (rect.top - GameModesArtwork._frame.top) /
                        GameModesArtwork._frame.height *
                        area.maxHeight,
                    (rect.right - GameModesArtwork._frame.left) /
                        GameModesArtwork._frame.width *
                        area.maxWidth,
                    (rect.bottom - GameModesArtwork._frame.top) /
                        GameModesArtwork._frame.height *
                        area.maxHeight,
                  );

              Widget action({
                required String id,
                required Rect source,
                required String title,
                required VoidCallback onTap,
                required ModeGuideTarget target,
                required Color color,
                required int order,
                String? hint,
                bool enabled = true,
                bool circle = false,
              }) {
                final bounds = map(source);
                return Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: bounds.center,
                    width: math.max(48, bounds.width),
                    height: math.max(48, bounds.height),
                  ),
                  // Keep hit areas and tour anchors still while the art moves.
                  child: Tooltip(
                    key: widget.guideTargets[target],
                    message: title,
                    child: _ModeButton(
                      id: id,
                      title: title,
                      hint: hint,
                      source: source,
                      artSize: bounds.size,
                      color: color,
                      order: order,
                      enabled: enabled,
                      circle: circle,
                      animate: _animate,
                      entrance: _entrance,
                      ambient: _ambient,
                      onTap: enabled ? onTap : widget.onUnavailable,
                    ),
                  ),
                );
              }

              return Semantics(
                namesRoute: true,
                label: 'أوضاع اللعب',
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(area.maxWidth * .035),
                      child: const _ModeArtworkSlice(GameModesArtwork._frame),
                    ),
                  ),
                  // Cover the baked-in cards before drawing movable slices.
                  Positioned.fromRect(
                    rect: map(const Rect.fromLTRB(.057, .238, .944, .927)),
                    child: const _ModeBackdrop(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _ModeStarsPainter(
                            animation: _ambient,
                            animate: _animate,
                          ),
                        ),
                      ),
                    ),
                  ),
                  action(
                    id: 'close',
                    source: const Rect.fromLTRB(.077, .098, .166, .218),
                    title: 'إغلاق',
                    onTap: widget.onClose,
                    target: ModeGuideTarget.close,
                    color: const Color(0xFF67DFFF),
                    order: 0,
                    circle: true,
                  ),
                  action(
                    id: 'main',
                    source: const Rect.fromLTRB(.076, .257, .923, .552),
                    title: 'التحدي الرئيسي',
                    hint: 'فريقان على جهاز واحد',
                    onTap: widget.onMainChallenge,
                    target: ModeGuideTarget.main,
                    color: const Color(0xFFFFD54F),
                    order: 0,
                  ),
                  action(
                    id: 'group',
                    source: const Rect.fromLTRB(.657, .590, .924, .900),
                    title: 'تحدي جماعي',
                    hint: 'غرف ومنافسة أونلاين',
                    onTap: widget.onGroupChallenge,
                    target: ModeGuideTarget.group,
                    enabled: widget.isOnline,
                    color: const Color(0xFFFFD54F),
                    order: 1,
                  ),
                  action(
                    id: 'friend',
                    source: const Rect.fromLTRB(.368, .590, .635, .900),
                    title: 'تحدي صديق',
                    hint: '1 ضد 1 أو منافس عشوائي',
                    onTap: widget.onFriendChallenge,
                    target: ModeGuideTarget.friend,
                    enabled: widget.isOnline,
                    color: const Color(0xFF39CFFF),
                    order: 2,
                  ),
                  action(
                    id: 'offline',
                    source: const Rect.fromLTRB(.076, .590, .345, .900),
                    title: 'أوفلاين',
                    hint: 'العب بدون اتصال',
                    onTap: widget.onOffline,
                    target: ModeGuideTarget.offline,
                    color: const Color(0xFF59FF9C),
                    order: 3,
                  ),
                ]),
              );
            }),
          ),
        ),
      );
}

class _ModeButton extends StatefulWidget {
  const _ModeButton({
    required this.id,
    required this.title,
    required this.hint,
    required this.source,
    required this.artSize,
    required this.color,
    required this.order,
    required this.enabled,
    required this.circle,
    required this.animate,
    required this.entrance,
    required this.ambient,
    required this.onTap,
  });

  final String id, title;
  final String? hint;
  final Rect source;
  final Size artSize;
  final Color color;
  final int order;
  final bool enabled, circle, animate;
  final Animation<double> entrance, ambient;
  final VoidCallback onTap;

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _states.addListener(_interactionChanged);
  }

  void _interactionChanged() => setState(() {});

  void _activate() {
    AppSettings.playClick();
    widget.onTap();
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _states.value.contains(WidgetState.pressed);
    final highlighted = _states.value.contains(WidgetState.hovered) ||
        _states.value.contains(WidgetState.focused);
    final radius = widget.artSize.shortestSide * (widget.circle ? .5 : .13);
    final shape = widget.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return Semantics(
      label: widget.title,
      hint: widget.hint,
      button: true,
      enabled: widget.enabled,
      onTap: _activate,
      child: ExcludeSemantics(
        child: Stack(clipBehavior: Clip.none, children: [
          Center(
            child: IgnorePointer(
              child: SizedBox.fromSize(
                size: widget.artSize,
                child: AnimatedBuilder(
                  animation:
                      Listenable.merge([widget.entrance, widget.ambient]),
                  child: widget.circle
                      ? const SizedBox.expand()
                      : RepaintBoundary(
                          child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: _ModeArtworkSlice(widget.source),
                        )),
                  builder: (context, art) {
                    final progress =
                        ((widget.entrance.value - widget.order * .13) /
                                (1 - widget.order * .13))
                            .clamp(0.0, 1.0);
                    final enter = Curves.easeOutBack.transform(progress);
                    final phase =
                        (widget.ambient.value + widget.order * .21) % 1;
                    final wave = math.sin(phase * math.pi * 2);
                    final moving =
                        widget.animate && widget.enabled && !widget.circle;
                    final scale = widget.circle
                        ? 1.0
                        : .86 + .14 * enter + (moving ? wave * .012 : 0);
                    final lift = widget.circle
                        ? 0.0
                        : (1 - enter) * widget.artSize.height * .24 +
                            (moving ? wave * widget.artSize.height * .026 : 0);

                    return Transform(
                      key: ValueKey('mode-${widget.id}-motion'),
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(scale, scale, 1)
                        ..setTranslationRaw(0, lift, 0),
                      child: AnimatedScale(
                        key: ValueKey('mode-${widget.id}-press'),
                        scale: !widget.animate || widget.circle
                            ? 1
                            : pressed
                                ? .95
                                : highlighted
                                    ? 1.025
                                    : 1,
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOutCubic,
                        child: Opacity(
                          opacity: widget.circle
                              ? 1
                              : Curves.easeOut.transform(progress),
                          child: CustomPaint(
                            foregroundPainter: _ModeEffectsPainter(
                              color: widget.color,
                              radius: radius,
                              phase: phase,
                              energy: widget.enabled ? (wave + 1) / 2 : 0,
                              moving: widget.animate && widget.enabled,
                              highlighted: pressed || highlighted,
                              enabled: widget.enabled,
                            ),
                            child: Stack(fit: StackFit.expand, children: [
                              art!,
                              if (!widget.enabled)
                                DecoratedBox(
                                    decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .48),
                                  borderRadius: BorderRadius.circular(radius),
                                )),
                              if (!widget.enabled)
                                Positioned(
                                  top: 7,
                                  left: 7,
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: (widget.artSize.height * .18)
                                        .clamp(14.0, 24.0),
                                    color: Colors.white70,
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: TextButton(
              statesController: _states,
              onPressed: _activate,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
                foregroundColor: widget.color,
                overlayColor: widget.color.withValues(alpha: .16),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// All slices share the same decoded texture through adaptiveAssetImage.
class _ModeArtworkSlice extends StatelessWidget {
  const _ModeArtworkSlice(this.source);
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
                    child: adaptiveAssetImage(GameModesArtwork.asset,
                        fit: BoxFit.fill, excludeFromSemantics: true),
                  ),
                ])),
      );
}

class _ModeBackdrop extends StatelessWidget {
  const _ModeBackdrop();

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0, .018, .982, 1],
        ).createShader(rect),
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
            stops: [0, .025, .975, 1],
          ).createShader(rect),
          child: const DecoratedBox(
              decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF293F80), Color(0xFF292260), Color(0xFF3B1454)],
            ),
          )),
        ),
      );
}

class _ModeEffectsPainter extends CustomPainter {
  const _ModeEffectsPainter({
    required this.color,
    required this.radius,
    required this.phase,
    required this.energy,
    required this.moving,
    required this.highlighted,
    required this.enabled,
  });

  final Color color;
  final double radius, phase, energy;
  final bool moving, highlighted, enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), Radius.circular(radius));
    final strength = enabled ? .4 + energy * .4 : .12;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 5 : 3
      ..color = color.withValues(alpha: strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(ring, glow);
    canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlighted ? 2 : 1
          ..color =
              color.withValues(alpha: highlighted ? .95 : strength * .65));
    if (!moving) return;

    // A short travelling highlight makes each card feel independently alive.
    final path = Path()..addRRect(ring);
    final metric = path.computeMetrics().first;
    final start = phase * metric.length;
    final length = metric.length * .12;
    final streak =
        metric.extractPath(start, math.min(start + length, metric.length));
    if (start + length > metric.length) {
      streak.addPath(
          metric.extractPath(0, start + length - metric.length), Offset.zero);
    }
    canvas.drawPath(
        streak,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(color, Colors.white, .7)!);

    // Leave a pause between sweeps so the artwork and Arabic text stay clear.
    if (phase < .42) {
      canvas.save();
      canvas.clipRRect(ring);
      final x = (-.55 + phase / .42 * 2.1) * size.width;
      final shine = Rect.fromLTWH(x, 0, size.width * .42, size.height);
      canvas.drawRect(
          shine,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: .17),
                Colors.transparent
              ],
            ).createShader(shine));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ModeEffectsPainter old) =>
      color != old.color ||
      radius != old.radius ||
      phase != old.phase ||
      energy != old.energy ||
      moving != old.moving ||
      highlighted != old.highlighted ||
      enabled != old.enabled;
}

class _ModeStarsPainter extends CustomPainter {
  _ModeStarsPainter({required this.animation, required this.animate})
      : super(repaint: animation);
  final Animation<double> animation;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final time = animate ? animation.value * math.pi * 2 : 0.0;
    for (var i = 0; i < 16; i++) {
      final phase = time + i * 2.399;
      final point = Offset(
        size.width * (.07 + ((i * .618) % 1) * .86),
        size.height * (.22 + ((i * .381) % 1) * .72) + math.sin(phase) * 3,
      );
      final alpha = .16 + (math.sin(phase * 2) + 1) * .18;
      final color =
          i.isEven ? const Color(0xFF77DAFF) : const Color(0xFFECA0FF);
      final radius = size.shortestSide * (i % 3 == 0 ? .0038 : .0022);
      canvas.drawCircle(
          point,
          radius * 3,
          Paint()
            ..color = color.withValues(alpha: alpha * .45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(
          point, radius, Paint()..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_ModeStarsPainter old) =>
      animation != old.animation || animate != old.animate;
}
