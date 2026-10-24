import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scales controls uniformly while allowing each route to fill the display.
/// Safe insets protect controls without leaving gaps around their backgrounds.
class GameViewport extends StatelessWidget {
  const GameViewport({super.key, required this.child});

  static const designSize = Size(960, 540);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final safe = media.viewPadding;
      final available = Size(
        math.max(0, constraints.maxWidth - safe.horizontal),
        math.max(0, constraints.maxHeight - safe.vertical),
      );
      final scale = math.min(available.width / designSize.width,
          available.height / designSize.height);
      if (!scale.isFinite || scale <= 0) {
        return const SizedBox.shrink();
      }

      final canvasSize = constraints.biggest / scale;
      EdgeInsets mapInsets(EdgeInsets insets) => insets / scale;

      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.fromSize(
            size: canvasSize,
            child: MediaQuery(
              data: media.copyWith(
                size: canvasSize,
                devicePixelRatio: media.devicePixelRatio * scale,
                textScaler: TextScaler.noScaling,
                padding: mapInsets(media.padding),
                viewPadding: mapInsets(media.viewPadding),
                viewInsets: mapInsets(media.viewInsets),
                systemGestureInsets: mapInsets(media.systemGestureInsets),
              ),
              child: child,
            ),
          ),
        ),
      );
    });
  }
}
