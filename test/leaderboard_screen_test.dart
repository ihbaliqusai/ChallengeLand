import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/home/leaderboard_screen.dart';
import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _MockUser implements User {
  const _MockUser(this.uid);

  @override
  final String uid;

  @override
  String? get displayName => 'أنا المنافس';
  @override
  String? get email => 'player@example.test';
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String?> _noDeviceCountry() async => null;

class _MockAppState extends ChangeNotifier implements AppState {
  _MockAppState({this.trophyBalance = 1250, String? uid = 'me'})
      : _user = uid == null ? null : _MockUser(uid);

  final User? _user;
  int trophyBalance;

  void setTrophies(int value) {
    trophyBalance = value;
    notifyListeners();
  }

  @override
  int get trophies => trophyBalance;
  @override
  int get xp => 1500;
  @override
  Map<String, int> get playerStats => const {'wins': 4};
  @override
  int get level => 8;
  @override
  String get friendCode => 'TESTCODE99';
  @override
  User? get user => _user;
  @override
  User? get currentUser => _user;
  @override
  Future<void> syncPublicProfile({int? level, int? trophies}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> player(FakeFirebaseFirestore db, String uid, int trophies,
          {String? country, String? name, int xp = 100, String? friendCode}) =>
      db.doc('public_profiles/$uid').set({
        'uid': uid,
        'username': name ?? uid,
        'trophies': trophies,
        'xp': xp,
        if (country != null) 'countryCode': country,
        if (friendCode != null) 'friendCode': friendCode,
      });

  Future<void> link(FakeFirebaseFirestore db, String peer,
          {String status = 'accepted'}) =>
      db.doc('social_links/me:$peer').set({
        'members': ['me', peer],
        'status': status,
      });

  Future<void> globalWindow(FakeFirebaseFirestore db) async {
    for (var i = 0; i < 201; i++) {
      await player(db, 'global-$i', 4000 - i, country: 'US');
    }
  }

  Finder row(String uid) => find.byKey(ValueKey('leaderboard-player-$uid'));

  void expectRank(String uid, int rank) {
    expect(find.descendant(of: row(uid), matching: find.text('$rank')),
        findsOneWidget);
  }

  Future<void> pumpBoard(
      WidgetTester tester, FakeFirebaseFirestore db, _MockAppState state,
      {Size size = const Size(400, 900),
      Future<String?> Function() detectCountry = _noDeviceCountry,
      EdgeInsets? viewportSafeInsets}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      builder: viewportSafeInsets == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: viewportSafeInsets,
                    viewPadding: viewportSafeInsets),
                child: GameViewport(child: child!),
              ),
      home: ChangeNotifierProvider<AppState>.value(
        value: state,
        child: LeaderboardScreen(
          service:
              LeaderboardService(firestore: db, detectCountry: detectCountry),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectTab(WidgetTester tester, String scope) async {
    await tester.tap(find.byKey(ValueKey('leaderboard-tab-$scope')));
    await tester.pumpAndSettle();
  }

  for (final safeInsets in [
    const EdgeInsets.only(left: 64),
    const EdgeInsets.only(right: 64),
  ]) {
    testWidgets('title spans the viewport while controls respect $safeInsets',
        (tester) async {
      const size = Size(1000, 540);
      final db = FakeFirebaseFirestore();
      await player(db, 'me', 15, country: 'TR');
      await player(db, 'leader', 1000, country: 'TR');
      await pumpBoard(tester, db, _MockAppState(trophyBalance: 15),
          size: size, viewportSafeInsets: safeInsets);

      final banner = tester
          .getRect(find.byKey(const ValueKey('leaderboard-title-banner')));
      expect(banner.left, closeTo(0, .01));
      expect(banner.right, closeTo(size.width, .01));

      void expectSafe(Finder finder) {
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(safeInsets.left - .01));
        expect(
            rect.right, lessThanOrEqualTo(size.width - safeInsets.right + .01));
      }

      expectSafe(find.byTooltip('رجوع'));
      for (final scope in ['world', 'country', 'friends']) {
        expectSafe(find.byKey(ValueKey('leaderboard-tab-$scope')));
      }
      expectSafe(find.byKey(const ValueKey('leaderboard-list-world')));
      expectSafe(row('leader'));

      await selectTab(tester, 'country');
      expectSafe(find.byKey(const ValueKey('leaderboard-change-country')));
      expectSafe(find.byKey(const ValueKey('leaderboard-list-country')));
      expectSafe(row('leader'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('country is detected and ranked without opening the picker',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'me', 15);
    await player(db, 'turkey-leader', 200, country: 'TR');
    await player(db, 'other-country', 500, country: 'JO');
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 15),
        detectCountry: () async => 'TR');

    expect(find.text('تركيا'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await selectTab(tester, 'country');
    expectRank('turkey-leader', 1);
    expectRank('me', 2);
    expect(row('other-country'), findsNothing);
    expect(find.text('اختيار البلد'), findsNothing);
    expect((await db.doc('public_profiles/me').get()).data()!['countryCode'],
        'TR');
    expect(tester.takeException(), isNull);
  });

  testWidgets('three top scope tabs rank trophies without a podium or XP tabs',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'me', 300, country: 'JO', xp: 100000);
    await player(db, 'trophy-leader', 1000, country: 'JO', xp: 10);
    await link(db, 'trophy-leader');
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 300));

    expect(find.text('أفضل اللاعبين'), findsOneWidget);
    for (final scope in ['world', 'country', 'friends']) {
      expect(find.byKey(ValueKey('leaderboard-tab-$scope')), findsOneWidget);
    }
    expect(find.text('العالم'), findsOneWidget);
    expect(find.text('الأردن'), findsOneWidget);
    expect(find.text('أصدقائي'), findsOneWidget);
    expect(find.text('أقوياء المستوى'), findsNothing);
    expect(find.text('خريطة الدوريات'), findsNothing);
    expect(find.byKey(const ValueKey('leaderboard-podium-1')), findsNothing);
    final banner = find.byKey(const ValueKey('leaderboard-title-banner'));
    expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('leaderboard-tab-world')))
            .dy,
        lessThanOrEqualTo(tester.getTopLeft(banner).dy));

    for (final scope in ['world', 'country', 'friends']) {
      if (scope != 'world') await selectTab(tester, scope);
      expectRank('trophy-leader', 1);
      expectRank('me', 2);
      expect(tester.getTopLeft(row('trophy-leader')).dy,
          lessThan(tester.getTopLeft(row('me')).dy));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows show sequential ranks and full comma-separated trophies',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'third', 4500);
    await player(db, 'first', 6133450);
    await player(db, 'second', 5493385);
    await pumpBoard(tester, db, _MockAppState());

    expectRank('first', 1);
    expectRank('second', 2);
    expectRank('third', 3);
    expect(find.descendant(of: row('first'), matching: find.text('6,133,450')),
        findsOneWidget);
    expect(find.descendant(of: row('second'), matching: find.text('5,493,385')),
        findsOneWidget);
    expect(find.textContaining('6.1M'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current trophy losses and gains immediately reorder player rows',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'me', 3000, friendCode: 'TESTCODE99');
    await player(db, 'rival', 2000);
    final state = _MockAppState(trophyBalance: 1250);
    await pumpBoard(tester, db, state);
    expectRank('rival', 1);
    expectRank('me', 2);
    expect(find.descendant(of: row('me'), matching: find.text('1,250')),
        findsOneWidget);

    state.setTrophies(2500);
    await tester.pumpAndSettle();
    expectRank('me', 1);
    expectRank('rival', 2);
    expect(find.descendant(of: row('me'), matching: find.text('2,500')),
        findsOneWidget);

    state.setTrophies(0);
    await tester.pumpAndSettle();
    expect(row('me'), findsNothing);
    expectRank('rival', 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loss below the full query window never invents a loaded rank',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await globalWindow(db);
    await player(db, 'me', 4500, friendCode: 'TESTCODE99');
    final state = _MockAppState(trophyBalance: 1000);
    await pumpBoard(tester, db, state);
    expect(row('me'), findsNothing);
    expectRank('global-0', 1);
    final list = tester
        .widget<ListView>(find.byKey(const ValueKey('leaderboard-list-world')));
    expect(list.childrenDelegate.estimatedChildCount, 397);

    state.setTrophies(4500);
    await tester.pumpAndSettle();
    expectRank('me', 1);
    expectRank('global-0', 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'country search saves selection and loads beyond the world window',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await globalWindow(db);
    await player(db, 'me', 15);
    await player(db, 'country-leader', 40, country: 'JO');
    await player(db, 'country-third', 10, country: 'JO');
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 25));
    expect(row('country-leader'), findsNothing);
    await selectTab(tester, 'country');
    expect(find.text('تعذر تحديد بلدك تلقائيًا. اختره للمنافسة مع لاعبيه'),
        findsOneWidget);
    await tester.tap(find.text('اختيار البلد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'jo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leaderboard-country-JO')));
    await tester.pumpAndSettle();

    final saved = (await db.doc('public_profiles/me').get()).data()!;
    expect(saved['countryCode'], 'JO');
    expect(saved['trophies'], 15);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('الأردن'), findsOneWidget);
    expectRank('country-leader', 1);
    expectRank('me', 2);
    expectRank('country-third', 3);
    expect(row('global-0'), findsNothing);
    expect(find.byKey(const ValueKey('leaderboard-change-country')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friends ranks accepted peers outside world top 200 only',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await globalWindow(db);
    await player(db, 'me', 15);
    await player(db, 'friend', 40);
    await player(db, 'new-friend', 0);
    await player(db, 'pending', 60);
    await player(db, 'blocked', 70);
    await player(db, 'unrelated', 80);
    await link(db, 'friend');
    await link(db, 'new-friend');
    await link(db, 'pending', status: 'pending');
    await link(db, 'blocked');
    await db.doc('social_blocks/me:blocked').set({
      'ownerUid': 'me',
      'targetUid': 'blocked',
    });
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 25));
    expect(row('friend'), findsNothing);
    await selectTab(tester, 'friends');
    expectRank('friend', 1);
    expectRank('me', 2);
    expectRank('new-friend', 3);
    for (final excluded in ['pending', 'blocked', 'unrelated', 'global-0']) {
      expect(row(excluded), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out scopes explain how to access country and friends',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'world-player', 100);
    await pumpBoard(tester, db, _MockAppState(uid: null));
    expectRank('world-player', 1);
    await selectTab(tester, 'country');
    expect(find.text('سجّل الدخول لعرض ترتيب بلدك'), findsOneWidget);
    await selectTab(tester, 'friends');
    expect(find.text('سجّل الدخول لعرض ترتيبك بين أصدقائك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('country picker scrolls with a landscape software keyboard',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await player(db, 'me', 15);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pumpBoard(tester, db, _MockAppState(trophyBalance: 15),
        size: const Size(800, 360));
    await selectTab(tester, 'country');
    await tester.ensureVisible(find.text('اختيار البلد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختيار البلد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'jo');
    await tester.pumpAndSettle();
    final jordan = find.byKey(const ValueKey('leaderboard-country-JO'));
    await tester.ensureVisible(jordan);
    await tester.pumpAndSettle();
    await tester.tap(jordan);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect((await db.doc('public_profiles/me').get()).data()!['countryCode'],
        'JO');
    expectRank('me', 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(400, 900),
    const Size(960, 540),
    const Size(320, 568),
  ]) {
    testWidgets('rows and profile modal fit ${size.width}x${size.height}',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await player(db, 'long-name', 2147483647,
          name: 'لاعب الأساطير صاحب الاسم الطويل جدًا للمنافسة العالمية',
          country: 'JO',
          friendCode: 'LONGPLAYER');
      await player(db, 'second', 6133450);
      await player(db, 'third', 3);
      await pumpBoard(tester, db, _MockAppState(), size: size);
      expectRank('long-name', 1);
      expect(
          find.descendant(
              of: row('long-name'), matching: find.text('2,147,483,647')),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(row('long-name'));
      await tester.pumpAndSettle();
      expect(find.text('المركز 1 • 2,147,483,647 كأس'), findsOneWidget);
      expect(find.text('كود الصداقة: LONGPLAYER'), findsOneWidget);
      expect(find.text('تحدي اللاعب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
