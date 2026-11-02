import 'dart:async';

import 'package:challenge_land/models/app_update_policy.dart';
import 'package:challenge_land/services/app_update_service.dart';
import 'package:challenge_land/widgets/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const blocked = AppUpdatePolicy(
    enabled: true, minimumBuild: 50, installedBuild: 49, remotePolicy: true);

class FakeUpdates extends AppUpdateService {
  AppUpdatePolicy cached = const AppUpdatePolicy();
  AppUpdatePolicy refreshed = const AppUpdatePolicy();
  bool failFetch = false, storeOpened = true;
  int storeCalls = 0, fetches = 0;
  bool? lastForced;
  Completer<AppUpdatePolicy>? cachedPending, fetchPending;
  @override
  Future<AppUpdatePolicy> cachedPolicy() async =>
      cachedPending == null ? cached : await cachedPending!.future;
  @override
  Future<AppUpdatePolicy> refreshPolicy({bool force = false}) async {
    fetches++;
    lastForced = force;
    if (failFetch) throw StateError('offline');
    return fetchPending == null ? refreshed : await fetchPending!.future;
  }

  @override
  Future<bool> openStore() async {
    storeCalls++;
    return storeOpened;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Widget host(FakeUpdates service, {Widget? child}) => AppUpdateGate(
      service: service,
      child: child ?? const MaterialApp(home: Text('gameplay')));

  testWidgets('disabled policy allows the game while network work is pending',
      (tester) async {
    final service = FakeUpdates()..fetchPending = Completer();
    await tester.pumpWidget(host(service));
    await tester.pump();
    expect(find.text('gameplay'), findsOneWidget);
    expect(service.fetches, 1);
    service.fetchPending!.complete(const AppUpdatePolicy());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'verified cached block never builds the game and cannot be popped',
      (tester) async {
    final service = FakeUpdates()
      ..cached = blocked
      ..refreshed = blocked;
    var gameBuilds = 0;
    await tester.pumpWidget(host(service, child: Builder(builder: (_) {
      gameBuilds++;
      return const Text('gameplay');
    })));
    await tester.pumpAndSettle();
    expect(gameBuilds, 0);
    expect(find.text('تحديث اللعبة مطلوب'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('تحديث اللعبة مطلوب'), findsOneWidget);
    expect(find.text('gameplay'), findsNothing);
  });

  testWidgets(
      'fetch errors retain a known required update and show retry feedback',
      (tester) async {
    final service = FakeUpdates()
      ..cached = blocked
      ..failFetch = true;
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('required-update-retry')));
    await tester.pumpAndSettle();
    expect(service.lastForced, isTrue);
    expect(find.textContaining('تعذّر التحقق'), findsOneWidget);
    expect(find.text('gameplay'), findsNothing);
  });

  testWidgets('publishing a disabled policy releases the gate on manual retry',
      (tester) async {
    final service = FakeUpdates()
      ..cached = blocked
      ..refreshed = blocked;
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    service.refreshed = const AppUpdatePolicy();
    await tester.tap(find.byKey(const ValueKey('required-update-retry')));
    await tester.pumpAndSettle();
    expect(find.text('gameplay'), findsOneWidget);
    expect(find.text('تحديث اللعبة مطلوب'), findsNothing);
  });

  testWidgets(
      'update opens store and reports an unavailable store without bypass',
      (tester) async {
    final service = FakeUpdates()
      ..cached = blocked
      ..refreshed = blocked;
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('required-update-store')));
    await tester.pumpAndSettle();
    expect(service.storeCalls, 1);
    service.storeOpened = false;
    await tester.tap(find.byKey(const ValueKey('required-update-store')));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذّر فتح المتجر'), findsOneWidget);
    expect(find.text('gameplay'), findsNothing);
  });

  testWidgets(
      'return from store rechecks policy and accepts an up-to-date build',
      (tester) async {
    final service = FakeUpdates()
      ..cached = blocked
      ..refreshed = blocked;
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.refreshed = const AppUpdatePolicy(
        enabled: true,
        minimumBuild: 50,
        installedBuild: 50,
        remotePolicy: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('gameplay'), findsOneWidget);
  });

  testWidgets('late native completion after disposal does not update UI',
      (tester) async {
    final service = FakeUpdates()..cachedPending = Completer();
    await tester.pumpWidget(host(service));
    await tester.pumpWidget(const SizedBox());
    service.cachedPending!.complete(blocked);
    await tester.pump();
    expect(service.fetches, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown offline policy cannot hold startup indefinitely',
      (tester) async {
    final service = FakeUpdates()
      ..cachedPending = Completer()
      ..failFetch = true;
    await tester.pumpWidget(host(service));
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pumpAndSettle();
    expect(find.text('gameplay'), findsOneWidget);
    service.cachedPending!.complete(blocked);
    await tester.pump();
    expect(find.text('gameplay'), findsOneWidget);
  });

  for (final size in [
    const Size(960, 540),
    const Size(480, 270),
    const Size(390, 844)
  ]) {
    testWidgets('blocking screen fits $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = FakeUpdates()
        ..cached = blocked
        ..refreshed = blocked;
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(find.text('تحديث اللعبة مطلوب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
