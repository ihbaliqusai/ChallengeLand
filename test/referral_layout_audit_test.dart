import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/screens/social/invite_friends_screen.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _auditData = InviteFriendsData(
  code: 'CL-012345ABCDEF',
  qualifiedCount: 4,
  earnedCoins: 5000,
  earnedGems: 50,
  canAccept: true,
  milestones: [
    InviteFriendsMilestone(count: 3, coins: 1000, gems: 10, claimed: true),
    InviteFriendsMilestone(count: 5, coins: 2500, gems: 25, claimed: false),
    InviteFriendsMilestone(count: 10, coins: 5000, gems: 50, claimed: false),
  ],
);

void main() {
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

  Future<void> snapshot(WidgetTester tester, Key key, String name) async {
    if (Platform.environment['REFERRAL_AUDIT_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/referral_layout_audit/$name.png');
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final scenario in [
    (
      name: 'landscape_640x360_scale13',
      size: const Size(640, 360),
      scale: 1.3,
      keyboard: 0.0
    ),
    (
      name: 'landscape_720x320_scale20',
      size: const Size(720, 320),
      scale: 2.0,
      keyboard: 0.0
    ),
    (
      name: 'keyboard_640x360_scale13',
      size: const Size(640, 360),
      scale: 1.3,
      keyboard: 220.0
    ),
    (
      name: 'keyboard_720x320_scale20',
      size: const Size(720, 320),
      scale: 2.0,
      keyboard: 210.0
    ),
    (
      name: 'user_1600x826',
      size: const Size(1600, 826),
      scale: 1.0,
      keyboard: 0.0
    ),
  ]) {
    testWidgets('GameViewport referral audit ${scenario.name}', (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final keyboard = ValueNotifier<double>(0);
      addTearDown(keyboard.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Baloo',
          fontFamilyFallback: const ['NotoSansArabic'],
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7C3AED), surface: Color(0xFF0B173F)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: .08),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: .18))),
          ),
        ),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, keyboardHeight, _) => RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scenario.scale),
                viewInsets: EdgeInsets.only(bottom: keyboardHeight),
                viewPadding: const EdgeInsets.only(left: 24, right: 12),
                padding: const EdgeInsets.only(left: 24, right: 12),
              ),
              child: GameViewport(child: child!),
            ),
          ),
        ),
        home: InviteFriendsScreen(
          initialCode: scenario.keyboard > 0 ? 'CL-012345ABCDEF' : null,
          load: () async => _auditData,
          accept: (_) async => _auditData,
          share: (_) async {},
          onPlayWithFriends: () {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/social/invite_friends_hero.png'),
          tester.element(find.byType(InviteFriendsScreen))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario.keyboard == 0) {
        expect(find.byKey(const Key('share-referral')).hitTestable(),
            findsOneWidget);
        expect(find.byKey(const Key('play-with-friends')).hitTestable(),
            findsOneWidget);
      }
      await snapshot(tester, boundaryKey, scenario.name);
      if (scenario.keyboard > 0) {
        final input = find.byKey(const Key('accept-referral-code'));
        await tester.tap(input);
        keyboard.value = scenario.keyboard;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final inputRect = tester.getRect(input);
        final acceptRect =
            tester.getRect(find.byKey(const Key('accept-referral')));
        final keyboardTop = scenario.size.height - scenario.keyboard;
        expect(inputRect.bottom, lessThanOrEqualTo(keyboardTop));
        expect(acceptRect.bottom, lessThanOrEqualTo(keyboardTop));
        expect(inputRect.top, greaterThanOrEqualTo(0));
        expect(acceptRect.top, greaterThanOrEqualTo(0));
        debugPrint(
            'AUDIT ${scenario.name} keyboardTop=${scenario.size.height - scenario.keyboard} input=$inputRect accept=$acceptRect');
        await snapshot(tester, boundaryKey, '${scenario.name}_focused');
        await tester.ensureVisible(find.byKey(const Key('accept-referral')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('accept-referral')).hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapshot(tester, boundaryKey, '${scenario.name}_accept_visible');
      }
    });
  }
}
