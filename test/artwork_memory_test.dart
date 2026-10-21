import 'dart:ui' as ui;

import 'package:challenge_land/core/artwork_sizes.g.dart';
import 'package:challenge_land/core/shared_android_assets.g.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/widgets/adaptive_asset_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'shared character and category resources decode through the common bundle',
      () async {
    for (final asset in [
      'assets/characters/contestant_omar.png',
      'assets/characters/layan.webp',
      'assets/categories/الأنمي.png',
      'assets/categories/كأس العالم.png',
    ]) {
      final bytes = await SharedAssets.bundle.load(asset);
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      final frame = await codec.getNextFrame();
      expect(Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
          artworkSizes[asset]);
      frame.image.dispose();
      codec.dispose();
    }
    await SharedAssets.initializeFont();
    expect((await SharedAssets.welcomeVideoUri()).scheme, 'android.resource');
    for (final asset in sharedAndroidAssets.keys) {
      expect(
          (await SharedAssets.bundle.load(asset)).lengthInBytes, greaterThan(0),
          reason: asset);
    }
  });

  test(
      'atlas slices share one bounded texture even for enormous stretched strips',
      () {
    const asset = 'assets/ui/weekly_reward.webp';
    final full = artworkDecodeWidth(
        asset,
        const BoxConstraints.tightFor(width: 780, height: 400),
        const Size(800, 450),
        1,
        BoxFit.fill);
    final strip = artworkDecodeWidth(
        asset,
        const BoxConstraints.tightFor(width: 30000, height: 9000),
        const Size(800, 450),
        1,
        BoxFit.fill);
    expect(full, 800);
    expect(strip, full);
    expect(
        artworkDecodeWidth(asset, const BoxConstraints(),
            const Size(3840, 2160), 3, BoxFit.fill),
        1600);
  });

  testWidgets('small portraits actually decode at their physical display size',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
      width: 48,
      height: 48,
      child:
          adaptiveAssetImage('assets/characters/omar.png', fit: BoxFit.contain),
    ))));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, lessThanOrEqualTo(96));
    await tester.runAsync(
        () => precacheImage(provider, tester.element(find.byType(Image))));
    final key = await provider.obtainKey(
        createLocalImageConfiguration(tester.element(find.byType(Image))));
    expect(PaintingBinding.instance.imageCache.containsKey(key), isTrue);
    expect(tester.takeException(), isNull);
  });
}
