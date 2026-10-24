import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uses the same head, mouth frames, body and coordinates as the native game.
class GamePresenter extends StatefulWidget {
  const GamePresenter({super.key, this.message = ''});
  final String message;

  @override
  State<GamePresenter> createState() => _GamePresenterState();
}

class _GamePresenterState extends State<GamePresenter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Timer? _stopTalking;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speak();
  }

  @override
  void didUpdateWidget(GamePresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) _speak();
  }

  void _speak() {
    _stopTalking?.cancel();
    if (widget.message.isEmpty || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
      return;
    }
    _motion.repeat();
    _stopTalking = Timer(
      Duration(
        milliseconds: (widget.message.runes.length * 30).clamp(1600, 9000),
      ),
      () {
        if (!mounted) return;
        _motion.stop();
        _motion.value = 0;
      },
    );
  }

  @override
  void dispose() {
    _stopTalking?.cancel();
    _motion.dispose();
    super.dispose();
  }

  Widget _asset(String name) => Image.asset(
    'assets/images/guide/$name.png',
    fit: BoxFit.fill,
    gaplessPlayback: true,
    excludeFromSemantics: true,
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 208,
        height: 141,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final mouth = _motion.isAnimating
                ? ((_motion.value * 12).floor() % 4) + 1
                : 1;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 208,
                  height: 78,
                  child: _asset('person_02'),
                ),
                Positioned(
                  left: 71,
                  bottom: 28,
                  width: 94,
                  height: 112,
                  child: Transform.rotate(
                    angle: _motion.isAnimating
                        ? math.sin(_motion.value * math.pi * 2) * .015
                        : 0,
                    alignment: Alignment.bottomCenter,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _asset('head')),
                        Positioned(
                          left: 21,
                          top: 60,
                          width: 30,
                          height: 24,
                          child: _asset('mouth_0$mouth'),
                        ),
                        if (_motion.isAnimating && _motion.value > .91)
                          Positioned(
                            left: 17,
                            top: 38,
                            width: 36,
                            height: 12,
                            child: _asset('closed_eyes'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
