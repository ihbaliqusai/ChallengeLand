import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/performance_probe.dart';
import 'home_artwork.dart';

/// Home-only background; character/gameplay decoders remain independent.
class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, this.child});
  final Widget? child;

  Widget _build(String mode) => switch (mode) {
        'video' => _VideoHomeBackground(child: child),
        _ => Stack(fit: StackFit.expand, children: [
            RepaintBoundary(
                child: Image.asset(HomeArtwork.background,
                    fit: BoxFit.cover, cacheWidth: 1280)),
            if (child != null) child!,
          ]),
      };

  @override
  Widget build(BuildContext context) {
    if (!PerformanceProbe.enabled) {
      return _build(PerformanceProbe.defaultBackground);
    }
    return ValueListenableBuilder<String>(
      valueListenable: PerformanceProbe.background,
      builder: (_, mode, __) => _build(mode),
    );
  }
}

class _VideoHomeBackground extends StatefulWidget {
  const _VideoHomeBackground({this.child});
  final Widget? child;
  @override
  State<_VideoHomeBackground> createState() => _VideoHomeBackgroundState();
}

class _VideoHomeBackgroundState extends State<_VideoHomeBackground>
    with WidgetsBindingObserver {
  static const _factory = MethodChannel('challengeland/home-background');
  MethodChannel? _session;
  int? _texture;
  int _generation = 0;
  bool _creating = false;
  bool _ready = false;
  bool _failed = false;
  bool _active = true;
  bool _paused = false;
  bool _firstFrameShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    // Reveal the complete static home before asking Android for a decoder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrameShown = true;
      if (mounted) _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    _paused = !_active || !TickerMode.of(context) || reduced;
    if (_firstFrameShown) _sync();
  }

  void _sync() {
    if (_failed || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _paused = !_active ||
        !TickerMode.of(context) ||
        MediaQuery.disableAnimationsOf(context);
    if (_session != null) {
      unawaited(_invoke(_session!, 'setPaused', _paused));
    } else if (!_creating && !_paused) {
      unawaited(_create());
    }
  }

  Future<void> _invoke(MethodChannel session, String method,
      [Object? arguments]) async {
    try {
      await session.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Retain the static poster on unsupported decoders/native hosts.
    } on MissingPluginException {
      // Widget tests and desktop builds have no Android video bridge.
    }
  }

  Future<void> _create() async {
    _creating = true;
    final generation = ++_generation;
    MethodChannel? session;
    try {
      final texture = await _factory.invokeMethod<int>('create');
      if (texture == null) throw PlatformException(code: 'NO_TEXTURE');
      session = MethodChannel('challengeland/home-background/$texture');
      if (!mounted || generation != _generation) {
        await _invoke(session, 'dispose');
        return;
      }
      _session = session;
      _texture = texture;
      session.setMethodCallHandler((call) async {
        if (!mounted || generation != _generation) return;
        if (call.method == 'ready') {
          PerformanceProbe.mark('home.video.ready');
          setState(() => _ready = true);
        } else if (call.method == 'failed') {
          _stop();
          setState(() => _failed = true);
        }
      });
      await session.invokeMethod<void>('start', _paused);
    } on PlatformException {
      if (session != null) await _invoke(session, 'dispose');
      if (mounted && generation == _generation) {
        _stop();
        setState(() => _failed = true);
      }
    } on MissingPluginException {
      if (session != null) await _invoke(session, 'dispose');
      if (mounted && generation == _generation) {
        _stop();
        setState(() => _failed = true);
      }
    } finally {
      if (generation == _generation) _creating = false;
    }
  }

  void _stop() {
    _generation++;
    final session = _session;
    _session = null;
    _texture = null;
    _ready = false;
    _creating = false;
    if (session != null) {
      session.setMethodCallHandler(null);
      unawaited(_invoke(session, 'dispose'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: _ready && _texture != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 960,
                      height: 540,
                      child: Texture(textureId: _texture!),
                    ),
                  )
                : Image.asset(HomeArtwork.background,
                    fit: BoxFit.cover, cacheWidth: 1280),
          ),
          if (widget.child != null) widget.child!,
        ],
      );
}
