import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_character.dart';
import '../services/native_bridge_service.dart';

/// Displays the chosen contestant using the native game's existing idle loop.
class HomeCharacterArtwork extends StatefulWidget {
  const HomeCharacterArtwork({super.key, required this.character});

  final GameCharacter character;

  @override
  State<HomeCharacterArtwork> createState() => _HomeCharacterArtworkState();
}

class _HomeCharacterArtworkState extends State<HomeCharacterArtwork> {
  Future<Uint8List?>? _artwork;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _artwork ??= context
        .read<NativeBridgeService>()
        .getCharacterArtwork(widget.character.index);
  }

  @override
  void didUpdateWidget(HomeCharacterArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.index != widget.character.index) {
      _artwork = context
          .read<NativeBridgeService>()
          .getCharacterArtwork(widget.character.index);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'الشخصية المختارة: ${widget.character.nameAr}',
        excludeSemantics: true,
        child: _withAnimation(FutureBuilder<Uint8List?>(
          key: ValueKey(widget.character.index),
          future: _artwork,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            // The roster asset is only a face portrait. Stretching it into the
            // hero area causes a large face to flash before the native art loads.
            const placeholder =
                SizedBox.expand(key: ValueKey('home-character-placeholder'));
            if (bytes == null) return placeholder;
            return LayoutBuilder(builder: (context, area) {
              final decodeHeight =
                  (area.maxHeight * MediaQuery.devicePixelRatioOf(context))
                      .ceil()
                      .clamp(1, 2390);
              return Image.memory(bytes,
                  key: ValueKey('home-character-${widget.character.id}'),
                  fit: BoxFit.contain,
                  cacheHeight: decodeHeight,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => placeholder);
            });
          },
        )),
      );

  Widget _withAnimation(Widget fallback) {
    if (!context.read<NativeBridgeService>().supportsAnimatedCharacters ||
        MediaQuery.disableAnimationsOf(context)) {
      return fallback;
    }
    return _AnimatedContestant(
        key: ValueKey('animated-${widget.character.index}'),
        index: widget.character.index,
        fallback: fallback);
  }
}

class _AnimatedContestant extends StatefulWidget {
  const _AnimatedContestant(
      {super.key, required this.index, required this.fallback});
  final int index;
  final Widget fallback;
  @override
  State<_AnimatedContestant> createState() => _AnimatedContestantState();
}

class _AnimatedContestantState extends State<_AnimatedContestant> {
  MethodChannel? _channel;
  bool _ready = false;
  bool _paused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paused = !TickerMode.of(context);
    _setPaused();
  }

  Future<void> _setPaused() async {
    try {
      await _channel?.invokeMethod<void>('setPaused', _paused);
    } on PlatformException {
      // Native disposal may race a route transition.
    } on MissingPluginException {
      // The platform view has already been disposed.
    }
  }

  void _created(int id) {
    _channel = MethodChannel('challengeland/home-character/$id');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'ready' && mounted) setState(() => _ready = true);
    });
    _setPaused();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        if (!_ready) Positioned.fill(child: widget.fallback),
        Positioned.fill(
            key: const ValueKey('home-native-animation'),
            child: Center(
                child: AspectRatio(
              aspectRatio: 720 / 1280,
              child: PlatformViewLink(
                viewType: 'challengeland/home-character',
                surfaceFactory: (context, controller) => AndroidViewSurface(
                    controller: controller as AndroidViewController,
                    gestureRecognizers: const <Factory<
                        OneSequenceGestureRecognizer>>{},
                    hitTestBehavior: PlatformViewHitTestBehavior.transparent),
                onCreatePlatformView: (params) =>
                    PlatformViewsService.initExpensiveAndroidView(
                  id: params.id,
                  viewType: 'challengeland/home-character',
                  layoutDirection: TextDirection.ltr,
                  creationParams: {'index': widget.index, 'paused': _paused},
                  creationParamsCodec: const StandardMessageCodec(),
                  onFocus: () => params.onFocusChanged(true),
                )
                      ..addOnPlatformViewCreatedListener(
                          params.onPlatformViewCreated)
                      ..addOnPlatformViewCreatedListener(_created)
                      ..create(),
              ),
            ))),
      ]);
}
