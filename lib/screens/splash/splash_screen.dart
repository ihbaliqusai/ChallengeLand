import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays the local intro once while the startup gate prepares the application.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  late final VideoPlayerController _video;
  Timer? _playbackDeadline;
  Timer? _fallbackTimer;
  Timer? _initializationDeadline;
  bool _videoReady = false;
  bool _finished = false;
  bool _failed = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _video = VideoPlayerController.asset(
      'assets/videos/splashscreen.mp4',
      // Lifecycle is managed here so the watchdog also pauses in the background.
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    )..addListener(_onVideoChanged);
    _initializationDeadline = Timer(const Duration(seconds: 5), () {
      _usePoster('Video initialization timed out');
    });
    unawaited(_initializeVideo());
  }

  Future<void> _initializeVideo() async {
    try {
      await _video.initialize();
      _initializationDeadline?.cancel();
      if (!mounted || _finished || _failed) return;
      setState(() => _videoReady = true);
      if (_foreground) await _play();
    } catch (error) {
      _usePoster(error);
    }
  }

  Future<void> _play() async {
    try {
      await _video.play();
      if (!mounted || _finished || _failed || !_foreground) return;
      // A stalled decoder must never trap the player on the intro screen.
      _playbackDeadline?.cancel();
      final remaining = _video.value.duration - _video.value.position;
      _playbackDeadline =
          Timer(remaining + const Duration(seconds: 3), _finish);
    } catch (error) {
      _usePoster(error);
    }
  }

  void _onVideoChanged() {
    if (!mounted || _finished || _failed) return;
    if (_video.value.hasError) {
      _usePoster(_video.value.errorDescription);
    } else if (_video.value.isCompleted) {
      _finish();
    }
  }

  void _usePoster(Object? error) {
    if (!mounted || _finished || _failed) return;
    debugPrint('[Splash] Video unavailable; using poster: $error');
    _initializationDeadline?.cancel();
    _playbackDeadline?.cancel();
    setState(() {
      _failed = true;
      _videoReady = false;
    });
    unawaited(_pause());
    _fallbackTimer = Timer(const Duration(milliseconds: 1200), _finish);
  }

  Future<void> _pause() async {
    try {
      await _video.pause();
    } catch (_) {
      // The player may already be unavailable after a platform error.
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _playbackDeadline?.cancel();
    _fallbackTimer?.cancel();
    _initializationDeadline?.cancel();
    setState(() => _finished = true);
    unawaited(_pause());
    widget.onComplete?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _playbackDeadline?.cancel();
      unawaited(_pause());
    } else if (_videoReady && !_finished && !_failed) {
      unawaited(_play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackDeadline?.cancel();
    _fallbackTimer?.cancel();
    _initializationDeadline?.cancel();
    _video.removeListener(_onVideoChanged);
    unawaited(_video.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SplashPoster(),
            if (_videoReady)
              ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: VideoPlayer(_video),
                  ),
                ),
              ),
          ],
        ),
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
        'assets/ui/splash_poster.webp',
        fit: BoxFit.cover,
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
