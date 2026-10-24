import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/character_video_bounds.dart';
import '../models/game_character.dart';
import '../services/native_bridge_service.dart';

typedef CharacterFrame = Widget Function(Key key, {bool reflected});

/// Both previews receive the same decoded video frame through separate output
/// textures. Independent texture identities keep differently sized/transformed
/// consumers from invalidating each other's cached image in the renderer.
class SynchronizedCharacterAnimation extends StatefulWidget {
  const SynchronizedCharacterAnimation({
    super.key,
    required this.character,
    required this.fallback,
    required this.builder,
  });

  final GameCharacter character;
  final CharacterFrame fallback;
  final Widget Function(BuildContext context, CharacterFrame frame) builder;

  @override
  State<SynchronizedCharacterAnimation> createState() =>
      _SynchronizedCharacterAnimationState();
}

class _SynchronizedCharacterAnimationState
    extends State<SynchronizedCharacterAnimation> {
  static const _factory = MethodChannel('challengeland/character-animation');
  MethodChannel? _session;
  int? _texture;
  int? _reflectionTexture;
  int _generation = 0;
  bool _creating = false;
  bool _ready = false;
  bool _paused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePlayback();
  }

  @override
  void didUpdateWidget(SynchronizedCharacterAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.character.index != oldWidget.character.index) _stop();
    _updatePlayback();
  }

  void _updatePlayback() {
    final supported =
        context.read<NativeBridgeService?>()?.supportsAnimatedCharacters ==
            true;
    if (!supported || MediaQuery.disableAnimationsOf(context)) {
      _stop();
      return;
    }
    final wasPaused = _paused;
    _paused = !TickerMode.of(context);
    if (_session != null) {
      if (_paused != wasPaused) {
        unawaited(_invoke(_session!, 'setPaused', _paused));
      }
    } else if (!_creating) {
      unawaited(_create());
    }
  }

  Future<void> _invoke(MethodChannel channel, String method,
      [Object? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Keep the artwork fallback if a renderer cannot be started.
    } on MissingPluginException {
      // Desktop previews and older native hosts use the artwork fallback.
    }
  }

  Future<void> _create() async {
    _creating = true;
    final generation = ++_generation;
    MethodChannel? session;
    try {
      final outputs = await _factory.invokeMapMethod<String, int>(
          'create', {'index': widget.character.index});
      final texture = outputs?['original'];
      final reflection = outputs?['reflection'];
      if (texture == null || reflection == null) return;
      session = MethodChannel('challengeland/character-animation/$texture');
      if (!mounted || generation != _generation) {
        await _invoke(session, 'dispose');
        return;
      }
      _session = session;
      _texture = texture;
      _reflectionTexture = reflection;
      session.setMethodCallHandler((call) async {
        if (call.method == 'ready' && mounted && generation == _generation) {
          setState(() => _ready = true);
        }
      });
      // Install the ready listener before starting the decoder.
      await session.invokeMethod<void>('start', {'paused': _paused});
    } on PlatformException {
      if (session != null) await _invoke(session, 'dispose');
      if (mounted && generation == _generation) _stop();
    } on MissingPluginException {
      if (session != null) await _invoke(session, 'dispose');
      if (mounted && generation == _generation) _stop();
    } finally {
      if (generation == _generation) _creating = false;
    }
  }

  void _stop() {
    _generation++;
    final session = _session;
    _session = null;
    _texture = null;
    _reflectionTexture = null;
    _ready = false;
    _creating = false;
    if (session != null) {
      session.setMethodCallHandler(null);
      unawaited(_invoke(session, 'dispose'));
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Widget _frame(Key key, {bool reflected = false}) {
    if (!_ready || _texture == null) {
      return widget.fallback(key, reflected: reflected);
    }
    final crop = characterVideoBounds[widget.character.id] ??
        const Rect.fromLTRB(0, 0, 1, 1);
    // Trim the black video canvas rather than squeezing that canvas into the
    // mirror. Keep the contestant's proportions and space for the whole loop.
    const source = Size(540, 960);
    return FittedBox(
      key: key,
      fit: BoxFit.contain,
      child: SizedBox(
        width: source.width * crop.width,
        height: source.height * crop.height,
        child: ClipRect(
          child: Stack(children: [
            Positioned(
              left: -source.width * crop.left,
              top: -source.height * crop.top,
              width: source.width,
              height: source.height,
              child: Texture(
                  textureId: reflected ? _reflectionTexture! : _texture!),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _frame);
}
