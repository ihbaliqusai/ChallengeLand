import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/trophy_league.dart';
import '../models/campaign_home_progress.dart';
import 'adaptive_asset_image.dart';
import 'guide/home_guide_steps.dart';
import 'sign_in_required_action.dart';

/// The supplied lobby artwork, arranged in the same order as the reference.
class HomeActionSidebar extends StatelessWidget {
  const HomeActionSidebar({
    super.key,
    required this.animation,
    this.leaderboardRank,
    this.campaignProgress,
    required this.trophies,
    required this.isOnline,
    required this.isVip,
    required this.guideTargets,
    required this.onLeaderboard,
    required this.onCampaign,
    required this.onVip,
    required this.onLuckyWheel,
    required this.onModes,
    required this.onFriends,
    required this.onPlay,
    this.rotatePromotions = true,
  });

  static const leaderboardAsset = 'assets/home/sidebar/leaderboard.png';
  static const campaignAsset = 'assets/home/sidebar/campaign.png';
  static const vipAsset = 'assets/home/sidebar/vip.png';
  static const luckyWheelAsset = 'assets/home/sidebar/lucky_wheel.png';
  static const modesAsset = 'assets/home/sidebar/modes.png';
  static const friendsAsset = 'assets/home/sidebar/friends.png';
  static const playAsset = 'assets/home/sidebar/play.png';
  static const assets = [
    leaderboardAsset,
    campaignAsset,
    vipAsset,
    luckyWheelAsset,
    modesAsset,
    friendsAsset,
    playAsset,
  ];
  static const minimumHeight = 274.0;

  final Animation<double> animation;
  final int? leaderboardRank;
  final int trophies;
  final CampaignHomeProgress? campaignProgress;
  final bool isOnline, isVip;
  final Map<HomeGuideTarget, GlobalKey> guideTargets;
  final VoidCallback onLeaderboard, onCampaign, onVip;
  final VoidCallback onLuckyWheel, onModes, onFriends, onPlay;
  final bool rotatePromotions;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(builder: (context, constraints) {
          final height =
              constraints.hasBoundedHeight ? constraints.maxHeight : 480.0;
          final gap = ((height - minimumHeight) * .045 + 4).clamp(4.0, 14.0);
          final extra = math.max(0.0, height - gap * 4 - 258);
          final heights = [
            48 + extra * .18,
            60 + extra * .32,
            48 + extra * .22,
            48 + extra * .04,
            54 + extra * .24,
          ];
          final nextLeague = TrophyProgression.nextLeagueFor(trophies);
          final trophyLabel = nextLeague == null
              ? '$trophies'
              : '$trophies / ${nextLeague.min}';
          final progress = nextLeague == null
              ? 1.0
              : (trophies / nextLeague.min).clamp(0.0, 1.0);

          Widget button({
            required String id,
            required String label,
            required String asset,
            required VoidCallback onPressed,
            required int order,
            required Widget child,
            String? semanticLabel,
            HomeGuideTarget? target,
            bool onlineOnly = false,
            bool green = false,
            bool play = false,
            bool preserveCornerNotification = false,
            bool animateEntrance = true,
          }) =>
              KeyedSubtree(
                key: target == null ? null : guideTargets[target],
                child: SignInRequiredAction(
                  child: _SidebarArtButton(
                    key: ValueKey(id),
                    label: label,
                    semanticLabel: semanticLabel,
                    asset: asset,
                    onPressed: onPressed,
                    animation: animation,
                    order: order,
                    available: !onlineOnly || isOnline,
                    green: green,
                    play: play,
                    preserveCornerNotification: preserveCornerNotification,
                    animateEntrance: animateEntrance,
                    child: child,
                  ),
                ),
              );

          return Column(children: [
            SizedBox(
              height: heights[0],
              child: button(
                id: 'home-leaderboard-button',
                label: 'المتصدرون',
                semanticLabel: leaderboardRank == null
                    ? 'المتصدرون، الترتيب غير متاح'
                    : 'المتصدرون، ترتيبك العالمي $leaderboardRank',
                asset: leaderboardAsset,
                onPressed: onLeaderboard,
                order: 0,
                onlineOnly: true,
                child: LayoutBuilder(builder: (context, area) {
                  return Stack(children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            12, area.maxHeight * .23, area.maxWidth * .32, 5),
                        child: _SidebarWords('المتصدرون',
                            size: area.maxWidth * .110,
                            color: const Color(0xFFFFDB7B)),
                      ),
                    ),
                    Positioned(
                      left: area.maxWidth * 346 / 461,
                      top: area.maxHeight * 54 / 142,
                      width: area.maxWidth * 52 / 461,
                      height: area.maxHeight * 52 / 142,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(leaderboardRank?.toString() ?? '—',
                              key: const ValueKey('home-leaderboard-rank'),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Leaderboard',
                                  fontSize: area.maxWidth * .092,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4D3515))),
                        ),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: heights[1],
              child: Row(textDirection: TextDirection.ltr, children: [
                Expanded(
                  flex: 60,
                  child: button(
                    id: 'home-campaign-button',
                    target: HomeGuideTarget.campaign,
                    label: 'تحدي المراحل',
                    semanticLabel: campaignProgress == null
                        ? 'تحدي المراحل'
                        : 'تحدي المراحل، المرحلة ${campaignProgress!.reachedStage} من ${campaignProgress!.totalStages}',
                    asset: campaignAsset,
                    onPressed: onCampaign,
                    order: 1,
                    onlineOnly: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 8, 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _SidebarWords('تحدي المراحل', size: 27),
                            const SizedBox(height: 3),
                            _SidebarWords(campaignProgress?.label ?? '…',
                                key: const ValueKey('home-campaign-progress'),
                                size: 20,
                                textDirection: TextDirection.ltr,
                                color: const Color(0xFFFFDB98)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 36,
                  child: KeyedSubtree(
                    key: guideTargets[HomeGuideTarget.offer],
                    child: _RotatingPromotionSlot(
                      enabled: rotatePromotions,
                      onVip: onVip,
                      onLuckyWheel: onLuckyWheel,
                      builder: (wheel, activate) => button(
                        id: wheel ? 'home-wheel-button' : 'home-vip-button',
                        label: wheel ? 'دولاب الحظ' : 'نادي الأبطال',
                        asset: wheel ? luckyWheelAsset : vipAsset,
                        onPressed: activate,
                        order: 2,
                        onlineOnly: true,
                        animateEntrance: false,
                        child: LayoutBuilder(builder: (context, area) {
                          return Stack(children: [
                            if (!wheel)
                              Positioned(
                                left: area.maxWidth * 157 / 434,
                                top: area.maxHeight * 174 / 476,
                                width: area.maxWidth * 120 / 434,
                                height: area.maxHeight * 80 / 476,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('VIP',
                                        key: const ValueKey('home-vip-label'),
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontFamily: 'Leaderboard',
                                            fontSize: area.maxWidth * .17,
                                            height: 1,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF553A11))),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 5,
                              right: 5,
                              top: area.maxHeight * (wheel ? .66 : .62),
                              bottom: area.maxHeight * (wheel ? .12 : .10),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                    wheel ? 'دولاب الحظ' : 'نادي\nالأبطال',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 24,
                                        height: 1.05,
                                        fontWeight: FontWeight.w900,
                                        color: !wheel && isVip
                                            ? const Color(0xFFFFDF88)
                                            : Colors.white,
                                        shadows: const [
                                          Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4,
                                              offset: Offset(0, 2))
                                        ])),
                              ),
                            ),
                          ]);
                        }),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: heights[2],
              child: button(
                id: 'home-modes-button',
                target: HomeGuideTarget.modes,
                label: 'أوضاع اللعب',
                asset: modesAsset,
                onPressed: onModes,
                order: 3,
                child: LayoutBuilder(builder: (context, area) {
                  return Stack(children: [
                    Positioned.fill(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(14, 7, area.maxWidth * .33, 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('أوضاع اللعب',
                                  style: TextStyle(
                                      fontSize: area.maxWidth * .096,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              Row(textDirection: TextDirection.ltr, children: [
                                const Icon(Icons.emoji_events_rounded,
                                    size: 20, color: Color(0xFFF8D38D)),
                                const SizedBox(width: 6),
                                Text(trophyLabel,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                        fontSize: area.maxWidth * .075,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFF4E5CD))),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: LinearProgressIndicator(
                          key: const ValueKey('home-trophy-progress'),
                          value: progress,
                          backgroundColor: const Color(0xFF4D4C43),
                          color: const Color(0xFFF5D08E),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: heights[3],
              child: button(
                id: 'home-friends-shortcut',
                target: HomeGuideTarget.friends,
                label: 'الأصدقاء واللاعبون',
                asset: friendsAsset,
                onPressed: onFriends,
                order: 4,
                onlineOnly: true,
                green: true,
                preserveCornerNotification: true,
                child: LayoutBuilder(builder: (context, area) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 15, 7),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _SidebarWords('الأصدقاء',
                          size: area.maxWidth * .080,
                          color: const Color(0xFFB6E58C)),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: heights[4],
              child: button(
                id: 'home-play-button',
                target: HomeGuideTarget.play,
                label: 'العب',
                asset: playAsset,
                onPressed: onPlay,
                order: 5,
                onlineOnly: true,
                green: true,
                play: true,
                child: LayoutBuilder(builder: (context, area) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 8),
                      child: _SidebarWords('العب', size: area.maxWidth * .17),
                    ),
                  );
                }),
              ),
            ),
          ]);
        }),
      );
}

/// Keeps both destinations in one stable slot without swapping under a press.
class _RotatingPromotionSlot extends StatefulWidget {
  const _RotatingPromotionSlot({
    required this.enabled,
    required this.onVip,
    required this.onLuckyWheel,
    required this.builder,
  });

  final bool enabled;
  final VoidCallback onVip, onLuckyWheel;
  final Widget Function(bool wheel, VoidCallback activate) builder;

  @override
  State<_RotatingPromotionSlot> createState() => _RotatingPromotionSlotState();
}

class _RotatingPromotionSlotState extends State<_RotatingPromotionSlot>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _wheel = false;
  bool _visible = false;
  bool _hovered = false;
  bool _focused = false;
  int _pointers = 0;
  late AppLifecycleState _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.of(context) && ModalRoute.of(context)?.isCurrent != false;
    _syncTimer();
  }

  @override
  void didUpdateWidget(_RotatingPromotionSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _wheel = false;
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncTimer();
  }

  void _syncTimer() {
    final active = widget.enabled &&
        _visible &&
        _lifecycle == AppLifecycleState.resumed &&
        !_hovered &&
        !_focused &&
        _pointers == 0;
    if (active) {
      _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _wheel = !_wheel);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _activate(bool wheel) {
    if (_wheel != wheel) return;
    (wheel ? widget.onLuckyWheel : widget.onVip)();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wheel = _wheel;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) {
        _hovered = true;
        _syncTimer();
      },
      onExit: (_) {
        _hovered = false;
        _syncTimer();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          _focused = focused;
          _syncTimer();
        },
        child: Listener(
          onPointerDown: (_) {
            _pointers++;
            _syncTimer();
          },
          onPointerUp: (_) {
            _pointers = math.max(0, _pointers - 1);
            _syncTimer();
          },
          onPointerCancel: (_) {
            _pointers = math.max(0, _pointers - 1);
            _syncTimer();
          },
          child: AnimatedSwitcher(
            duration: Duration(
                milliseconds: reducedMotion || !widget.enabled ? 0 : 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [
                for (final child in previous)
                  IgnorePointer(
                      child:
                          ExcludeFocus(child: ExcludeSemantics(child: child))),
                if (current != null) current,
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey(wheel),
              child: widget.builder(wheel, () => _activate(wheel)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarWords extends StatelessWidget {
  const _SidebarWords(this.text,
      {super.key,
      this.size = 28,
      this.color = Colors.white,
      this.textDirection = TextDirection.rtl});
  final String text;
  final double size;
  final Color color;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(text,
            maxLines: 1,
            textDirection: textDirection,
            style: TextStyle(
                fontSize: size,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: color,
                shadows: const [
                  Shadow(
                      color: Colors.black45,
                      blurRadius: 3,
                      offset: Offset(0, 2))
                ])),
      );
}

class _SidebarArtButton extends StatefulWidget {
  const _SidebarArtButton({
    super.key,
    required this.label,
    required this.asset,
    required this.onPressed,
    required this.animation,
    required this.order,
    required this.available,
    required this.green,
    required this.play,
    required this.child,
    this.semanticLabel,
    this.preserveCornerNotification = false,
    this.animateEntrance = true,
  });
  final String label, asset;
  final String? semanticLabel;
  final VoidCallback onPressed;
  final Animation<double> animation;
  final int order;
  final bool available, green, play;
  final bool preserveCornerNotification;
  final bool animateEntrance;
  final Widget child;

  @override
  State<_SidebarArtButton> createState() => _SidebarArtButtonState();
}

class _SidebarArtButtonState extends State<_SidebarArtButton> {
  bool _hovered = false, _focused = false, _pressed = false;

  // Hue rotation keeps the dark centers neutral while turning gold into green.
  static const _greenFilter = ColorFilter.matrix([
    .422,
    -.262,
    .840,
    0,
    0,
    .230,
    .979,
    -.209,
    0,
    0,
    -.575,
    .977,
    .598,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  void _activate() {
    AppSettings.playClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final animated = !reducedMotion && TickerMode.of(context);
    final active = _hovered || _focused;
    final accent =
        widget.green ? const Color(0xFFAAEF80) : const Color(0xFFFFDC8E);
    final source = adaptiveAssetImage(widget.asset,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true);
    Widget artwork = source;
    if (widget.green) {
      artwork = ColorFiltered(colorFilter: _greenFilter, child: artwork);
    }
    final content = RepaintBoundary(
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: artwork),
        if (widget.preserveCornerNotification)
          Positioned.fill(
            child: ClipRect(
              key: const ValueKey('home-friends-notification-dot'),
              clipper: const _NotificationCornerClipper(),
              child: source,
            ),
          ),
        Positioned.fill(
          child: AnimatedContainer(
            duration: Duration(milliseconds: reducedMotion ? 0 : 160),
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: .07) : null,
              border: active ? Border.all(color: accent, width: 1.5) : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: accent.withValues(alpha: .22), blurRadius: 12)
                    ]
                  : null,
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
        if (widget.play)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PlayFramePainter(
                    animation: widget.animation, animated: animated),
              ),
            ),
          ),
      ]),
    );
    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      hint: widget.available ? null : 'يتطلب اتصالاً بالإنترنت',
      onTap: _activate,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              _activate();
              return null;
            }),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: _activate,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: reducedMotion || !widget.animateEntrance ? 1 : 0,
                  end: 1),
              duration: Duration(
                  milliseconds: reducedMotion || !widget.animateEntrance
                      ? 0
                      : 400 + widget.order * 65),
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                scale:
                    reducedMotion ? 1 : (_pressed ? .97 : (active ? 1.012 : 1)),
                duration: Duration(milliseconds: reducedMotion ? 0 : 140),
                curve: Curves.easeOutCubic,
                child: Opacity(
                    opacity: widget.available ? 1 : .78, child: content),
              ),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                    offset: Offset((1 - value) * 14, 0), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Retains the supplied red notification without tinting it with the banner.
class _NotificationCornerClipper extends CustomClipper<Rect> {
  const _NotificationCornerClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * .95, 0, size.width, size.height * .24);

  @override
  bool shouldReclip(_NotificationCornerClipper oldClipper) => false;
}

/// Draws only the play frame and its light, so labels stay crisp and steady.
class _PlayFramePainter extends CustomPainter {
  _PlayFramePainter({required this.animation, required this.animated})
      : super(repaint: animated ? animation : null);
  final Animation<double> animation;
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animated ? animation.value : 0.0;
    final pulse = animated ? .5 + math.sin(t * math.pi * 2) * .5 : .35;
    final frame = Rect.fromLTWH(
        5, 5, math.max(0, size.width - 10), math.max(0, size.height - 10));
    const green = Color(0xFFADFF7A);
    canvas.drawRect(
        frame,
        Paint()
          ..color = green.withValues(alpha: .18 + pulse * .20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawRect(
        frame,
        Paint()
          ..color = green.withValues(alpha: .40 + pulse * .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    if (!animated) return;

    // A short highlight travels around the rectangular frame.
    final path = Path()..addRect(frame);
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final start = t * length;
    final end = start + length * .13;
    void trace(double from, double to) {
      final section = metric.extractPath(from, to);
      canvas.drawPath(
          section,
          Paint()
            ..color = green.withValues(alpha: .75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(
          section,
          Paint()
            ..color = const Color(0xFFE6FFD1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }

    trace(start, math.min(end, length));
    if (end > length) trace(0, end - length);

    // One soft sweep per animation cycle, clipped inside the existing frame.
    final sweep = ((t - .25) / .40).clamp(0.0, 1.0);
    if (sweep > 0 && sweep < 1) {
      canvas.save();
      canvas.clipRect(frame.deflate(3));
      final x = -size.width * .3 + sweep * size.width * 1.6;
      canvas.translate(x, size.height / 2);
      canvas.rotate(-.35);
      final band = Rect.fromLTWH(-24, -size.height * 1.5, 48, size.height * 3);
      canvas.drawRect(
          band,
          Paint()
            ..shader = LinearGradient(colors: [
              Colors.white.withValues(alpha: 0),
              const Color(0xFFE5FFD6).withValues(alpha: .08),
              Colors.white.withValues(alpha: 0)
            ], begin: Alignment.centerLeft, end: Alignment.centerRight)
                .createShader(band));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PlayFramePainter oldDelegate) =>
      animation != oldDelegate.animation || animated != oldDelegate.animated;
}
