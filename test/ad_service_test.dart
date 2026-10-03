import 'dart:async';

import 'package:challenge_land/services/ad_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final ump = MethodChannel('plugins.flutter.io/google_mobile_ads/ump',
      StandardMethodCodec(UserMessagingCodec()));
  late AdService service;
  late List<MethodCall> calls;
  late bool consentAllowed;

  Future<void> event(int adId, String name,
      [Map<String, Object?> extra = const {}]) async {
    final done = Completer<void>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      instanceManager.channel.name,
      instanceManager.channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': adId,
        'eventName': name,
        ...extra,
      })),
      (_) => done.complete(),
    );
    await done.future;
  }

  int getRewardedId() => calls
      .lastWhere((call) => call.method == 'loadRewardedAd')
      .arguments['adId'] as int;

  int count(String method) =>
      calls.where((call) => call.method == method).length;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    consentAllowed = true;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ump, (call) async {
      if (call.method == 'ConsentInformation#canRequestAds') {
        return consentAllowed;
      }
      if (call.method ==
          'ConsentInformation#getPrivacyOptionsRequirementStatus') {
        return 0;
      }
      return null;
    });
    service = AdService();
  });

  tearDown(() {
    service.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('concurrent initialization shares one SDK setup and preload', () async {
    await Future.wait([service.initialize(), service.initialize()]);
    await service.initialize();
    expect(count('MobileAds#initialize'), 1);
    expect(count('loadRewardedAd'), 1);
    expect(count('loadInterstitialAd'), 1);
  });

  test(
      'an ad that finishes loading in the background stays cached until a new tap',
      () async {
    await service.initialize();
    final result = service.showActionRewardedAd();
    await Future<void>.delayed(Duration.zero);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await event(getRewardedId(), 'onAdLoaded');
    expect(await result, isFalse);
    expect(count('showAdWithoutView'), 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final retry = service.showActionRewardedAd();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 1);
    await event(getRewardedId(), 'onAdDismissedFullScreenContent');
    expect(await retry, isFalse);
  });

  testWidgets('tap waits for the existing preload and rejects concurrent taps',
      (tester) async {
    await service.initialize();
    final result = service.showActionRewardedAd();
    await tester.pump();
    expect(count('loadRewardedAd'), 1);
    expect(count('showAdWithoutView'), 0);
    expect(await service.showActionRewardedAd(), isFalse);
    final id = getRewardedId();
    await event(id, 'onAdLoaded');
    await tester.pump();
    expect(count('showAdWithoutView'), 1);
    await event(id, 'onRewardedAdUserEarnedReward', {
      'rewardItem': RewardItem(1, 'reward'),
    });
    await event(id, 'onAdDismissedFullScreenContent');
    expect(await result, isTrue);
    expect(
        service.watchesToday, 0); // Category rentals do not use coin cooldown.
  });

  testWidgets('coin reward is recorded once and delivered after ad dismissal',
      (tester) async {
    await service.initialize();
    final result = service.showRewardedAd();
    var completed = false;
    result.then((_) => completed = true);
    await tester.pump();
    final id = getRewardedId();
    await event(id, 'onAdLoaded');
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await event(id, 'onRewardedAdUserEarnedReward', {
        'rewardItem': RewardItem(1, 'reward'),
      });
    }
    expect(service.watchesToday, 1);
    expect(service.canWatchAd, isFalse);
    expect(completed, isFalse);
    await event(id, 'onAdDismissedFullScreenContent');
    expect(await result, {'coins': 100, 'gems': 5});
  });

  testWidgets('closing an ad without earning does not award currency',
      (tester) async {
    await service.initialize();
    final result = service.showRewardedAd();
    await tester.pump();
    final id = getRewardedId();
    await event(id, 'onAdLoaded');
    await tester.pump();
    await event(id, 'onAdDismissedFullScreenContent');
    expect(await result, isNull);
    expect(service.watchesToday, 0);
  });

  testWidgets('no fill returns failure and disposal cancels scheduled retries',
      (tester) async {
    await service.initialize();
    final result = service.showActionRewardedAd();
    await tester.pump();
    await event(getRewardedId(), 'onAdFailedToLoad', {
      'loadAdError':
          LoadAdError(3, 'com.google.android.gms.ads', 'No fill', null),
    });
    expect(await result, isFalse);
    expect(count('showAdWithoutView'), 0);
    // Dispose in the test so fake time can verify retry cancellation.
    service.dispose();
    service = AdService();
    await tester.pump(const Duration(seconds: 31));
    expect(count('loadRewardedAd'), 1);
  });

  testWidgets('consent prevents preload and on-demand requests',
      (tester) async {
    consentAllowed = false;
    await service.initialize();
    expect(await service.showActionRewardedAd(), isFalse);
    expect(count('loadRewardedAd'), 0);
    expect(count('loadInterstitialAd'), 0);
  });

  testWidgets('timeout never shows an ad after the action has returned',
      (tester) async {
    await service.initialize();
    final result = service.showActionRewardedAd();
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(await result, isFalse);
    final id = getRewardedId();
    await event(id, 'onAdLoaded');
    await tester.pump();
    expect(count('showAdWithoutView'), 0);
    // The late preload is available for a new, explicit tap.
    final retry = service.showActionRewardedAd();
    await tester.pump();
    expect(count('loadRewardedAd'), 1);
    expect(count('showAdWithoutView'), 1);
    await event(id, 'onAdDismissedFullScreenContent');
    expect(await retry, isFalse);
  });
}
