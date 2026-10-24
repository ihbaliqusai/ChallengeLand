import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'shared_android_assets.g.dart';

/// Reads shared artwork directly from the APK's existing Android resources.
/// Encoded bytes are not retained here; Flutter's image cache owns decoded images.
class SharedAssetBundle extends CachingAssetBundle {
  static const channel = MethodChannel('challengeland/shared-assets');

  @override
  Future<ByteData> load(String key) async {
    if (!sharedAndroidAssets.containsKey(key)) return rootBundle.load(key);
    final bytes = await channel.invokeMethod<Uint8List>('load', key);
    if (bytes == null) throw StateError('Empty shared asset: $key');
    return ByteData.sublistView(bytes);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) =>
      sharedAndroidAssets.containsKey(key)
          ? super.loadBuffer(key)
          : rootBundle.loadBuffer(key);

  /// Asset manifests and ordinary Flutter resources use the engine's fast path.
  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) =>
      rootBundle.loadStructuredBinaryData(key, parser);
}

abstract final class SharedAssets {
  static final bundle = SharedAssetBundle();
  static Future<void>? _font;

  static Future<void> initializeFont() => _font ??= (FontLoader('Baloo')
        ..addFont(bundle.load('assets/fonts/baloo.ttf')))
      .load();

  static Future<Uri> welcomeVideoUri() async {
    final uri =
        await SharedAssetBundle.channel.invokeMethod<String>('welcomeVideoUri');
    if (uri == null) throw StateError('Welcome video resource unavailable');
    return Uri.parse(uri);
  }
}
