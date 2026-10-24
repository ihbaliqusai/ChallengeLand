import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/widgets/game_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(builder: (value) {
        context = value;
        return const Scaffold(body: Text('Game'));
      }),
    ));
    return context;
  }

  testWidgets('feedback is centered and new messages replace old messages',
      (tester) async {
    final context = await host(tester);
    final messenger = GameNoticeMessenger.of(context);
    messenger.show('First');
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(GameNoticeCard));
    expect(center.dx, closeTo(400, 1));
    expect(center.dy, closeTo(300, 1));
    messenger.showSnackBar(const SnackBar(
        content: Text('Second'), duration: Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GameNoticeCard), findsNothing);
  });

  testWidgets('action runs once and closes its notice', (tester) async {
    final context = await host(tester);
    var calls = 0;
    GameNoticeMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Visit the store'),
      action: SnackBarAction(label: 'Open', onPressed: () => calls++),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(GameNoticeCard), findsNothing);
  });

  testWidgets('captured messenger works after its dialog is popped',
      (tester) async {
    final context = await host(tester);
    late GameNoticeMessenger messenger;
    showDialog<void>(
        context: context,
        builder: (dialogContext) {
          messenger = GameNoticeMessenger.of(dialogContext);
          return const GameAlertDialog(title: Text('Confirm'));
        });
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    messenger.show('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('long RTL notices keep actions reachable on small screens',
      (tester) async {
    for (final size in [const Size(640, 360), const Size(320, 480)]) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Center(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: GameNoticeCard(
              tone: GameNoticeTone.friend,
              content: Text(List.filled(20, 'دعوة صداقة جديدة من أحد اللاعبين.')
                  .join(' ')),
              actions: [
                FilledButton(onPressed: () {}, child: const Text('قبول')),
                OutlinedButton(onPressed: () {}, child: const Text('رفض'))
              ],
            ),
          ),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('قبول').hitTestable(), findsOneWidget);
      expect(find.text('رفض').hitTestable(), findsOneWidget);
    }
  });

  testWidgets('confirmation returns its existing result', (tester) async {
    final context = await host(tester);
    final result = showDialog<bool>(
        context: context,
        builder: (dialogContext) => GameAlertDialog(
              title: const Text('Confirm purchase'),
              content: const Text('50 coins'),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Confirm'))
              ],
            ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('export Arabic game notice previews', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final tone in [
      GameNoticeTone.friend,
      GameNoticeTone.challenge,
      GameNoticeTone.success
    ]) {
      final interactive = tone != GameNoticeTone.success;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansArabic')),
        home: RepaintBoundary(
          key: const ValueKey('notice-preview'),
          child: Scaffold(
              body: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/home/lobby_background.jfif', fit: BoxFit.cover),
            const ColoredBox(color: Color(0xB3070B19)),
            Center(
                child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GameNoticeCard(
                  key: ValueKey(tone),
                  tone: tone,
                  title: Text(tone.title(true)),
                  content: Text(switch (tone) {
                    GameNoticeTone.friend => 'أحمد أرسل لك طلب صداقة',
                    GameNoticeTone.challenge =>
                      'أحمد يدعوك لمواجهة\nالدخول: 50 قطعة • الجائزة: 100 قطعة\nمتبقي 24 ثانية',
                    _ => 'تم إرسال طلب الصداقة بنجاح',
                  }),
                  progress: tone == GameNoticeTone.challenge ? 0.8 : null,
                  onClose: () {},
                  actions: !interactive
                      ? []
                      : [
                          FilledButton(
                              onPressed: () {},
                              child: Text(tone == GameNoticeTone.friend
                                  ? 'قبول الصداقة'
                                  : 'قبول التحدي')),
                          OutlinedButton(
                              onPressed: () {}, child: const Text('رفض')),
                        ],
                ),
              ),
            )),
          ])),
        ),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/home/lobby_background.jfif'),
          tester.element(find.byKey(const ValueKey('notice-preview')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('notice-preview')));
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File('build/game-notice-${tone.name}-ar.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }
  }, skip: !const bool.fromEnvironment('EXPORT_GAME_NOTICES'));
}
