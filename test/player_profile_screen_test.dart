import 'dart:async';

import 'package:challenge_land/screens/social/player_profile_screen.dart';
import 'package:challenge_land/services/social_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _PendingProfiles extends SocialService {
  _PendingProfiles() : super(firestore: FakeFirebaseFirestore());

  final requests =
      <({String uid, bool refresh, Completer<Map<String, dynamic>> pending})>[];

  @override
  Future<Map<String, dynamic>> profile(String uid,
      {bool forceRefresh = false}) {
    final pending = Completer<Map<String, dynamic>>();
    requests.add((uid: uid, refresh: forceRefresh, pending: pending));
    return pending.future;
  }
}

void main() {
  final publicProfile = <String, dynamic>{
    'uid': 'bob',
    'username': 'Bob public',
    'friendCode': 'BOBCODE77',
    'level': 7,
    'trophies': 890,
    'wins': 12,
    'gamesPlayed': 20,
    'correctAnswers': 30,
    'accuracy': 75,
    'bestWinStreak': 4,
  };

  Future<void> pumpProfile(WidgetTester tester, SocialService service,
      {String uid = 'bob',
      Map<String, dynamic>? initialProfile,
      Size size = const Size(800, 400),
      double textScale = 1,
      bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(Provider<SocialService>.value(
        value: service,
        child: MaterialApp(
            theme: ThemeData(
                fontFamily: 'Baloo',
                fontFamilyFallback: const ['NotoSansArabic']),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: PlayerProfileScreen(
                playerUid: uid, initialProfile: initialProfile))));
    if (settle) await tester.pumpAndSettle();
  }

  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows the requested public player without private account data',
      (tester) async {
    resetView(tester);
    final db = FakeFirebaseFirestore();
    await db.doc('public_profiles/bob').set({
      ...publicProfile,
      // Defensive coverage: accidental private fields must not become widgets.
      'email': 'secret-bob@example.com',
      'coins': 918273,
      'gems': 445566,
      'playerStats': {'wins': 9999},
    });
    await db.doc('users/alice').set({
      'username': 'Alice private',
      'coins': 112233,
      'email': 'secret-alice@example.com',
    });
    await pumpProfile(tester, SocialService(firestore: db));
    expect(find.text('ملف اللاعب'), findsOneWidget);
    expect(find.text('Bob public'), findsOneWidget);
    expect(find.text('BOBCODE77'), findsOneWidget);
    expect(find.text('المستوى 7'), findsOneWidget);
    expect(find.text('متعلم'), findsOneWidget);
    expect(find.text('الدوري فضي'), findsOneWidget);
    expect(find.text('890'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    for (final secret in [
      'secret-bob@example.com',
      'secret-alice@example.com',
      'Alice private',
      '918273',
      '445566',
      '9999',
      '112233',
      'تعديل الملف',
    ]) {
      expect(find.text(secret), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing statistics stay absent instead of becoming zero values',
      (tester) async {
    resetView(tester);
    final db = FakeFirebaseFirestore();
    await db.doc('public_profiles/bob').set({
      'uid': 'bob',
      'username': 'Bob identity only',
    });
    await pumpProfile(tester, SocialService(firestore: db));
    expect(find.text('Bob identity only'), findsOneWidget);
    expect(find.text('لا توجد إحصاءات متاحة لهذا اللاعب بعد.'), findsOneWidget);
    expect(find.text('المستوى 1'), findsNothing);
    expect(find.text('الكؤوس'), findsNothing);
    expect(find.text('الانتصارات'), findsNothing);
    expect(find.text('المباريات'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('رمز اللاعب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a missing published profile shows retry instead of invented data',
      (tester) async {
    resetView(tester);
    final service = _PendingProfiles();
    await pumpProfile(tester, service, settle: false);
    service.requests.single.pending.complete({
      'uid': 'bob',
      'username': 'لاعب',
      '_profileMissing': true,
    });
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل ملف اللاعب.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byKey(const ValueKey('public-player-name')), findsNothing);
    expect(find.byKey(const ValueKey('public-player-code')), findsNothing);
    expect(find.text('المستوى 1'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing fresh profile keeps valid cached identity with retry',
      (tester) async {
    resetView(tester);
    final service = _PendingProfiles();
    await pumpProfile(tester, service,
        initialProfile: publicProfile, settle: false);
    service.requests.single.pending.complete({
      'uid': 'bob',
      '_profileMissing': true,
    });
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحديث ملف اللاعب.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('Bob public'), findsOneWidget);
    expect(find.text('BOBCODE77'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and retry read the requested player with a fresh cache',
      (tester) async {
    resetView(tester);
    final service = _PendingProfiles();
    await pumpProfile(tester, service, settle: false);
    expect(find.text('جارٍ تحميل ملف اللاعب…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(service.requests.single.uid, 'bob');
    expect(service.requests.single.refresh, isTrue);
    service.requests.single.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل ملف اللاعب.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('المستوى 1'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(service.requests, hasLength(2));
    expect(service.requests.last.uid, 'bob');
    expect(service.requests.last.refresh, isTrue);
    service.requests.last.pending.complete(publicProfile);
    await tester.pumpAndSettle();
    expect(find.text('Bob public'), findsOneWidget);
    expect(find.text('تعذر تحميل ملف اللاعب.'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old pending read cannot replace a different player profile',
      (tester) async {
    resetView(tester);
    final service = _PendingProfiles();
    await pumpProfile(tester, service,
        initialProfile: {'uid': 'bob', 'username': 'Bob preview'},
        settle: false);
    expect(find.text('Bob preview'), findsOneWidget);
    await pumpProfile(tester, service,
        uid: 'carol',
        initialProfile: {'uid': 'carol', 'username': 'Carol preview'},
        settle: false);
    expect(service.requests, hasLength(2));
    service.requests.first.pending.complete(publicProfile);
    await tester.pump();
    expect(find.text('Bob public'), findsNothing);
    expect(find.text('Carol preview'), findsOneWidget);
    service.requests.last.pending.complete({
      'uid': 'carol',
      'username': 'Carol fresh',
      'friendCode': 'CAROLCODE',
    });
    await tester.pumpAndSettle();
    expect(find.text('Carol fresh'), findsOneWidget);
    expect(find.text('BOBCODE77'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(800, 400), scale: 1.0),
    (size: const Size(320, 640), scale: 1.6),
  ]) {
    testWidgets(
        'profile fits ${scenario.size} with text scale ${scenario.scale}',
        (tester) async {
      resetView(tester);
      final db = FakeFirebaseFirestore();
      await db.doc('public_profiles/bob').set({
        ...publicProfile,
        'username': 'لاعب باسم طويل لاختبار وضوح الملف على الشاشات الصغيرة',
      });
      await pumpProfile(tester, SocialService(firestore: db),
          size: scenario.size, textScale: scenario.scale);
      expect(tester.takeException(), isNull);
      final accuracy = find.byKey(const ValueKey('public-stat:الدقة'));
      await tester.ensureVisible(accuracy);
      await tester.pumpAndSettle();
      expect(accuracy, findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('player profile keeps the usual route back action',
      (tester) async {
    resetView(tester);
    final db = FakeFirebaseFirestore();
    await db.doc('public_profiles/bob').set(publicProfile);
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(Provider<SocialService>.value(
        value: SocialService(firestore: db),
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const PlayerProfileScreen(
                                    playerUid: 'bob'))),
                        child: const Text('Players')))))));
    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();
    expect(find.text('ملف اللاعب'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Players'), findsOneWidget);
    expect(find.byType(PlayerProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
