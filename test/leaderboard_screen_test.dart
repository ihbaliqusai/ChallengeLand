import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/screens/home/leaderboard_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _MockAppState extends ChangeNotifier implements AppState {
  _MockAppState({this.trophyBalance = 1250, this.totalXp = 1500});

  int trophyBalance;
  int totalXp;

  void setTrophies(int value) {
    trophyBalance = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  int get trophies => trophyBalance;

  @override
  int get xp => totalXp;

  @override
  Map<String, int> get playerStats => const {'wins': 4};

  @override
  int get level => 8;

  @override
  String get friendCode => 'TESTCODE99';

  @override
  get user => null;

  @override
  get currentUser => null;

  @override
  Future<void> checkAndAwardXpForGames() async {}

  @override
  Future<void> syncPublicProfile({int? level, int? trophies}) async {}
}

void main() {
  Future<void> pumpBoard(WidgetTester tester, FakeFirebaseFirestore db,
      _MockAppState state) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<AppState>.value(
        value: state,
        child: LeaderboardScreen(firestore: db),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
      'XP ladder includes zero-trophy leaders outside the trophy window',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 201; i++) {
      await db.collection('public_profiles').doc('p$i').set({
        'username': 'منافس $i',
        'trophies': 4000 - i,
        'level': 2,
        'xp': 150,
      });
    }
    await db.collection('public_profiles').doc('knowledge').set({
      'username': 'عالم المعرفة',
      'trophies': 0,
      'level': 1,
      'xp': 50000,
    });
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 10, totalXp: 10));
    expect(find.text('عالم المعرفة'), findsNothing);
    expect(find.text('خارج القائمة'), findsOneWidget);
    expect(find.text('#201'), findsNothing);

    await tester.tap(find.text('أقوياء المستوى'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('عالم المعرفة'),
        ),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'legacy totalScore outside the level window stays on the XP ladder',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 201; i++) {
      await db.collection('public_profiles').doc('level-rival-$i').set({
        'username': 'منافس المستوى $i',
        'trophies': 4000 - i,
        'level': 2,
        'xp': 150,
        'totalScore': 150,
      });
    }
    await db.collection('public_profiles').doc('legacy').set({
      'username': 'خبير سابق',
      'trophies': 0,
      'level': 1,
      'totalScore': 5000,
    });
    await db.collection('public_profiles').doc('modern').set({
      'username': 'منافس جديد',
      'trophies': 100,
      'level': 1,
      'xp': 2000,
    });
    await pumpBoard(tester, db, _MockAppState());
    await tester.tap(find.text('أقوياء المستوى'));
    await tester.pump(const Duration(milliseconds: 500));
    final podium = find.byKey(const ValueKey('leaderboard-podium-1'));
    expect(find.descendant(of: podium, matching: find.text('خبير سابق')),
        findsOneWidget);
    expect(find.text('5.0K XP'), findsWidgets);
    expect(find.text('≥ 5.0K XP'), findsNothing);
    expect(
        find.descendant(
            of: podium,
            matching: find.text('مستوى ${PlayerRank.levelForXp(5000)}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current trophy losses replace stale public trophy balances',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('public_profiles').doc('me').set({
      'username': 'أنا المنافس',
      'friendCode': 'TESTCODE99',
      'trophies': 3000,
      'level': 8,
      'xp': 1500,
    });
    await db.collection('public_profiles').doc('rival').set({
      'username': 'المنافس المتقدم',
      'trophies': 2000,
      'level': 8,
      'xp': 1600,
    });
    final state = _MockAppState(trophyBalance: 1250);
    await pumpBoard(tester, db, state);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('المنافس المتقدم'),
        ),
        findsOneWidget);
    state.setTrophies(2500);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('أنا المنافس'),
        ),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loss below a full trophy window does not invent a rank',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 201; i++) {
      await db.collection('public_profiles').doc('rival$i').set({
        'username': 'منافس $i',
        'trophies': 4000 - i,
        'xp': 100,
      });
    }
    await db.collection('public_profiles').doc('me').set({
      'username': 'صاحب الخسارة',
      'friendCode': 'TESTCODE99',
      'trophies': 4500,
      'xp': 1500,
    });
    final state = _MockAppState(trophyBalance: 1000);
    await pumpBoard(tester, db, state);
    expect(find.text('خارج القائمة'), findsOneWidget);
    expect(find.text('#200'), findsNothing);
    expect(find.text('صاحب الخسارة'), findsNothing);
    expect(tester.takeException(), isNull);

    state.setTrophies(4500);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('صاحب الخسارة'),
        ),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero trophies remove a stale account from the trophy ladder',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('public_profiles').doc('me').set({
      'username': 'صاحب الخبرة فقط',
      'friendCode': 'TESTCODE99',
      'trophies': 500,
      'xp': 1500,
    });
    await db.collection('public_profiles').doc('rival').set({
      'username': 'صاحب الكؤوس',
      'trophies': 200,
      'xp': 100,
    });
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 0));
    expect(find.text('خارج القائمة'), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('صاحب الكؤوس'),
        ),
        findsOneWidget);

    await tester.tap(find.text('أقوياء المستوى'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('صاحب الخبرة فقط'),
        ),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('XP within a level decides the experience podium',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('public_profiles').doc('more-trophies').set({
      'username': 'صاحب الكؤوس',
      'trophies': 4000,
      'level': 2,
      'xp': 125,
    });
    await db.collection('public_profiles').doc('more-xp').set({
      'username': 'صاحب الخبرة',
      'trophies': 10,
      'level': 2,
      'xp': 145,
    });
    await pumpBoard(tester, db, _MockAppState());
    await tester.tap(find.text('أقوياء المستوى'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-podium-1')),
          matching: find.text('صاحب الخبرة'),
        ),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LeaderboardScreen renders top podium and players from firestore',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fakeFirestore = FakeFirebaseFirestore();

    // Populate fake public profiles
    await fakeFirestore.collection('public_profiles').doc('p1').set({
      'uid': 'p1',
      'username': 'فارس الأساطير',
      'trophies': 3500,
      'level': 25,
      'friendCode': 'FARES123',
    });
    await fakeFirestore.collection('public_profiles').doc('p2').set({
      'uid': 'p2',
      'username': 'سيف التحدي',
      'trophies': 2800,
      'level': 18,
      'friendCode': 'SAIF456',
    });
    await fakeFirestore.collection('public_profiles').doc('p3').set({
      'uid': 'p3',
      'username': 'صقر العرب',
      'trophies': 2100,
      'level': 14,
      'friendCode': 'SAQR789',
    });

    final mockState = _MockAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppState>.value(
          value: mockState,
          child: LeaderboardScreen(firestore: fakeFirestore),
        ),
      ),
    );

    // Initial loading pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Title and Tabs
    expect(find.text('لوحة الصدارة'), findsOneWidget);
    expect(find.text('سباق الكؤوس'), findsOneWidget);
    expect(find.text('أقوياء المستوى'), findsOneWidget);
    expect(find.text('خريطة الدوريات'), findsOneWidget);

    // Verify top players appear on podium and list
    expect(find.text('فارس الأساطير'), findsWidgets);
    expect(find.text('سيف التحدي'), findsWidgets);
    expect(find.text('صقر العرب'), findsWidgets);

    // Verify switching to "أقوياء المستوى" tab
    await tester.tap(find.text('أقوياء المستوى'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify switching to "خريطة الدوريات" tab
    await tester.tap(find.text('خريطة الدوريات'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('دليل ورتب الدوريات'), findsOneWidget);
    expect(find.text('مسار الدوريات السبع'), findsOneWidget);

    // Return to "سباق الكؤوس" tab
    await tester.tap(find.text('سباق الكؤوس'));
    await tester.pump(const Duration(milliseconds: 300));

    // Open Trophy Rules Modal via info button
    final infoButton = find.byIcon(Icons.info_outline_rounded);
    expect(infoButton, findsOneWidget);
    await tester.tap(infoButton);
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('نظام احتساب الكؤوس'), findsOneWidget);
    expect(find.text('حسناً، فهمت'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('حسناً، فهمت'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
