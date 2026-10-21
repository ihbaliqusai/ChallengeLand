import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:challenge_land/core/shared_android_assets.g.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  void installAssetBridge() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SharedAssetBundle.channel, (call) async {
      if (call.method == 'welcomeVideoUri') {
        return 'android.resource://com.qi7bali.landchallengeonline/raw/welcome';
      }
      final source = sharedAndroidAssets[call.arguments];
      if (call.method != 'load' || source == null) {
        throw StateError('Unexpected shared asset request: ${call.arguments}');
      }
      return Uint8List.fromList(File(source).readAsBytesSync());
    });
  }

  installAssetBridge();
  setUp(installAssetBridge);
  await testMain();
}
