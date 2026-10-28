import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds app fonts and native dependencies to Flutter's existing package notices.
abstract final class ThirdPartyLicenses {
  static bool _registered = false;

  static void register() {
    if (_registered) return;
    _registered = true;
    // Read notices only when the player opens the license viewer.
    LicenseRegistry.addLicense(_load);
  }

  static Stream<LicenseEntry> _load() async* {
    const fonts = {
      'Baloo — Ek Type': 'assets/fonts/Baloo-OFL.txt',
      'Noto Sans Arabic': 'assets/fonts/NotoSansArabic-OFL.txt',
      'Barlow Condensed': 'assets/fonts/BarlowCondensed-OFL.txt',
    };
    for (final font in fonts.entries) {
      yield LicenseEntryWithLineBreaks(
        [font.key],
        await rootBundle.loadString(font.value),
      );
    }
    final manifest = jsonDecode(await rootBundle
        .loadString('assets/licenses/third_party_notices.json'));
    final entries = manifest is List ? manifest : manifest['entries'] as List;
    for (final entry in entries) {
      yield LicenseEntryWithLineBreaks(
        List<String>.from(entry['packages'] as List),
        entry['text'] as String,
      );
    }
  }
}
