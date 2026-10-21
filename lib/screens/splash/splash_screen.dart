import 'dart:async';

import 'package:flutter/material.dart';

/// Displays the game splash screen with the desert challenge artwork and
/// an adventure-styled golden loading bar while account and assets prepare.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2400),
  });

  final VoidCallback? onComplete;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  late final AnimationController _shimmerController;
  Timer? _watchdogTimer;
  bool _finished = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });

    if (_foreground) {
      _progressController.forward();
      _shimmerController.repeat();
      _armWatchdog();
    }
  }

  void _armWatchdog() {
    _watchdogTimer?.cancel();
    final remaining = widget.duration * (1.0 - _progressController.value);
    _watchdogTimer = Timer(remaining + const Duration(seconds: 2), _finish);
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    _watchdogTimer?.cancel();
    widget.onComplete?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _watchdogTimer?.cancel();
      if (_progressController.isAnimating) {
        _progressController.stop();
      }
      if (_shimmerController.isAnimating) {
        _shimmerController.stop();
      }
    } else if (!_finished) {
      _progressController.forward();
      _shimmerController.repeat();
      _armWatchdog();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= 0 || media.size.height <= 0) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SplashPoster(),
      );
    }

    final bottomPadding = (media.padding.bottom + 26.0).clamp(22.0, 48.0);
    final barMaxWidth = (media.size.width * 0.48).clamp(280.0, 440.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SplashPoster(),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            child: Center(
              child: SizedBox(
                width: barMaxWidth,
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_progressAnimation, _shimmerController]),
                  builder: (context, _) {
                    return SplashLoadingBar(
                      progress: _progressAnimation.value,
                      shimmerValue: _shimmerController.value,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The matching first frame covers platform startup and decoder initialization.
class SplashPoster extends StatelessWidget {
  const SplashPoster({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox.expand(
      child: Image.asset(
        'assets/ui/splash.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        cacheWidth:
            (media.size.width * media.devicePixelRatio).ceil().clamp(1, 1920),
        cacheHeight: (media.size.width * media.devicePixelRatio * 9 / 16)
            .ceil()
            .clamp(1, 1080),
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Stylized desert-adventure progress bar with golden glow, bevel framing,
/// glossy highlight, and animated active light sweep.
class SplashLoadingBar extends StatelessWidget {
  const SplashLoadingBar({
    super.key,
    required this.progress,
    required this.shimmerValue,
  });

  final double progress;
  final double shimmerValue;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with Arabic title and percentage counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'جاري تجهيز التحديات...',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8E7),
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1.5),
                      blurRadius: 4,
                    ),
                    Shadow(
                      color: Color(0x99FFA000),
                      offset: Offset(0, 0),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFE082),
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Outer ornate frame with bronze and gold border
        Container(
          height: 19,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5D4037),
                Color(0xFF2E1A0F),
                Color(0xFF1B0D06),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD54F),
              width: 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFB300),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
              BoxShadow(
                color: Colors.black87,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Inset track background
                Container(
                  color: const Color(0xFF100904),
                ),
                // Active progress fill
                if (progress > 0.005)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Core rich gold/amber gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFE65100),
                                Color(0xFFFFA000),
                                Color(0xFFFFD54F),
                                Color(0xFFFFF9C4),
                              ],
                            ),
                          ),
                        ),
                        // Upper half glossy reflection
                        Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: 0.45,
                            widthFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.55),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Animated shimmer beam
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              if (width <= 0) return const SizedBox.shrink();
                              final beamX = (shimmerValue * (width + 60)) - 30;
                              return Transform.translate(
                                offset: Offset(beamX, 0),
                                child: Container(
                                  width: 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.55),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Glowing leading edge point
                        if (progress > 0.04)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 6,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFFFFF),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFFF9C4),
                                    blurRadius: 5,
                                    spreadRadius: 1.5,
                                  ),
                                  BoxShadow(
                                    color: Color(0xFFFFB300),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
