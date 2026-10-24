import 'package:challenge_land/core/shared_assets.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/social/player_profile_screen.dart';
import 'package:challenge_land/screens/social/social_screen.dart';
import 'package:challenge_land/services/social_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/online_match_flow.dart';
import 'package:challenge_land/widgets/friend_stake_selector.dart';
import 'package:challenge_land/widgets/game_notice.dart';
import 'package:challenge_land/widgets/social_shell.dart';
import 'package:challenge_land/widgets/social_artwork.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final paidLaunched = <String>[];
  void switchAccount(String uid) {
    currentUser = _User(uid);
    notifyListeners();
  }

  @override
  Future<void> openFriendChallenge(String code) async {
    launched.add(code);
  }

  @override
  Future<void> openStakedFriendChallenge(String code,
      {required String matchId, required int stakeCoins}) async {
    paidLaunched.add('$code:$matchId:$stakeCoins');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StakesBridge extends NativeBridgeService {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> friendStakes(Map<String, dynamic> data) async {
    calls.add(data);
    return {};
  }
}

class _AvailableNativeBridge extends NativeBridgeService {
  @override
  Future<List<Map<String, dynamic>>> getRecoverableOnlineMatches() async => [];
  @override
  Future<bool> isOnlineMatchAccount(String uid) async => true;
}

class _SavedMatchBridge extends _AvailableNativeBridge {
  @override
  Future<List<Map<String, dynamic>>> getRecoverableOnlineMatches() async => [
        {'id': 'bot:previous', 'uid': 'bob', 'finished': false},
      ];
  @override
  Future<Map<String, dynamic>> inspectOnlineMatch(String id,
          {bool forfeit = false, String? uid}) async =>
      {'id': id, 'uid': 'bob', 'finished': false};
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
    refreshes++;
    super.refreshReads();
  }
}

class _NativeBroadcastSocialService extends SocialService {
  _NativeBroadcastSocialService(
      {required super.firestore, required super.clock});
  Stream<QuerySnapshot<Map<String, dynamic>>>? _shared;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sharedPlayers;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> blocks(String uid) =>
      _shared ??= super
          .blocks(uid)
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> recentPlayers() =>
      _sharedPlayers ??= super
          .recentPlayers()
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  @override
  void refreshReads() {
    _shared = null;
    _sharedPlayers = null;
    super.refreshReads();
  }
}

class _FailingProfileSocialService extends SocialService {
  _FailingProfileSocialService(
      {required super.firestore, required super.clock});
  @override
  Future<Map<String, dynamic>> profile(String uid,
          {bool forceRefresh = false}) =>
      uid == 'bob'
          ? Future.error(StateError('Profile unavailable'))
          : super.profile(uid, forceRefresh: forceRefresh);
}

class _DelayedProfileSocialService extends SocialService {
  _DelayedProfileSocialService(
      {required super.firestore, required super.clock});
  final delayed = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> profile(String uid,
          {bool forceRefresh = false}) =>
      uid == 'recent'
          ? delayed.future
          : super.profile(uid, forceRefresh: forceRefresh);
}

void main() {
  late FakeFirebaseFirestore db;
  late SocialService service;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 12, 12);
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

  Future<void> seedPlayer(String uid,
      {Duration age = Duration.zero,
      String state = 'available',
      bool discoverable = true}) async {
    await db.doc('public_profiles/$uid').set({
      'uid': uid,
      'username': uid,
      'friendCode': uid.toUpperCase(),
      'trophies': 100,
    });
    await db.doc('player_presence/$uid').set({
      'uid': uid,
      'state': state,
      'discoverable': discoverable,
      'heartbeatAt': Timestamp.fromDate(now.subtract(age)),
    });
  }

  Future<void> pump(WidgetTester tester, _App app,
      {bool screen = false,
      bool settle = true,
      int initialTab = 0,
      Size size = const Size(640, 360),
      ThemeData? theme,
      NativeBridgeService? recoveryBridge,
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          Provider<SocialService>.value(value: service),
          Provider<NativeBridgeService>(
              create: (_) => recoveryBridge ?? _AvailableNativeBridge()),
        ],
        child: MaterialApp(
            navigatorKey: OnlineMatchFlow.navigatorKey,
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SocialShell(child: child!))),
            home: screen
                ? SocialScreen(initialTab: initialTab)
                : const Scaffold(body: Text('home')))));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollable = target.evaluate().isNotEmpty
        ? find.byWidget(
            Scrollable.of(tester.element(target), axis: Axis.vertical).widget)
        : find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                (widget.axisDirection == AxisDirection.down ||
                    widget.axisDirection == AxisDirection.up))
            .last;
    if (target.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(target, 140,
        scrollable: scrollable, maxScrolls: 30);
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester, String peer) async {
    final feedbackClose = find.descendant(
        of: find.byType(GameNoticeCard),
        matching: find.byIcon(Icons.close_rounded));
    if (feedbackClose.evaluate().isNotEmpty) {
      await tester.tap(feedbackClose.first);
      await tester.pumpAndSettle();
    }
    final player = find.byKey(ValueKey('player:$peer'));
    await reveal(tester, player);
    await tester.tap(player);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  }

  Finder option(String label) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(label));

  testWidgets(
      'accepting an invitation can show recovery above the root social notice',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ref = db.doc('social_challenges/alice:bob');
    await ref.set({
      'members': ['alice', 'bob'],
      'fromUid': 'alice',
      'toUid': 'bob',
      'status': 'pending',
      'mode': 'duel',
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30))),
    });
    final app = _App('bob');
    await pump(tester, app,
        size: const Size(640, 480), recoveryBridge: _SavedMatchBridge());
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    expect(find.text('لديك مباراة لم تنتهِ'), findsOneWidget);
    expect(find.text('دعوة إلى التحدي'), findsNothing);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect((await ref.get()).data()?['status'], 'pending');
    expect(app.launched, isEmpty);
    expect(find.text('دعوة إلى التحدي'), findsOneWidget);
  });

  testWidgets(
      'paid friend invitation shows cost and pool before server acceptance',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bridge = _StakesBridge();
    service =
        SocialService(firestore: db, clock: () => now, nativeBridge: bridge);
    final ref = db.doc('social_challenges/alice:bob');
    await ref.set({
      'members': ['alice', 'bob'],
      'fromUid': 'alice',
      'toUid': 'bob',
      'status': 'pending',
      'mode': 'duel',
      'serverStake': true,
      'stakeCoins': 50,
      'prizeCoins': 100,
      'stakeMatchId': 'paid-match',
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30))),
    });
    final app = _App('bob');
    await pump(tester, app, size: const Size(640, 480));
    expect(find.text('قبول بـ50 قطعة'), findsOneWidget);
    expect(find.textContaining('الجائزة: 100 قطعة'), findsOneWidget);
    await tester.tap(find.text('قبول بـ50 قطعة'));
    await tester.pumpAndSettle();
    expect(bridge.calls.single, containsPair('expectedAmount', 50));
    expect(bridge.calls.single, containsPair('status', 'accepted'));
    expect((await ref.get()).data()?['status'], 'pending');
    expect(app.launched, isEmpty);
    expect(app.paidLaunched, isEmpty);

    // Only the server's accepted document plus matching reservation may launch.
    final acceptedAt = Timestamp.fromDate(now);
    await db.doc('social_reservations/bob').set({
      'challengeId': ref.id,
      'acceptedAt': acceptedAt,
      'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 2))),
    });
    await ref.update({'status': 'accepted', 'acceptedAt': acceptedAt});
    for (var i = 0; i < 20 && app.paidLaunched.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(app.paidLaunched, ['ALICE:paid-match:50']);
    expect(app.launched, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'paid friend selector offers all seven stakes and sends explicit amount',
      (tester) async {
    int? chosen;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      chosen = await FriendStakeSelector.choose(context);
                    },
                    child: const Text('اختيار'))))));
    await tester.tap(find.text('اختيار'));
    await tester.pumpAndSettle();
    for (final amount in SocialService.stakeAmounts) {
      expect(find.byKey(ValueKey('friendStake:$amount')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('friendStake:0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('friendStake:5000')));
    await tester.pumpAndSettle();
    expect(find.text('تدفع 5000 قطعة • الفائز يحصل على 10000 قطعة'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sendStakedChallenge')));
    await tester.pumpAndSettle();
    expect(chosen, 5000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'paid social challenge sends chosen price only after player confirms',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bridge = _StakesBridge();
    service =
        SocialService(firestore: db, clock: () => now, nativeBridge: bridge);
    await pump(tester, _App('alice'), screen: true, size: const Size(640, 480));
    await openOptions(tester, 'bob');
    await tester.tap(option('تحدٍّ على قطع'));
    await tester.pumpAndSettle();
    expect(bridge.calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('friendStake:50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sendStakedChallenge')));
    await tester.pumpAndSettle();
    expect(bridge.calls.single, containsPair('stakeCoins', 50));
    expect(bridge.calls.single, containsPair('peerUid', 'bob'));
    expect((await db.doc('social_challenges/alice:bob').get()).exists, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  void expectChallengeUnavailable(WidgetTester tester) {
    final label = option('تحدٍّ مباشر');
    if (label.evaluate().isEmpty) {
      expect(label, findsNothing);
      return;
    }
    final button = find
        .ancestor(
            of: label,
            matching:
                find.byWidgetPredicate((widget) => widget is ButtonStyleButton))
        .first;
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
  }

  Future<void> closeOptions(WidgetTester tester) async {
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  }

  testWidgets(
      'landscape discovery adds a friend once and moves expired presence to recent activity',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true);
    await reveal(tester, find.byKey(const ValueKey('player:bob')));
    expect(find.text('bob'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('إضافة صديق'), findsNothing);
    await openOptions(tester, 'bob');
    await reveal(tester, option('إضافة صديق'));
    await tester.tap(option('إضافة صديق'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'pending');
    await openOptions(tester, 'bob');
    expect(option('طلب قائم'), findsOneWidget);
    expect(option('إضافة صديق'), findsNothing);
    await closeOptions(tester);
    now = now.add(const Duration(seconds: 76));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(ChoiceChip, 'خلال ساعة'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'خلال ساعة'));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    await openOptions(tester, 'bob');
    expectChallengeUnavailable(tester);
    await closeOptions(tester);
    await reveal(tester, find.widgetWithText(ChoiceChip, 'متصل الآن'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'متصل الآن'));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'an online stranger can receive a play invitation without a friend request',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'),
        screen: true, size: const Size(320, 640), textScale: 1.5);
    await openOptions(tester, 'bob');
    await reveal(tester, option('تحدٍّ مباشر'));
    await tester.tap(option('تحدٍّ مباشر'));
    await tester.pumpAndSettle();
    expect(
        (await db.doc('social_challenges/alice:bob').get()).data()?['status'],
        'pending');
    expect((await db.doc('social_links/alice:bob').get()).exists, isFalse);
    expect(find.textContaining('بانتظار قبول bob'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('landscape discovery opens challenge options without scrolling',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true, size: const Size(800, 400));
    expect(find.text('bob').hitTestable(), findsOneWidget);
    expect(find.text('تحدٍّ مباشر'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player:bob')));
    await tester.pumpAndSettle();
    expect(option('تحدٍّ مباشر').hitTestable(), findsOneWidget);
    expect(option('عرض الملف الشخصي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('activity filters keep each player in their current time group',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedPlayer('recent', age: const Duration(minutes: 30), state: 'away');
    await seedPlayer('earlier', age: const Duration(hours: 3), state: 'away');
    await seedPlayer('today', age: const Duration(hours: 8), state: 'away');
    await pump(tester, _App('alice'),
        screen: true, size: const Size(800, 2200));
    for (final label in [
      'متصلون الآن',
      'نشطوا خلال ساعة',
      'نشطوا خلال 6 ساعات',
      'نشطوا اليوم',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final peer in ['bob', 'recent', 'earlier', 'today']) {
      expect(find.text(peer), findsOneWidget);
    }
    for (final entry in {
      'متصل الآن': 'bob',
      'خلال ساعة': 'recent',
      'خلال 6 ساعات': 'earlier',
      'اليوم': 'today',
    }.entries) {
      final filter = find.widgetWithText(ChoiceChip, entry.key);
      await reveal(tester, filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filter).selected, isTrue);
      expect(find.text(entry.value), findsOneWidget);
      for (final peer in ['bob', 'recent', 'earlier', 'today']) {
        if (peer != entry.value) expect(find.text(peer), findsNothing);
      }
    }
    final all = find.widgetWithText(ChoiceChip, 'الكل');
    await reveal(tester, all);
    await tester.tap(all);
    await tester.pumpAndSettle();
    for (final peer in ['bob', 'recent', 'earlier', 'today']) {
      expect(find.text(peer), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('discovery excludes self, blocked, hidden and old players',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedPlayer('blocked');
    await seedPlayer('hidden', discoverable: false);
    await seedPlayer('yesterday',
        age: const Duration(hours: 25), state: 'away');
    await service.block('alice', 'blocked');
    await pump(tester, _App('alice'),
        screen: true, size: const Size(800, 1600));
    expect(find.byKey(const ValueKey('player:bob')), findsOneWidget);
    for (final peer in ['alice', 'blocked', 'hidden', 'yesterday']) {
      expect(find.byKey(ValueKey('player:$peer')), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('online players in a match cannot be challenged', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.doc('player_presence/bob').update({'state': 'in_match'});
    await pump(tester, _App('alice'),
        screen: true, size: const Size(320, 640), textScale: 1.5);
    final player = find.byKey(const ValueKey('player:bob'));
    await reveal(tester, player);
    expect(find.text('bob'), findsOneWidget);
    await openOptions(tester, 'bob');
    expectChallengeUnavailable(tester);
    expect(option('إضافة صديق'), findsOneWidget);
    expect((await db.doc('social_challenges/alice:bob').get()).exists, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'recent offline players expose friendship and profile without challenge',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.doc('player_presence/bob').update({
      'state': 'away',
      'heartbeatAt':
          Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
    });
    await pump(tester, _App('alice'),
        screen: true, size: const Size(320, 640), textScale: 1.5);
    await openOptions(tester, 'bob');
    expectChallengeUnavailable(tester);
    expect(option('إضافة صديق'), findsOneWidget);
    expect(option('عرض الملف الشخصي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'open player options stop offering a challenge when presence changes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true, size: const Size(800, 400));
    await openOptions(tester, 'bob');
    expect(option('تحدٍّ مباشر'), findsOneWidget);
    await db.doc('player_presence/bob').update({'state': 'in_match'});
    await tester.pumpAndSettle();
    expectChallengeUnavailable(tester);
    expect((await db.doc('social_challenges/alice:bob').get()).exists, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'open player options expire challenge availability without a new snapshot',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true, size: const Size(800, 400));
    await openOptions(tester, 'bob');
    expect(option('تحدٍّ مباشر'), findsOneWidget);
    now = now.add(const Duration(seconds: 76));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectChallengeUnavailable(tester);
    expect((await db.doc('social_challenges/alice:bob').get()).exists, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'switching accounts cannot execute an option captured for the old account',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedPlayer('carol');
    final app = _App('alice');
    await pump(tester, app, screen: true, size: const Size(800, 400));
    await openOptions(tester, 'bob');
    app.switchAccount('carol');
    await tester.pumpAndSettle();
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await reveal(tester, option('إضافة صديق'));
      await tester.tap(option('إضافة صديق'));
      await tester.pumpAndSettle();
    }
    expect((await db.doc('social_links/alice:bob').get()).exists, isFalse);
    expect((await db.doc('social_links/bob:carol').get()).exists, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tapping a card opens options then the selected public player profile',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.doc('public_profiles/bob').update({
      'username': 'Opponent public',
      'friendCode': 'PUBLIC89',
      'level': 7,
      'trophies': 890,
    });
    await pump(tester, _App('alice'),
        screen: true, size: const Size(320, 640), textScale: 1.5);
    expect(find.text('تحدٍّ مباشر'), findsNothing);
    expect(find.text('إضافة صديق'), findsNothing);
    expect(find.text('عرض الملف الشخصي'), findsNothing);
    await openOptions(tester, 'bob');
    expect(find.byKey(const ValueKey('playerOptions:bob')), findsOneWidget);
    expect(option('تحدٍّ مباشر'), findsOneWidget);
    expect(option('إضافة صديق'), findsOneWidget);
    await reveal(tester, option('عرض الملف الشخصي'));
    await tester.tap(option('عرض الملف الشخصي'));
    await tester.pumpAndSettle();
    final profile =
        tester.widget<PlayerProfileScreen>(find.byType(PlayerProfileScreen));
    expect(profile.playerUid, 'bob');
    expect(find.text('Opponent public'), findsOneWidget);
    expect(find.text('PUBLIC89'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('player options fit landscape RTL with enlarged text and scroll',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'),
        screen: true, size: const Size(640, 360), textScale: 1.5);
    await openOptions(tester, 'bob');
    await reveal(tester, option('عرض الملف الشخصي'));
    expect(option('عرض الملف الشخصي').hitTestable(), findsOneWidget);
    await reveal(tester, option('حظر اللاعب'));
    expect(option('حظر اللاعب').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeOptions(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an existing friendship can be removed through player options',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: false);
    await service.respond('bob', 'alice:bob', 'accepted', challenge: false);
    await pump(tester, _App('alice'),
        screen: true,
        initialTab: 1,
        size: const Size(320, 640),
        textScale: 1.5);
    await openOptions(tester, 'bob');
    expect(option('إضافة صديق'), findsNothing);
    await reveal(tester, option('إزالة الصديق'));
    await tester.tap(option('إزالة الصديق'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'removed');
    expect(find.byKey(const ValueKey('player:bob')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blocking through player options removes a discovered player',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'), screen: true, size: const Size(800, 400));
    await openOptions(tester, 'bob');
    await reveal(tester, option('حظر اللاعب'));
    await tester.tap(option('حظر اللاعب'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_blocks/alice:bob').get()).exists, isTrue);
    expect(find.byKey(const ValueKey('player:bob')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('privacy player options can unblock a player', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.block('alice', 'bob');
    await pump(tester, _App('alice'),
        screen: true,
        initialTab: 3,
        size: const Size(320, 640),
        textScale: 1.5);
    await openOptions(tester, 'bob');
    await reveal(tester, option('إلغاء الحظر'));
    await tester.tap(option('إلغاء الحظر'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_blocks/alice:bob').get()).exists, isFalse);
    expect(find.byKey(const ValueKey('player:bob')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed profile read does not hide other discoverable players',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedPlayer('healthy');
    service = _FailingProfileSocialService(firestore: db, clock: () => now);
    await pump(tester, _App('alice'),
        screen: true, size: const Size(800, 1600));
    expect(find.text('healthy'), findsOneWidget);
    expect(find.byKey(const ValueKey('player:bob')), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'متصل الآن'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'changing activity never reuses another player profile while loading',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedPlayer('recent', age: const Duration(minutes: 30), state: 'away');
    final delayed =
        _DelayedProfileSocialService(firestore: db, clock: () => now);
    service = delayed;
    await pump(tester, _App('alice'),
        screen: true, size: const Size(800, 1600));
    await tester.tap(find.widgetWithText(ChoiceChip, 'متصل الآن'));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'خلال ساعة'));
    await tester.pumpAndSettle();
    final recent = find.byKey(const ValueKey('player:recent'));
    expect(recent, findsOneWidget);
    expect(
        find.descendant(of: recent, matching: find.text('bob')), findsNothing);
    delayed.delayed.complete({'username': 'recent', 'trophies': 100});
    await tester.pumpAndSettle();
    expect(find.text('recent'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final tab in [1, 2, 3]) {
    testWidgets('social tab $tab fits a narrow RTL phone with larger text',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await service.send('alice', 'bob', challenge: false);
      await service.respond('bob', 'alice:bob', 'accepted', challenge: false);
      await pump(tester, _App('alice'),
          screen: true,
          initialTab: tab,
          size: const Size(320, 640),
          textScale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('requests tab still accepts a dismissed incoming friend request',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: false);
    await pump(tester, _App('bob'),
        screen: true,
        initialTab: 2,
        size: const Size(320, 640),
        textScale: 1.5);
    await tester.tap(find.byKey(const ValueKey('dismissFriendRequest')));
    await tester.pumpAndSettle();
    await openOptions(tester, 'alice');
    final accept = option('قبول');
    await reveal(tester, accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'accepted');
    expect(accept, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('privacy tab still persists discoverability and challenge policy',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, _App('alice'),
        screen: true,
        initialTab: 3,
        size: const Size(320, 640),
        textScale: 1.5);
    await reveal(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
        (await db.doc('social_settings/alice').get()).data()?['discoverable'],
        isFalse);
    await tester.tap(find.descendant(
        of: find.byType(GameNoticeCard),
        matching: find.byIcon(Icons.close_rounded)));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('الجميع'));
    await tester.tap(find.text('الجميع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الأصدقاء فقط').last);
    await tester.pumpAndSettle();
    final settings = (await db.doc('social_settings/alice').get()).data()!;
    expect(settings['discoverable'], isFalse);
    expect(settings['allowChallenges'], 'friends');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'incoming friendship shows sender and can be accepted from any route',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: false);
    final app = _App('bob');
    await pump(tester, app, size: const Size(320, 640), textScale: 1.5);
    expect(find.text('alice أرسل لك طلب صداقة'), findsOneWidget);
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'accepted');
    expect(find.textContaining('أرسل لك طلب صداقة'), findsNothing);
    expect(app.launched, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'dismissed friend request remains in the inbox without reappearing every tick',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.send('alice', 'bob', challenge: false);
    await pump(tester, _App('bob'));
    await tester.tap(find.byKey(const ValueKey('dismissFriendRequest')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('أرسل لك طلب صداقة'), findsNothing);
    expect((await db.doc('social_links/alice:bob').get()).data()?['status'],
        'pending');
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
    final previousRefreshes = stalled.refreshes;
    stalled.stalled = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('player:bob')));
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(stalled.refreshes, greaterThan(previousRefreshes));
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
    await reveal(tester, find.byKey(const ValueKey('player:bob')));
    expect(find.text('bob'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    unawaited(startup.cancel());
    await tester.pump();
  });

  testWidgets('export supplied social design with live fixture players',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Baloo')
          ..addFont(SharedAssets.bundle.load('assets/fonts/baloo.ttf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(
              SharedAssets.bundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(
              SharedAssets.bundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Baloo', fontFamilyFallback: const ['NotoSansArabic']));
    await seedPlayer('recent', age: const Duration(minutes: 10), state: 'away');
    await seedPlayer('another',
        age: const Duration(minutes: 45), state: 'away');
    await seedPlayer('earlier', age: const Duration(hours: 3), state: 'away');
    await seedPlayer('today', age: const Duration(hours: 10), state: 'away');
    await db
        .doc('public_profiles/bob')
        .update({'username': 'أحمد', 'level': 8, 'trophies': 2400});
    await db
        .doc('public_profiles/recent')
        .update({'username': 'ليان', 'level': 4, 'trophies': 360});
    await db
        .doc('public_profiles/another')
        .update({'username': 'سامر', 'level': 12, 'trophies': 1280});
    await service.send('alice', 'bob', challenge: false);
    await service.respond('bob', 'alice:bob', 'accepted', challenge: false);
    final app = _App('alice');
    Future<void> capture(String path) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('social-screen-artwork')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final size in [
      const Size(1100, 620),
      const Size(800, 400),
      const Size(390, 780)
    ]) {
      await pump(tester, app, screen: true, size: size, theme: theme);
      await tester.runAsync(() => precacheImage(
          const AssetImage(socialArtworkAsset),
          tester.element(find.byType(SocialScreen))));
      await tester.pumpAndSettle();
      final name = size.width == 1100
          ? 'desktop'
          : size.width == 800
              ? 'landscape'
              : 'mobile';
      await capture('build/social-$name-ar.png');
      if (size.width == 1100) {
        for (final entry in {
          'أصدقائي': 'friends',
          'الطلبات': 'requests',
          'الخصوصية': 'privacy'
        }.entries) {
          await tester.tap(find.descendant(
              of: find.byType(TabBar), matching: find.text(entry.key)));
          await capture('build/social-${entry.value}-ar.png');
        }
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'switching accounts refreshes native discovery and resets filters',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service = _NativeBroadcastSocialService(firestore: db, clock: () => now);
    final app = _App('alice');
    await pump(tester, app, screen: true, size: const Size(800, 1600));
    expect(find.byKey(const ValueKey('player:bob')), findsOneWidget);
    await reveal(tester, find.widgetWithText(ChoiceChip, 'متصل الآن'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'متصل الآن'));
    await tester.pumpAndSettle();
    app.switchAccount('bob');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'الكل'))
            .selected,
        isTrue);
    expect(find.byKey(const ValueKey('player:alice')), findsOneWidget);
    expect(find.byKey(const ValueKey('player:bob')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
