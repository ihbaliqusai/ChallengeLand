import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/privacy_policy_content.g.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/screens/legal/privacy_policy_screen.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('millionaire/native');
  final requests = <MethodCall>[];

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

  setUp(() {
    requests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      requests.add(call);
      return true;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  Future<void> showPolicy(WidgetTester tester, {GlobalKey? boundary}) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Baloo',
        fontFamilyFallback: const ['NotoSansArabic'],
      ),
      builder: boundary == null
          ? null
          : (context, child) => RepaintBoundary(
              key: boundary, child: GameViewport(child: child!)),
      home: const PrivacyPolicyScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('policy is readable before login and searches real disclosures',
      (tester) async {
    await showPolicy(tester);
    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.textContaining(PrivacyPolicyContent.updatedAt), findsOneWidget);
    expect(find.text('خصوصيتك، بوضوح'), findsOneWidget);
    final search = find.byKey(const ValueKey('privacy-search'));
    await tester.enterText(search, 'Firebase');
    await tester.pumpAndSettle();
    expect(find.text('مشاركة البيانات ومزودو الخدمات'), findsOneWidget);
    expect(find.text('الأطفال وأولياء الأمور'), findsNothing);
    await tester.enterText(search, 'نص لا يوجد في السياسة');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج. جرّب كلمة أخرى.'), findsOneWidget);
    await tester.tap(find.byTooltip('مسح البحث'));
    await tester.pumpAndSettle();
    expect(find.text('خصوصيتك، بوضوح'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(requests, isEmpty);
  });

  testWidgets('contents navigate to children and deletion without signing in',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1040, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await showPolicy(tester);
    final children = find.text('8. الأطفال وأولياء الأمور');
    await tester.ensureVisible(children);
    await tester.tap(children);
    await tester.pumpAndSettle();
    expect(find.text('الأطفال وأولياء الأمور').hitTestable(), findsOneWidget);
    final deletion = find.text('13. حذف الحساب وطلبات حذف البيانات');
    await tester.ensureVisible(deletion);
    await tester.tap(deletion);
    await tester.pumpAndSettle();
    expect(find.text('حذف الحساب وطلبات حذف البيانات').hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy links open the real deletion resource and email draft',
      (tester) async {
    await showPolicy(tester);
    final contact = find.text('مراسلة فريق الخصوصية');
    await tester.ensureVisible(contact);
    await tester.tap(contact);
    await tester.pumpAndSettle();
    expect(requests.last.method, 'composeSupportEmail');
    expect((requests.last.arguments as Map)['recipient'],
        PrivacyPolicyContent.contactEmail);
    final deletion = find.text('طلب حذف الحساب');
    await tester.ensureVisible(deletion);
    await tester.tap(deletion);
    await tester.pumpAndSettle();
    expect(requests.last.method, 'openExternalUrl');
    expect((requests.last.arguments as Map)['url'],
        PrivacyPolicyContent.deletionUrl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('policy adapts to phone and tablet windows and exports a preview',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(1600, 826),
      const Size(800, 360),
      const Size(320, 640),
    ]) {
      tester.view.physicalSize = size;
      final boundary = GlobalKey();
      await showPolicy(tester, boundary: boundary);
      expect(find.byKey(const ValueKey('privacy-search')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      if (size.width == 1600) {
        final render = boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/privacy-policy-preview.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('external privacy links only allow HTTPS', () async {
    final bridge = NativeBridgeService();
    expect(await bridge.openExternalUrl('javascript:alert(1)'), isFalse);
    expect(await bridge.openExternalUrl('file:///data/local/account'), isFalse);
    expect(requests, isEmpty);
  });
}
