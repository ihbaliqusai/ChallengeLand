import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/home/leaderboard_screen.dart';
import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  const _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _State extends ChangeNotifier implements AppState {
  User? _user = const _User('me');
  Future<void> synchronization = Future<void>.value();
  int syncCalls = 0;

  void changeAccount(String uid) {
    _user = _User(uid);
    notifyListeners();
  }

  @override
  User? get currentUser => _user;
  @override
  User? get user => _user;
  @override
  String get friendCode => 'code-${_user?.uid}';
  @override
  int get trophies => 100;
  @override
  int get level => 2;
  @override
  int get xp => 200;
  @override
  Map<String, int> get playerStats => const {'wins': 1};
  @override
  Future<void> syncPublicProfile({int? level, int? trophies}) {
    syncCalls++;
    return synchronization;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _key(LeaderboardScope scope, String? uid, String? country) =>
    '${uid ?? ''}:${scope.name}:${scope == LeaderboardScope.country ? country ?? '' : ''}';

class _Read {
  _Read(this.scope, this.uid, this.countryCode) {
    controller = StreamController<List<LeaderboardPlayer>>(
      onCancel: () => cancelled = true,
    );
  }
  final LeaderboardScope scope;
  final String? uid;
  final String? countryCode;
  late final StreamController<List<LeaderboardPlayer>> controller;
  bool cancelled = false;
}

class _Service implements LeaderboardService {
  final reads = <_Read>[];
  final results = <String, List<LeaderboardPlayer>>{};
  final countries = <String, String>{};
  Future<String?> Function(String uid) countryRead = (_) async => null;

  @override
  List<LeaderboardPlayer>? cached({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) =>
      results[_key(scope, uid, countryCode)];

  @override
  String? cachedCountry(String uid) => countries[uid];

  @override
  Future<String?> loadCountry(String uid) => countryRead(uid);

  @override
  Stream<List<LeaderboardPlayer>> watch({
    required LeaderboardScope scope,
    String? uid,
    String? countryCode,
  }) {
    final read = _Read(scope, uid, countryCode);
    reads.add(read);
    return read.controller.stream;
  }

  _Read latest(LeaderboardScope scope, {String uid = 'me'}) =>
      reads.lastWhere((read) => read.scope == scope && read.uid == uid);

  void emit(_Read read, String playerUid, {int trophies = 500}) {
    final players = [
      LeaderboardPlayer(
        uid: playerUid,
        username: playerUid,
        trophies: trophies,
      ),
    ];
    results[_key(read.scope, read.uid, read.countryCode)] =
        List<LeaderboardPlayer>.unmodifiable(players);
    read.controller.add(players);
  }

  Future<void> dispose() async {
    for (final read in reads) {
      await read.controller.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Finder row(String uid) => find.byKey(ValueKey('leaderboard-player-$uid'));

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> pumpBoard(
      WidgetTester tester, _Service service, _State state) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<AppState>.value(
        value: state,
        child: LeaderboardScreen(service: service),
      ),
    ));
    await frame(tester);
  }

  Future<void> tab(WidgetTester tester, LeaderboardScope scope) async {
    await tester.tap(find.byKey(ValueKey('leaderboard-tab-${scope.name}')));
    await frame(tester);
  }

  testWidgets('ranking starts before a slow progression synchronization',
      (tester) async {
    final sync = Completer<void>();
    final service = _Service();
    final state = _State()..synchronization = sync.future;
    await pumpBoard(tester, service, state);
    service.emit(service.latest(LeaderboardScope.world), 'world-leader');
    await frame(tester);

    expect(sync.isCompleted, isFalse);
    expect(row('world-leader'), findsOneWidget);
    expect(state.syncCalls, 1);
    expect(tester.takeException(), isNull);
    sync.complete();
  });

  testWidgets('world and friends do not wait for the country profile read',
      (tester) async {
    final country = Completer<String?>();
    final service = _Service()..countryRead = (_) => country.future;
    await pumpBoard(tester, service, _State());
    service.emit(service.latest(LeaderboardScope.world), 'world-leader');
    await frame(tester);
    expect(row('world-leader'), findsOneWidget);

    await tab(tester, LeaderboardScope.friends);
    service.emit(service.latest(LeaderboardScope.friends), 'friend-leader');
    await frame(tester);
    expect(country.isCompleted, isFalse);
    expect(row('friend-leader'), findsOneWidget);
    expect(row('world-leader'), findsNothing);
    expect(tester.takeException(), isNull);
    country.complete(null);
  });

  testWidgets('a failed country read does not replace loaded world players',
      (tester) async {
    final country = Completer<String?>();
    final service = _Service()..countryRead = (_) => country.future;
    await pumpBoard(tester, service, _State());
    service.emit(service.latest(LeaderboardScope.world), 'world-leader');
    await frame(tester);
    country.completeError(StateError('country unavailable'));
    await frame(tester);

    expect(row('world-leader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to a scope shows its cached players immediately',
      (tester) async {
    final service = _Service();
    await pumpBoard(tester, service, _State());
    service.emit(service.latest(LeaderboardScope.world), 'world-leader');
    await frame(tester);
    await tab(tester, LeaderboardScope.friends);
    service.emit(service.latest(LeaderboardScope.friends), 'friend-leader');
    await frame(tester);

    await tab(tester, LeaderboardScope.world);
    expect(row('world-leader'), findsOneWidget);
    expect(row('friend-leader'), findsNothing);
    // No fresh stream event was needed to restore the correct scope.
    service.emit(service.latest(LeaderboardScope.world), 'new-world-leader');
    await frame(tester);
    expect(row('new-world-leader'), findsOneWidget);
    expect(row('world-leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'refresh keeps previous players visible until fresh results arrive',
      (tester) async {
    final service = _Service();
    await pumpBoard(tester, service, _State());
    final initial = service.latest(LeaderboardScope.world);
    service.emit(initial, 'previous-leader');
    await frame(tester);

    unawaited(tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show());
    await tester.pump(const Duration(milliseconds: 400));
    await frame(tester);
    expect(row('previous-leader'), findsOneWidget);

    service.emit(service.latest(LeaderboardScope.world), 'refreshed-leader');
    await frame(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(row('refreshed-leader'), findsOneWidget);
    expect(row('previous-leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh errors keep already displayed players', (tester) async {
    final service = _Service();
    await pumpBoard(tester, service, _State());
    service.emit(service.latest(LeaderboardScope.world), 'previous-leader');
    await frame(tester);
    unawaited(tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show());
    await tester.pump(const Duration(milliseconds: 400));
    await frame(tester);
    service
        .latest(LeaderboardScope.world)
        .controller
        .addError(StateError('offline'));
    await frame(tester);

    expect(row('previous-leader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'late events from the previous scope cannot overwrite current rows',
      (tester) async {
    final service = _Service();
    await pumpBoard(tester, service, _State());
    final oldWorld = service.latest(LeaderboardScope.world);
    service.emit(oldWorld, 'world-leader');
    await frame(tester);
    await tab(tester, LeaderboardScope.friends);
    expect(oldWorld.cancelled, isTrue);
    service.emit(service.latest(LeaderboardScope.friends), 'friend-leader');
    await frame(tester);
    service.emit(oldWorld, 'late-world-leader');
    await frame(tester);

    expect(row('friend-leader'), findsOneWidget);
    expect(row('late-world-leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing account clears the previous accounts cached scope',
      (tester) async {
    final service = _Service();
    final state = _State();
    await pumpBoard(tester, service, state);
    await tab(tester, LeaderboardScope.friends);
    final oldFriends = service.latest(LeaderboardScope.friends);
    service.emit(oldFriends, 'old-private-friend');
    await frame(tester);

    state.changeAccount('next');
    await frame(tester);
    expect(row('old-private-friend'), findsNothing);
    expect(oldFriends.cancelled, isTrue);
    service.emit(
        service.latest(LeaderboardScope.friends, uid: 'next'), 'next-friend');
    await frame(tester);
    expect(row('next-friend'), findsOneWidget);
    expect(row('old-private-friend'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening a board displays its memory cache before stream data',
      (tester) async {
    final service = _Service();
    service.results[_key(LeaderboardScope.world, 'me', null)] = const [
      LeaderboardPlayer(
        uid: 'cached-world-leader',
        username: 'cached-world-leader',
        trophies: 900,
      ),
    ];
    await pumpBoard(tester, service, _State());

    expect(row('cached-world-leader'), findsOneWidget);
    service.emit(
        service.latest(LeaderboardScope.world), 'current-world-leader');
    await frame(tester);
    expect(row('current-world-leader'), findsOneWidget);
    expect(row('cached-world-leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a previous accounts late country cannot select the new board',
      (tester) async {
    final previousCountry = Completer<String?>();
    final nextCountry = Completer<String?>();
    final service = _Service()
      ..countryRead =
          (uid) => uid == 'me' ? previousCountry.future : nextCountry.future;
    final state = _State();
    await pumpBoard(tester, service, state);
    service.emit(service.latest(LeaderboardScope.world), 'old-world-leader');
    await frame(tester);
    state.changeAccount('next');
    await frame(tester);
    service.emit(service.latest(LeaderboardScope.world, uid: 'next'),
        'next-world-leader');
    previousCountry.complete('JO');
    await frame(tester);
    expect(row('next-world-leader'), findsOneWidget);
    expect(row('old-world-leader'), findsNothing);

    await tab(tester, LeaderboardScope.country);
    expect(
        service.reads.where((read) =>
            read.scope == LeaderboardScope.country && read.uid == 'next'),
        isEmpty);
    nextCountry.complete('TR');
    await frame(tester);
    final country = service.latest(LeaderboardScope.country, uid: 'next');
    expect(country.countryCode, 'TR');
    service.emit(country, 'turkey-leader');
    await frame(tester);
    expect(row('turkey-leader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
