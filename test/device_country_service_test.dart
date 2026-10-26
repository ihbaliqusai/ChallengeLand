import 'dart:async';
import 'dart:ui' as ui;

import 'package:challenge_land/services/device_country_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/device-country');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('network or SIM country takes priority over the device region',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceCountryCode');
      return ' jo ';
    });
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('en', 'US')],
    );
    expect(await detector.detectCountryCode(), 'JO');
  });

  test('a missing platform implementation falls back to the device region',
      () async {
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('ar', 'SA')],
    );
    expect(await detector.detectCountryCode(), 'SA');
  });

  test('unavailable telephony falls back without requiring a permission',
      () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'TELEPHONY_UNAVAILABLE');
    });
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('tr', 'TR')],
    );
    expect(await detector.detectCountryCode(), 'TR');
  });

  test('language-only settings do not invent a country', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('ar')],
    );
    expect(await detector.detectCountryCode(), isNull);
  });

  test('unknown countries and broad regions are ignored', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'ZZ');
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('es', '419'), ui.Locale('ar', 'EG')],
    );
    expect(await detector.detectCountryCode(), 'EG');
  });

  test('an unresponsive channel has a bounded fallback', () async {
    final pending = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final detector = DeviceCountryService(
      channel: channel,
      locales: () => const [ui.Locale('en', 'GB')],
      nativeTimeout: const Duration(milliseconds: 5),
    );
    expect(await detector.detectCountryCode(), 'GB');
    pending.complete(null);
  });
}
