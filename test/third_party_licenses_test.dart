import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/third_party_licenses.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/legal/open_source_licenses.dart';
import 'package:challenge_land/screens/legal/privacy_policy_screen.dart';
import 'package:challenge_land/screens/online/settings_screen.dart';
import 'package:challenge_land/services/ad_service.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GuestState extends ChangeNotifier implements AppState {
  @override
  bool get isBusy => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Ads extends ChangeNotifier implements AdService {
  @override
  bool get privacyOptionsRequired => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Promo extends ChangeNotifier implements CrossPromoService {
  @override
  bool get isRewardClaimed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _finishLoadingLicenses(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Allow asset decoding to finish on the real clock, then flush callbacks on
  // the widget test's fake clock. Awaiting the widget's future directly blocks
  // the fake microtasks needed to finish the stream.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ThirdPartyLicenses.register();

  setUpAll(() async {
    for (final font in {
      'Baloo': 'assets/fonts/baloo.ttf',
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(SharedAssets.bundle.load(font.value)))
          .load();
    }
  });

  test('offline notices include fonts and native libraries omitted by Flutter',
      () async {
    final entries = await LicenseRegistry.licenses.toList();
    final names = entries.expand((entry) => entry.packages).join('\n');
    for (final name in [
      'Baloo',
      'Noto Sans Arabic',
      'Barlow Condensed',
      'picasso',
      'circleimageview',
      'RingProgressBar'
    ]) {
      expect(names.toLowerCase(), contains(name.toLowerCase()));
    }
    final baloo = entries.singleWhere(
        (entry) => entry.packages.any((name) => name.startsWith('Baloo')));
    final text = baloo.paragraphs.map((paragraph) => paragraph.text).join('\n');
    expect(text, contains('Ek Type'));
    expect(text, contains('SIL OPEN FONT LICENSE'));
    expect(text, contains('TERMINATION'));
    expect(text, contains('DISCLAIMER'));

    // The JSON actually packaged for the Flutter viewer must contain full text.
    final manifest = jsonDecode(await rootBundle
        .loadString('assets/licenses/third_party_notices.json'));
    final notices = manifest is List ? manifest : manifest['entries'] as List;
    expect(notices, isNotEmpty);
    for (final notice in notices) {
      expect(notice['packages'], isNotEmpty);
      expect((notice['text'] as String).length, greaterThan(200));
    }
  });

  testWidgets('full Baloo text opens offline on phone and tablet',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(800, 360), const Size(1200, 650)]) {
      tester.view.physicalSize = size;
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Baloo',
              fontFamilyFallback: const ['NotoSansArabic']),
        ),
        builder: (_, child) => RepaintBoundary(key: boundary, child: child),
        home: Builder(
            builder: (context) => Scaffold(
                  body: Center(
                      child: TextButton(
                    onPressed: () => showOpenSourceLicenses(context),
                    child: const Text('Open licenses'),
                  )),
                )),
      ));
      await tester.tap(find.text('Open licenses'));
      await _finishLoadingLicenses(tester);
      final baloo = find.widgetWithText(ListTile, 'Baloo — Ek Type');
      await tester.scrollUntilVisible(baloo, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(baloo);
      await _finishLoadingLicenses(tester);
      expect(find.textContaining('SIL OPEN FONT LICENSE'), findsWidgets);
      expect(tester.takeException(), isNull, reason: '$size');
      if (size.width == 1200) {
        final render = boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/licenses-preview.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('privacy credits open the offline license viewer before login',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pumpAndSettle();
    final credits = find.text('اعتمادات المحتوى والتراخيص');
    await tester.ensureVisible(credits);
    await tester.tap(credits);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('open-source-licenses'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await _finishLoadingLicenses(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings keep licenses reachable in compact and tablet layouts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(800, 360), const Size(1200, 650)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>(
              create: (_) =>
                  AppSettings(NativeBridgeService())..loading = false),
          ChangeNotifierProvider<AppState>(create: (_) => _GuestState()),
          ChangeNotifierProvider<AdService>(create: (_) => _Ads()),
          ChangeNotifierProvider<CrossPromoService>(create: (_) => _Promo()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const SettingsScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      final entry = find.text('تراخيص المكتبات والخطوط');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await _finishLoadingLicenses(tester);
      expect(find.byType(LicensePage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
