import 'package:flutter/painting.dart';

ImageProvider underlyingAsset(ImageProvider provider) => provider is ResizeImage
    ? underlyingAsset(provider.imageProvider)
    : provider;
