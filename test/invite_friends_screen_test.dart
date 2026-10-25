import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/screens/social/invite_friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _data = InviteFriendsData(
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

Widget _app({
  Future<InviteFriendsData> Function()? load,
  Future<InviteFriendsData> Function(String)? accept,
  Future<void> Function(String)? share,
  VoidCallback? play,
  String? initialCode,
  Key? boundaryKey,
}) =>
    MaterialApp(
      theme: ThemeData.dark().copyWith(
        textTheme:
            ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansArabic'),
      ),
      home: RepaintBoundary(
        key: boundaryKey,
        child: InviteFriendsScreen(
          load: load ?? () async => _data,
          accept: accept ?? (_) async => _data,
          share: share ?? (_) async {},
          onPlayWithFriends: play ?? () {},
          initialCode: initialCode,
        ),
      ),
    );

void main() {
  setUpAll(() async {
    for (final font in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(SharedAssets.bundle.load(font.value)))
          .load();
    }
  });
  testWidgets('share and play buttons use actual referral code and callbacks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shared = <String>[];
    var played = 0;
    await tester.pumpWidget(_app(
      share: (code) async => shared.add(code),
      play: () => played++,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CL-012345ABCDEF'), findsOneWidget);
    expect(find.text('5,000'), findsWidgets);
    expect(find.textContaining('فيسبوك'), findsNothing);
    await tester.tap(find.byKey(const Key('share-referral')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play-with-friends')));
    expect(shared, ['CL-012345ABCDEF']);
    expect(played, 1);
  });

  testWidgets(
      'accept trims input, disables retries while pending, then shows credited state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<InviteFriendsData>();
    final accepted = <String>[];
    await tester.pumpWidget(_app(
        initialCode: ' cl-friend123456 ',
        accept: (code) {
          accepted.add(code);
          return pending.future;
        }));
    await tester.pumpAndSettle();
    final acceptButton = find.byKey(const Key('accept-referral'));
    expect(tester.getRect(acceptButton).bottom, lessThanOrEqualTo(540));
    await tester.ensureVisible(acceptButton);
    await tester.tap(acceptButton);
    await tester.pump();
    expect(accepted, ['cl-friend123456']);
    expect(tester.widget<FilledButton>(acceptButton).onPressed, isNull);
    pending.complete(const InviteFriendsData(
      code: 'CL-012345ABCDEF',
      qualifiedCount: 4,
      earnedCoins: 5000,
      earnedGems: 50,
      canAccept: false,
      acceptedCode: 'CL-FRIEND123456',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accept-referral-code')), findsNothing);
    expect(find.textContaining('تم قبول الدعوة!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pasted Play URL keeps query parameter casing for referral parsing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const link =
        'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline&referrer=cl_referral%3DCL-012345ABCDEF';
    String? accepted;
    await tester.pumpWidget(_app(
      initialCode: '  $link  ',
      accept: (value) async {
        accepted = value;
        return _data;
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-referral')));
    await tester.pumpAndSettle();
    expect(accepted, link);
  });

  testWidgets('failed loading does not invent counts and can be retried',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var attempts = 0;
    await tester.pumpWidget(_app(load: () async {
      if (++attempts == 1) throw StateError('تحقق من الاتصال');
      return _data;
    }));
    await tester.pumpAndSettle();
    expect(find.text('تحقق من الاتصال'), findsOneWidget);
    expect(find.text('CL-012345ABCDEF'), findsNothing);
    expect(find.text('أصدقاء انضموا'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('CL-012345ABCDEF'), findsOneWidget);
    expect(find.text('تحقق من الاتصال'), findsNothing);
  });

  testWidgets(
      'ineligible account with incoming code explains why acceptance is unavailable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      initialCode: 'CL-012345ABCDEF',
      load: () async => InviteFriendsData(
        code: 'CL-ABCDEF012345',
        qualifiedCount: 0,
        earnedCoins: 0,
        earnedGems: 0,
        canAccept: false,
        milestones: _data.milestones,
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'لا يمكن لهذا الحساب قبول دعوة جديدة. يمكنك دعوة أصدقائك والحصول على المكافآت.'),
        findsOneWidget);
    expect(find.byKey(const Key('accept-referral-code')), findsNothing);
    expect(tester.getRect(find.textContaining('لا يمكن لهذا الحساب')).bottom,
        lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
  });

  testWidgets('acceptance errors stay beside the input for correction',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      initialCode: 'CL-NOTFOUND1234',
      accept: (_) async => throw StateError('كود الدعوة غير موجود'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-referral')));
    await tester.pumpAndSettle();
    final input =
        tester.widget<TextField>(find.byKey(const Key('accept-referral-code')));
    expect(input.decoration!.errorText, 'كود الدعوة غير موجود');
    expect(tester.getRect(find.text('كود الدعوة غير موجود')).bottom,
        lessThanOrEqualTo(540));
    await tester.enterText(
        find.byKey(const Key('accept-referral-code')), 'CL-ANOTHERCODE1');
    await tester.pump();
    expect(find.text('كود الدعوة غير موجود'), findsNothing);
  });

  testWidgets('portrait keeps all actions reachable and copies the real code',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final copy = find.byKey(const Key('copy-referral-code'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, 'CL-012345ABCDEF');
    await tester.ensureVisible(find.byKey(const Key('accept-referral')));
    await tester.tap(find.byKey(const Key('accept-referral')));
    await tester.pumpAndSettle();
    expect(find.text('أدخل كود صديقك أولًا.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (name: 'landscape', size: const Size(960, 540)),
    (name: 'portrait', size: const Size(390, 844)),
    (name: 'small_landscape', size: const Size(760, 360)),
    (name: 'small_portrait', size: const Size(320, 640)),
  ]) {
    testWidgets('invitation screen fits ${scenario.name}', (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const boundaryKey = Key('invite-preview');
      await tester.pumpWidget(_app(boundaryKey: boundaryKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['INVITE_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/invite_friends_${scenario.name}.png');
          output.parent.createSync(recursive: true);
          output.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.ensureVisible(find.byKey(const Key('accept-referral')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/invite_friends_${scenario.name}_accept.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
