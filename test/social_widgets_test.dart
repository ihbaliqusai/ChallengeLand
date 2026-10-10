import 'dart:async';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/social/social_screen.dart';
import 'package:challenge_land/services/social_service.dart';
import 'package:challenge_land/widgets/social_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App extends ChangeNotifier implements AppState {
  _App(String uid) : currentUser = _User(uid);
  @override
  User? currentUser;
  @override
  bool get isOnline => true;
  @override
  int get trophies => 100;
  final launched = <String>[];
  @override
  Future<void> openFriendChallenge(String code) async {
    launched.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StalledSocialService extends SocialService {
  _StalledSocialService({required super.firestore, required super.clock});
  final source =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  bool stalled = true;
  int refreshes = 0;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> blocks(String uid) =>
      stalled ? source.stream : super.blocks(uid);
  @override
  void refreshReads() {
    if (++refreshes > 1) stalled = false;
    super.refreshReads();
  }
}

class _NativeBroadcastSocialService extends SocialService {
  _NativeBroadcastSocialService(
      {required super.firestore, required super.clock});
  Stream<QuerySnapshot<Map<String, dynamic>>>? _shared;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> blocks(String uid) =>
      _shared ??= super
          .blocks(uid)
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  @override
  void refreshReads() {
    _shared = null;
    super.refreshReads();
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late SocialService service;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.now();
    // Firestore commits use one request.time for ALL server timestamps. Give
    // the fake the same controlled clock to preserve that atomic invariant.
    db = FakeFirebaseFirestore(clock: Clock(() => now));
    service = SocialService(firestore: db, clock: () => now);
    for (final uid in ['alice', 'bob']) {
      await db.doc('public_profiles/$uid').set({
        'uid': uid,
        'username': uid,
        'friendCode': uid.toUpperCase(),
        'trophies': 100
      });
      await db.doc('player_presence/$uid').set({
        'uid': uid,
        'state': 'available',
        'discoverable': true,
        'heartbeatAt': Timestamp.fromDate(now)
      });
    }
  });
  Future<void> pump(WidgetTester tester, _App app,
      {bool screen = false, bool settle = true}) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          Provider<SocialService>.value(value: service),
        ],
        child: MaterialApp(
            builder: (_, child) => SocialShell(child: child!),
            home: screen
                ? const SocialScreen()
                : const Scaffold(body: Text('home')))));
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets(
      'landscape discovery adds a friend once and removes expired presence',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true);
    expect(find.text('bob'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('إضافة صديق'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'pending');
    expect(find.text('طلب قائم'), findsOneWidget);
    now = now.add(const Duration(seconds: 76));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'accepted invitation launches both participants once and does not replay after remount',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: true);
    final recipient = _App('bob');
    await pump(tester, recipient);
    expect(find.text('قبول'), findsOneWidget);
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 20 && recipient.launched.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(recipient.launched, ['ALICE']);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(recipient.launched, ['ALICE']);
    await tester.pumpWidget(const SizedBox());
    final sender = _App('alice');
    await pump(tester, sender);
    for (var i = 0; i < 20 && sender.launched.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sender.launched, ['BOB']);
    await tester.pumpWidget(const SizedBox());
    final reopened = _App('alice');
    await pump(tester, reopened);
    expect(reopened.launched, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'expired and blocked invitations never display an actionable banner',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: true);
    await service.block('bob', 'alice');
    await pump(tester, _App('bob'));
    expect(find.text('قبول'), findsNothing);
    await service.unblock('bob', 'alice');
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('قبول'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('outgoing invitation exposes a countdown and sender cancellation',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: true);
    await pump(tester, _App('alice'));
    expect(find.textContaining('بانتظار قبول bob'), findsOneWidget);
    await tester.tap(find.text('إلغاء الدعوة'));
    await tester.pumpAndSettle();
    expect(
        (await db.doc('social_challenges/alice:bob').get()).data()?['status'],
        'cancelled');
    expect(find.text('إلغاء الدعوة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a silent initial friends load times out and retry recreates working listeners',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stalled = _StalledSocialService(firestore: db, clock: () => now);
    service = stalled;
    await pump(tester, _App('alice'), screen: true, settle: false);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await stalled.source.close();
  });

  testWidgets(
      'opening friends after startup receives data even when the shared native broadcast does not replay',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final native =
        _NativeBroadcastSocialService(firestore: db, clock: () => now);
    service = native;
    final startup = native.blocks('alice').listen((_) {});
    await tester.pump(); // Consume the initial snapshot before page navigation.
    await pump(tester, _App('alice'), screen: true);
    expect(find.text('bob'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    unawaited(startup.cancel());
    await tester.pump();
  });
}
