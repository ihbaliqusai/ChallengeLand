import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/services/invite_service.dart';
import 'package:challenge_land/widgets/incoming_invite_dialog.dart';

void main() {
  testWidgets(
      'IncomingInviteDialog renders friend challenge candidate and responds to actions',
      (tester) async {
    const candidate = InviteCandidate(
      type: InviteType.friendChallenge,
      code: 'CL-8899',
      title: '⚔️ دعوة تحدي 1 ضد 1 من صديق!',
      subtitle: 'اللاعب فهد يتحداك الآن في أرض التحدي',
      rawText: 'CL-8899',
      senderName: 'فهد البطل',
      senderLevel: 14,
    );

    bool accepted = false;
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: IncomingInviteDialog(
            candidate: candidate,
            onAccept: () => accepted = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('⚔️ تحدي لاعب ضد لاعب'), findsOneWidget);
    expect(find.text('⚔️ دعوة تحدي 1 ضد 1 من صديق!'), findsOneWidget);
    expect(find.text('اللاعب فهد يتحداك الآن في أرض التحدي'), findsOneWidget);
    expect(find.text('فهد البطل'), findsOneWidget);
    expect(find.text('Lv.14'), findsOneWidget);
    expect(find.text('CL-8899'), findsOneWidget);
    expect(find.text('نسخ'), findsOneWidget);
    expect(find.text('قبول التحدي ⚔️'), findsOneWidget);
    expect(find.text('تجاهل'), findsOneWidget);

    // Test copy button
    await tester.tap(find.text('نسخ'));
    await tester.pump();
    expect(find.text('تم النسخ!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    // Test accept button
    await tester.tap(find.text('قبول التحدي ⚔️'));
    await tester.pump();
    expect(accepted, isTrue);

    // Test dismiss button
    await tester.tap(find.text('تجاهل'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets(
      'IncomingInviteDialog renders room invite candidate with mode pill and players count',
      (tester) async {
    const candidate = InviteCandidate(
      type: InviteType.room,
      code: 'ROOM-4411',
      title: '🏆 دعوة انضمام لغرفة جماعية!',
      subtitle: 'المضيف: سارة • 3/4 لاعبين',
      rawText: 'ROOM-4411',
      senderName: 'سارة',
      roomMode: 'blitz',
      roomPlayerCount: 3,
      roomMaxPlayers: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: IncomingInviteDialog(
            candidate: candidate,
            onAccept: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('🏆 دعوة غرفة جماعية'), findsOneWidget);
    expect(find.text('المضيف: سارة'), findsOneWidget);
    expect(find.text('صراع السرعة'), findsOneWidget);
    expect(find.text('3/4 لاعبين'), findsOneWidget);
    expect(find.text('ROOM-4411'), findsOneWidget);
    expect(find.text('انضمام للغرفة 🚀'), findsOneWidget);
  });

  testWidgets(
      'IncomingInviteDialog renders without overflow on compact screens',
      (tester) async {
    const candidate = InviteCandidate(
      type: InviteType.friendChallenge,
      code: 'CL-TEST1',
      title: '⚔️ دعوة تحدي 1 ضد 1!',
      subtitle: 'يتحداك صديقك الآن',
      rawText: 'CL-TEST1',
      senderName: 'محمد',
      senderLevel: 20,
    );

    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(640, 360),
      const Size(800, 400),
    ]) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: IncomingInviteDialog(
              candidate: candidate,
              onAccept: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
  });
}
