import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/artwork_sizes.g.dart';
import '../core/shared_android_assets.g.dart';
import '../core/shared_assets.dart';

/// All slices of an atlas use one decode size. Tiny stretched cleanup strips
/// must not create a separate, enormous texture or one cache entry per slice.
bool isArtworkAtlas(String asset) =>
    asset.startsWith('assets/store/') ||
    asset.startsWith('assets/home/') ||
    const {
      'assets/ui/home_menu.webp',
      'assets/ui/game_modes.webp',
      'assets/ui/weekly_reward.webp',
      'assets/ui/play_stake_dialog.png',
    }.contains(asset);

int? artworkDecodeWidth(String asset, BoxConstraints constraints, Size viewport,
    double pixelRatio, BoxFit fit,
    {double? width, double? height}) {
  final source = artworkSizes[asset];
  if (source == null) return null;
  double target;
  if (isArtworkAtlas(asset)) {
    target = viewport.width * pixelRatio;
  } else {
    final w = width ??
        (constraints.hasBoundedWidth ? constraints.maxWidth : viewport.width);
    final h = height ??
        (constraints.hasBoundedHeight
            ? constraints.maxHeight
            : viewport.height);
    final x = w / source.width, y = h / source.height;
    final ratio = fit == BoxFit.cover || fit == BoxFit.fill
        ? math.max(x, y)
        : fit == BoxFit.fitWidth
            ? x
            : fit == BoxFit.fitHeight
                ? y
                : math.min(x, y);
    target = source.width * ratio * pixelRatio;
  }
  if (!target.isFinite || target <= 0) return null;
  // Stable 32-pixel buckets prevent small layout changes growing the image cache.
  return math.min(source.width.toInt(), (target / 32).ceil() * 32);
}

/// Preserves Image keys/semantics while decoding textures at display resolution.
Widget adaptiveAssetImage(
  String asset, {
  Key? key,
  double? width,
  double? height,
  BoxFit? fit,
  AlignmentGeometry alignment = Alignment.center,
  Color? color,
  BlendMode? colorBlendMode,
  FilterQuality filterQuality = FilterQuality.low,
  String? semanticLabel,
  bool excludeFromSemantics = false,
  bool gaplessPlayback = false,
  ImageErrorWidgetBuilder? errorBuilder,
  ImageFrameBuilder? frameBuilder,
  Animation<double>? opacity,
  ImageRepeat repeat = ImageRepeat.noRepeat,
  Rect? centerSlice,
  bool isAntiAlias = false,
  bool matchTextDirection = false,
  double? scale,
  int? cacheWidth,
  int? cacheHeight,
  AssetBundle? bundle,
}) =>
    LayoutBuilder(builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final decodeWidth = cacheWidth ??
          artworkDecodeWidth(asset, constraints, media.size,
              media.devicePixelRatio, fit ?? BoxFit.scaleDown,
              width: width, height: height);
      return Image.asset(
        asset,
        key: key,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: errorBuilder,
        frameBuilder: frameBuilder,
        opacity: opacity,
        repeat: repeat,
        centerSlice: centerSlice,
        isAntiAlias: isAntiAlias,
        matchTextDirection: matchTextDirection,
        scale: scale,
        cacheWidth: decodeWidth,
        cacheHeight: cacheHeight,
        bundle: bundle ??
            (sharedAndroidAssets.containsKey(asset)
                ? SharedAssets.bundle
                : null),
      );
    });
