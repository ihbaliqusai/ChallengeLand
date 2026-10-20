import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original mode artwork with native, accessible controls and glowing
/// ambient light around each game mode button.
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

  @override
  State<GameModesArtwork> createState() => _GameModesArtworkState();
}

class _GameModesArtworkState extends State<GameModesArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    // In unit/widget tests, keep a steady value so tester.pumpAndSettle() settles.
    // In live execution, breathe continuously to bring the artwork to life.
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      _pulseController.value = 0.5;
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(
        key: const ValueKey('game-modes-artwork'),
        child: AspectRatio(
          aspectRatio: GameModesArtwork.aspectRatio,
          child: LayoutBuilder(
            builder: (context, area) {
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

              Widget action(
                Rect region,
                String title,
                VoidCallback onTap, {
                String? hint,
                bool enabled = true,
                required Color glowColor,
                required Color secondaryGlowColor,
                bool isCircle = false,
              }) {
                final bounds = map(region);
                final radius = isCircle
                    ? bounds.shortestSide * 0.5
                    : bounds.shortestSide * 0.13;

                return Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: bounds.center,
                    width: math.max(48, bounds.width),
                    height: math.max(48, bounds.height),
                  ),
                  child: Tooltip(
                    message: title,
                    child: Semantics(
                      label: title,
                      hint: hint,
                      button: true,
                      enabled: enabled,
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            final t = _glowAnimation.value;
                            final pulseAlpha =
                                enabled ? (0.45 + 0.55 * t) : 0.15;
                            final blur = enabled ? (8.0 + 10.0 * t) : 3.0;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 1. Multi-layered ambient pulsing halo around the button
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                        painter: _ModeHaloPainter(
                                      color: enabled ? glowColor : Colors.black,
                                      secondaryColor: secondaryGlowColor,
                                      opacity: pulseAlpha,
                                      blur: blur,
                                      radius: radius,
                                    )),
                                  ),
                                ),

                                // 2. Luminous pulsing neon border ring
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: isCircle
                                            ? null
                                            : BorderRadius.circular(radius),
                                        shape: isCircle
                                            ? BoxShape.circle
                                            : BoxShape.rectangle,
                                        border: Border.all(
                                          color: enabled
                                              ? glowColor.withValues(
                                                  alpha: 0.70 + 0.30 * t,
                                                )
                                              : Colors.white24,
                                          width:
                                              enabled ? (1.8 + 1.2 * t) : 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Gentle dynamic light sweep across the surface
                                if (enabled)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ClipRRect(
                                        borderRadius: isCircle
                                            ? BorderRadius.circular(
                                                bounds.shortestSide * 0.5,
                                              )
                                            : BorderRadius.circular(radius),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment(
                                                  -1.2 + 2.4 * t, -1.0),
                                              end:
                                                  Alignment(1.2 + 2.4 * t, 1.0),
                                              colors: [
                                                Colors.transparent,
                                                glowColor.withValues(
                                                  alpha: 0.08 * pulseAlpha,
                                                ),
                                                Colors.white.withValues(
                                                  alpha: 0.035 * pulseAlpha,
                                                ),
                                                glowColor.withValues(
                                                  alpha: 0.08 * pulseAlpha,
                                                ),
                                                Colors.transparent,
                                              ],
                                              stops: const [
                                                0.0,
                                                0.35,
                                                0.5,
                                                0.65,
                                                1.0,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // 4. Dimming overlay for locked/unavailable mode
                                if (!enabled)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        borderRadius: isCircle
                                            ? null
                                            : BorderRadius.circular(radius),
                                        shape: isCircle
                                            ? BoxShape.circle
                                            : BoxShape.rectangle,
                                      ),
                                    ),
                                  ),

                                // 5. Touch/tap action target
                                Positioned.fill(
                                  child: TextButton(
                                    onPressed:
                                        enabled ? onTap : widget.onUnavailable,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: isCircle
                                          ? const CircleBorder()
                                          : RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(radius),
                                            ),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),

                                // 6. Lock icon for disabled states
                                if (!enabled)
                                  Positioned(
                                    top: 7,
                                    left: 7,
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: (area.maxHeight * 0.065)
                                          .clamp(14.0, 24.0),
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Semantics(
                namesRoute: true,
                label: 'أوضاع اللعب',
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(area.maxWidth * 0.035),
                        child: ClipRect(
                          child: Stack(
                            children: [
                              Positioned(
                                left: -GameModesArtwork._frame.left /
                                    GameModesArtwork._frame.width *
                                    area.maxWidth,
                                top: -GameModesArtwork._frame.top /
                                    GameModesArtwork._frame.height *
                                    area.maxHeight,
                                width: area.maxWidth /
                                    GameModesArtwork._frame.width,
                                height: area.maxHeight /
                                    GameModesArtwork._frame.height,
                                child: Image.asset(
                                  GameModesArtwork.asset,
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    action(
                      const Rect.fromLTRB(0.077, 0.098, 0.166, 0.218),
                      'إغلاق',
                      widget.onClose,
                      glowColor: const Color(0xFFFF5252),
                      secondaryGlowColor: const Color(0xFFFF7A00),
                      isCircle: true,
                    ),
                    action(
                      const Rect.fromLTRB(0.076, 0.257, 0.923, 0.552),
                      'التحدي الرئيسي',
                      widget.onMainChallenge,
                      hint: 'فريقان على جهاز واحد',
                      glowColor: const Color(0xFFFFD54F),
                      secondaryGlowColor: const Color(0xFFFF8F00),
                    ),
                    action(
                      const Rect.fromLTRB(0.657, 0.590, 0.924, 0.900),
                      'تحدي جماعي',
                      widget.onGroupChallenge,
                      hint: 'غرف ومنافسة أونلاين',
                      enabled: widget.isOnline,
                      glowColor: const Color(0xFF00E5FF),
                      secondaryGlowColor: const Color(0xFF2979FF),
                    ),
                    action(
                      const Rect.fromLTRB(0.368, 0.590, 0.635, 0.900),
                      'تحدي صديق',
                      widget.onFriendChallenge,
                      hint: '1 ضد 1 أو منافس عشوائي',
                      enabled: widget.isOnline,
                      glowColor: const Color(0xFF00E676),
                      secondaryGlowColor: const Color(0xFF00B0FF),
                    ),
                    action(
                      const Rect.fromLTRB(0.076, 0.590, 0.345, 0.900),
                      'أوفلاين',
                      widget.onOffline,
                      hint: 'العب بدون اتصال',
                      glowColor: const Color(0xFFE040FB),
                      secondaryGlowColor: const Color(0xFF7C4DFF),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModeHaloPainter extends CustomPainter {
  const _ModeHaloPainter(
      {required this.color,
      required this.secondaryColor,
      required this.opacity,
      required this.blur,
      required this.radius});
  final Color color, secondaryColor;
  final double opacity, blur, radius;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(2), Radius.circular(radius));
    // Stroke only: the glow surrounds the artwork without painting over its text.
    canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = secondaryColor.withValues(alpha: .32 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: .65 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * .45));
  }

  @override
  bool shouldRepaint(_ModeHaloPainter oldDelegate) =>
      color != oldDelegate.color ||
      secondaryColor != oldDelegate.secondaryColor ||
      opacity != oldDelegate.opacity ||
      blur != oldDelegate.blur ||
      radius != oldDelegate.radius;
}
