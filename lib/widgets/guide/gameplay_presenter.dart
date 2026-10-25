import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Supported presenter body gestures matching `Person.java`.
enum PresenterGesture {
  /// Open hand gesturing towards the side (points towards button/target).
  showHand,

  /// The native open-hand gesture with the hand closed at its final frame.
  showHandGrip,

  /// Both hands open gesturing towards the user.
  show2Hands,

  /// Thumbs-up / celebration like gesture.
  like,

  /// Pointing towards big screen.
  showScreen,

  /// Idle resting hands down.
  idle,
}

/// Controller to trigger presenter actions programmatically.
class GameplayPresenterController extends ChangeNotifier {
  PresenterGesture _gesture = PresenterGesture.showHand;
  bool _isTalking = true;
  bool _isBlinking = false;
  bool _eyebrowsUp = false;
  bool _lookingAside = false;
  bool _disposed = false;
  Timer? _blinkReset;
  Timer? _eyebrowReset;
  Timer? _lookAsideReset;

  PresenterGesture get gesture => _gesture;
  bool get isTalking => _isTalking;
  bool get isBlinking => _isBlinking;
  bool get eyebrowsUp => _eyebrowsUp;
  bool get lookingAside => _lookingAside;

  void setGesture(PresenterGesture gesture) {
    if (!_disposed && _gesture != gesture) {
      _gesture = gesture;
      notifyListeners();
    }
  }

  void setTalking(bool talking) {
    if (!_disposed && _isTalking != talking) {
      _isTalking = talking;
      notifyListeners();
    }
  }

  void blink() {
    if (_disposed) return;
    _blinkReset?.cancel();
    _isBlinking = true;
    notifyListeners();
    _blinkReset = Timer(const Duration(milliseconds: 50), () {
      _isBlinking = false;
      notifyListeners();
    });
  }

  void raiseEyebrows([int durationMs = 300]) {
    if (_disposed) return;
    _eyebrowReset?.cancel();
    _eyebrowsUp = true;
    notifyListeners();
    _eyebrowReset = Timer(Duration(milliseconds: durationMs), () {
      _eyebrowsUp = false;
      notifyListeners();
    });
  }

  void lookAside([int durationMs = 600]) {
    if (_disposed) return;
    _lookAsideReset?.cancel();
    _lookingAside = true;
    notifyListeners();
    _lookAsideReset = Timer(Duration(milliseconds: durationMs), () {
      _lookingAside = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _blinkReset?.cancel();
    _eyebrowReset?.cancel();
    _lookAsideReset?.cancel();
    super.dispose();
  }
}

/// Animated 2D composite presenter replicating the native gameplay host (`Person.java`).
///
/// Features:
/// - Precise native layout & proportions (208 x 141 dp base canvas).
/// - Lip-sync mouth animation cycling mouth_01 -> mouth_02 -> mouth_03 while talking.
/// - Full body hand gestures matching `Person.java` (02 -> 03 -> 04 -> 05 -> 06).
/// - Periodic natural eye blinking and eyebrow movement.
/// - Subtle idle breathing & head bobbing.
/// - Horizontal flip support (default `true` so outstretched hand points to right).
class GameplayPresenter extends StatefulWidget {
  const GameplayPresenter({
    super.key,
    this.height = 160.0,
    this.isTalking = true,
    this.gesture = PresenterGesture.showHand,
    this.isFlipped = true,
    this.enableBlinking = true,
    this.enableEyebrows = true,
    this.enableBreathing = true,
    this.controller,
  });

  static const nativeSize = Size(208, 141);
  static const nativeHeadCenter = Offset(118.2, 56.5);

  /// Overall display height of the character (proportions are locked to 208:141).
  final double height;

  /// Whether character mouth is animating lip-sync talk.
  final bool isTalking;

  /// Hand/body gesture pose.
  final PresenterGesture gesture;

  /// Flip horizontally. If true (default), the gesturing hand points to the right.
  final bool isFlipped;

  /// Enable periodic natural eye blinks.
  final bool enableBlinking;

  /// Enable periodic eyebrow emphasis.
  final bool enableEyebrows;

  /// Enable subtle breathing physics / idle float.
  final bool enableBreathing;

  /// Optional controller to manipulate presenter from external state.
  final GameplayPresenterController? controller;

  @override
  State<GameplayPresenter> createState() => _GameplayPresenterState();
}

class _GameplayPresenterState extends State<GameplayPresenter>
    with SingleTickerProviderStateMixin {
  // Reference dimensions from Android activity_game_series.xml
  static const double _kNativeWidth = 208.0;
  static const double _kNativeHeight = 141.0;

  static const List<String> _kPrecacheAssets = [
    'assets/presenter/head.png',
    'assets/presenter/closed_eyes.png',
    'assets/presenter/eyebrows_up_left.png',
    'assets/presenter/eyebrows_up_right.png',
    'assets/presenter/look_aside.png',
    'assets/presenter/mouth_01.png',
    'assets/presenter/mouth_02.png',
    'assets/presenter/mouth_03.png',
    'assets/presenter/mouth_04.png',
    'assets/presenter/mouth_05.png',
    'assets/presenter/mouth_06.png',
    'assets/presenter/person_01.png',
    'assets/presenter/person_02.png',
    'assets/presenter/person_03.png',
    'assets/presenter/person_04.png',
    'assets/presenter/person_05.png',
    'assets/presenter/person_06.png',
    'assets/presenter/person_07.png',
    'assets/presenter/person_08.png',
    'assets/presenter/person_09.png',
    'assets/presenter/person_10.png',
    'assets/presenter/podiumhost.png',
  ];

  static bool _didPrecache = false;

  // Animation controller for breathing / idle motion
  late AnimationController _breathingController;

  // Mouth frame: 1, 2, 3 while talking; 5 when silent (smile)
  int _mouthFrame = 5;
  Timer? _talkTimer;

  // Body frame: 2 (idle), 3, 4, 5, 6 (showHand), 8 (show2Hands), 10 (like)
  int _bodyFrame = 2;
  Timer? _gestureTimer;
  Timer? _speechPulseTimer;
  Timer? _lowerHandTimer;

  // Eye blinking state
  bool _isBlinking = false;
  Timer? _blinkTimer;
  Timer? _blinkResetTimer;

  // Eyebrow state
  bool _eyebrowsUp = false;
  Timer? _eyebrowTimer;
  Timer? _eyebrowResetTimer;
  bool? _lastTalking;
  PresenterGesture? _lastGesture;

  final math.Random _random = math.Random();

  bool get _effectiveTalking =>
      widget.controller?.isTalking ?? widget.isTalking;

  PresenterGesture get _effectiveGesture =>
      widget.controller?.gesture ?? widget.gesture;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }

    widget.controller?.addListener(_onControllerUpdate);

    _syncFromSource();
    _scheduleNextBlink();
    _scheduleNextEyebrow();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      for (final path in _kPrecacheAssets) {
        precacheImage(
          AssetImage(path),
          context,
          onError: (_, __) {},
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant GameplayPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enableBreathing != widget.enableBreathing) {
      if (widget.enableBreathing) {
        _breathingController.repeat(reverse: true);
      } else {
        _breathingController.stop();
        _breathingController.value = 0.0;
      }
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }
    _syncFromSource();
    if (oldWidget.enableBlinking != widget.enableBlinking) {
      _blinkResetTimer?.cancel();
      _isBlinking = false;
      _scheduleNextBlink();
    }
    if (oldWidget.enableEyebrows != widget.enableEyebrows) {
      _eyebrowResetTimer?.cancel();
      _eyebrowsUp = false;
      _scheduleNextEyebrow();
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    _syncFromSource();
    // Eye and eyebrow notifications redraw without restarting speech or hands.
    setState(() {});
  }

  void _syncFromSource() {
    final gesture = _effectiveGesture;
    final talking = _effectiveTalking;
    if (_lastGesture != gesture) {
      _lastGesture = gesture;
      _syncGesture(gesture, animate: true);
    }
    if (_lastTalking != talking) {
      _lastTalking = talking;
      _syncTalking(talking);
    }
  }

  void _syncTalking(bool talking) {
    _talkTimer?.cancel();
    _speechPulseTimer?.cancel();
    _lowerHandTimer?.cancel();

    if (!talking) {
      _mouthFrame = 5; // closed smiling mouth
      if (mounted) setState(() {});

      // When talking stops, after 1000ms relax the hand down to idle
      _lowerHandTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted || _effectiveTalking) return;
        _syncGesture(PresenterGesture.idle, animate: true);
      });
      return;
    }

    // When speech starts, immediately raise hand up to gesture!
    _syncGesture(_effectiveGesture, animate: true);
    _mouthFrame = 1;
    if (mounted) setState(() {});

    // Loop matching Person.java: mouth_02 -> mouth_03 -> mouth_01 every 100ms
    const mouthCycle = [2, 3, 1];
    var cycleIndex = 0;
    _talkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _mouthFrame = mouthCycle[cycleIndex % mouthCycle.length];
        cycleIndex++;
      });
    });

    // While talking continues, perform subtle hand gesture emphasis every 2.4s
    _speechPulseTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted || !_effectiveTalking) return;
      _pulseHandGesture();
    });
  }

  void _pulseHandGesture() {
    if (_bodyFrame != 6) return;
    _gestureTimer?.cancel();
    final sequence = [5, 4, 5, 6];
    var step = 0;
    _gestureTimer = Timer.periodic(const Duration(milliseconds: 48), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (step < sequence.length) {
        setState(() {
          _bodyFrame = sequence[step];
        });
        step++;
      } else {
        timer.cancel();
      }
    });
  }

  void _syncGesture(PresenterGesture gesture, {bool animate = true}) {
    _gestureTimer?.cancel();

    int targetFrame;
    switch (gesture) {
      case PresenterGesture.showHand:
        targetFrame = 6;
        break;
      case PresenterGesture.showHandGrip:
        targetFrame = 9;
        break;
      case PresenterGesture.show2Hands:
        targetFrame = 8;
        break;
      case PresenterGesture.like:
        targetFrame = 10;
        break;
      case PresenterGesture.showScreen:
        targetFrame = 7;
        break;
      case PresenterGesture.idle:
        targetFrame = 2;
        break;
    }

    if (!animate) {
      _bodyFrame = targetFrame;
      if (mounted) setState(() {});
      return;
    }

    // Build frame progression sequence matching Person.java moveShowHand
    final sequence = <int>[];
    if (targetFrame == 6 || targetFrame == 9) {
      // Smooth hand rise: 2 -> 3 -> 4 -> 5 -> 6
      if (_bodyFrame == 2) {
        sequence.addAll([2, 3, 4, 5, targetFrame]);
      } else {
        sequence.addAll([3, 4, 5, targetFrame]);
      }
    } else if (targetFrame == 8) {
      sequence.addAll([2, 3, 4, 5, 6, 8]);
    } else if (targetFrame == 10) {
      sequence.addAll([2, 3, 10]);
    } else if (targetFrame == 7) {
      sequence.addAll([2, 3, 4, 5, 6, 7]);
    } else {
      // Returning to idle: 6 -> 5 -> 4 -> 3 -> 2
      if (_bodyFrame >= 6) {
        sequence.addAll([5, 4, 3, 2]);
      } else {
        sequence.add(2);
      }
    }

    var step = 0;
    final frameTime = targetFrame == 8
        ? 10
        : targetFrame == 10
            ? 40
            : 20;
    _gestureTimer = Timer.periodic(Duration(milliseconds: frameTime), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (step < sequence.length) {
        setState(() {
          _bodyFrame = sequence[step];
        });
        step++;
      } else {
        timer.cancel();
      }
    });
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (!widget.enableBlinking) return;

    // Blink every 2.8 - 4.5 seconds
    final delayMs = 2800 + _random.nextInt(1700);
    _blinkTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _isBlinking = true);

      // Person.blinkEyes closes for 50ms and spaces double blinks by 300ms.
      _blinkResetTimer = Timer(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        setState(() => _isBlinking = false);

        // 20% chance of a quick double-blink
        if (_random.nextDouble() < 0.22) {
          _blinkResetTimer = Timer(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            setState(() => _isBlinking = true);
            _blinkResetTimer = Timer(const Duration(milliseconds: 50), () {
              if (!mounted) return;
              setState(() => _isBlinking = false);
              _scheduleNextBlink();
            });
          });
        } else {
          _scheduleNextBlink();
        }
      });
    });
  }

  void _scheduleNextEyebrow() {
    _eyebrowTimer?.cancel();
    if (!widget.enableEyebrows) return;

    // Raise eyebrows occasionally (every 5-8 seconds) for dynamic personality
    final delayMs = 5000 + _random.nextInt(3500);
    _eyebrowTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _eyebrowsUp = true);

      _eyebrowResetTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        setState(() => _eyebrowsUp = false);
        _scheduleNextEyebrow();
      });
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _breathingController.dispose();
    _talkTimer?.cancel();
    _speechPulseTimer?.cancel();
    _lowerHandTimer?.cancel();
    _gestureTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkResetTimer?.cancel();
    _eyebrowTimer?.cancel();
    _eyebrowResetTimer?.cancel();
    super.dispose();
  }

  String _bodyAssetPath(int frame) {
    final numStr = frame < 10 ? '0$frame' : '$frame';
    return 'assets/presenter/person_$numStr.png';
  }

  String _mouthAssetPath(int frame) {
    final numStr = frame < 10 ? '0$frame' : '$frame';
    return 'assets/presenter/mouth_$numStr.png';
  }

  @override
  Widget build(BuildContext context) {
    // Proportional scaling factor based on the native 208x141 Android canvas
    final scale = widget.height / _kNativeHeight;
    final width = _kNativeWidth * scale;

    final isBlinking = (widget.controller?.isBlinking ?? false) || _isBlinking;
    final eyebrowsUp = (widget.controller?.eyebrowsUp ?? false) || _eyebrowsUp;

    final characterWidget = AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        // Subtle vertical breathing bob (±1.5px) and slight head tilt
        final bobY = widget.enableBreathing
            ? math.sin(_breathingController.value * math.pi * 2) * 1.5
            : 0.0;
        final tilt = widget.enableBreathing
            ? math.sin(_breathingController.value * math.pi * 2) * 0.012
            : 0.0;

        return Transform.translate(
          offset: Offset(0, bobY),
          child: SizedBox(
            width: width,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Body Sprite (person_01..10.png)
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 208.22 * scale,
                  height: 77.73 * scale,
                  child: Image.asset(
                    _bodyAssetPath(_bodyFrame),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

                // 2. Head Group (Rotates slightly with breathing)
                Positioned(
                  left: 71.2 * scale,
                  top: (_kNativeHeight - 28.5 - 112.0) * scale,
                  width: 94.0 * scale,
                  height: 112.0 * scale,
                  child: Transform.rotate(
                    angle: tilt,
                    alignment: const Alignment(0.0, 0.8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 2a. Base Head (head.png)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/presenter/head.png',
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                        // 2b. Animated Mouth (mouth_01..06.png)
                        Positioned(
                          left: 21.0 * scale,
                          top: 59.6 * scale,
                          width: 30.24 * scale,
                          height: 24.14 * scale,
                          child: Image.asset(
                            _mouthAssetPath(_mouthFrame),
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                        if (widget.controller?.lookingAside ?? false)
                          Positioned(
                            left: 14.0 * scale,
                            top: 38.0 * scale,
                            width: 45.0 * scale,
                            height: 17.0 * scale,
                            child: Image.asset(
                              'assets/presenter/look_aside.png',
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),

                        // 2c. Blinking Eyes (closed_eyes.png)
                        if (isBlinking)
                          Positioned(
                            left: 17.0 * scale,
                            top: 38.0 * scale,
                            width: 36.07 * scale,
                            height: 11.89 * scale,
                            child: Image.asset(
                              'assets/presenter/closed_eyes.png',
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),

                        // 2d. Raised Eyebrows Right (eyebrows_up_right.png)
                        if (eyebrowsUp) ...[
                          Positioned(
                            left: 14.4 * scale,
                            top: 31.0 * scale,
                            width: 20.08 * scale,
                            height: 11.07 * scale,
                            child: Image.asset(
                              'assets/presenter/eyebrows_up_right.png',
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),

                          // 2e. Raised Eyebrows Left (eyebrows_up_left.png)
                          Positioned(
                            left: 34.48 * scale,
                            top: 31.0 * scale,
                            width: 20.08 * scale,
                            height: 11.07 * scale,
                            child: Image.asset(
                              'assets/presenter/eyebrows_up_left.png',
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Apply horizontal flip if required (scaleX = -1 matching Android gameplay)
    if (widget.isFlipped) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: characterWidget,
      );
    }

    return characterWidget;
  }
}
