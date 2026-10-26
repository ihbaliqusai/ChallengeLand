import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../core/leaderboard_countries.dart';

/// Uses the phone's country signals without GPS, permissions, or IP lookups.
class DeviceCountryService {
  DeviceCountryService({
    MethodChannel channel = const MethodChannel('millionaire/native'),
    Iterable<ui.Locale> Function()? locales,
    Duration nativeTimeout = const Duration(seconds: 1),
  })  : _channel = channel,
        _locales = locales ?? (() => ui.PlatformDispatcher.instance.locales),
        _nativeTimeout = nativeTimeout;

  final MethodChannel _channel;
  final Iterable<ui.Locale> Function() _locales;
  final Duration _nativeTimeout;

  static String? _countryCode(String? raw) {
    final code = raw?.trim().toUpperCase();
    return leaderboardCountries.containsKey(code) ? code : null;
  }

  Future<String?> detectCountryCode() async {
    try {
      // Android tries the mobile network, SIM, then the system's region.
      final country = _countryCode(await _channel
          .invokeMethod<String>('getDeviceCountryCode')
          .timeout(_nativeTimeout));
      if (country != null) return country;
    } on MissingPluginException {
      // Other platforms can still supply an explicit device region.
    } on PlatformException {
      // Devices without telephony can fall back to their configured region.
    } on TimeoutException {
      // A platform channel must not delay the country tab indefinitely.
    }
    for (final locale in _locales()) {
      final country = _countryCode(locale.countryCode);
      if (country != null) return country;
    }
    // A language alone (for example Arabic) cannot identify a country.
    return null;
  }
}
