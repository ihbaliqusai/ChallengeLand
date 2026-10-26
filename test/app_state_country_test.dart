import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/auth_service.dart';
import 'package:challenge_land/services/leaderboard_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User implements User {
  const _User(this.uid);
  @override
  final String uid;
  @override
  String get displayName => 'Player $uid';
  @override
  String get email => '$uid@example.test';
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthService {
  final changes = StreamController<User?>.broadcast(sync: true);
  User? account;
  @override
  User? get currentUser => account;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  void emit(String? uid) {
    account = uid == null ? null : _User(uid);
    changes.add(account);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountryRequest {
  _CountryRequest(this.uid, this.isActive);
  final String uid;
  final bool Function() isActive;
  final completion = Completer<String?>();
}

class _Countries implements LeaderboardService {
  final requests = <_CountryRequest>[];
  final applied = <String>[];
  @override
  Future<String?> ensureCountry(String uid,
      {required bool Function() isActive}) async {
    final request = _CountryRequest(uid, isActive);
    requests.add(request);
    final code = await request.completion.future;
    if (!isActive()) return null;
    if (code != null) applied.add(uid);
    return code;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Native implements NativeBridgeService {
  String? boundUid;
  Completer<void>? hydrationGate;
  Completer<void>? resetGate;
  int resetCalls = 0;

  @override
  Future<void> syncLegacyUser({
    required String uid,
    required String username,
    String? photoUrl,
  }) async {
    await hydrationGate?.future;
    boundUid = uid;
  }

  @override
  Future<void> resetLegacyUser() async {
    resetCalls++;
    await resetGate?.future;
    boundUid = null;
  }

  @override
  Future<Map<String, dynamic>> getCategoryState() async => {
        'unlocked': <String>[],
        'rentals': <String, int>{},
      };
  @override
  Future<Map<String, dynamic>> getCommerceState() async => {};
  @override
  Future<bool> hydrateCommerceWallet({
    required String accountUid,
    required int coins,
    required int gems,
    int? referralRevision,
    required List<String> deliveryIds,
  }) async =>
      true;
  @override
  Future<bool> setCategoryState({
    required List<String> unlocked,
    required bool isVip,
  }) async =>
      true;
  @override
  Future<bool> setCharacterState({
    required int selected,
    required List<int> unlocked,
  }) async =>
      true;
  @override
  Future<Map<String, dynamic>> getProgressionSnapshot() async => {
        'accountUid': boundUid,
        'deviceId': 'country-test-installation',
        'stats': <String, int>{},
        'contributions': <String, int>{},
      };
  @override
  Future<Map<String, dynamic>> hydrateProgression({
    required String accountUid,
    required Map<String, int> stats,
    required Map<String, int> acknowledged,
  }) async =>
      {'accountUid': accountUid, 'stats': stats};
  @override
  Future<bool> restorePurchases() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _drain() async {
  for (var i = 0; i < 16; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue);
}

class _Harness {
  final auth = _Auth();
  final native = _Native();
  final countries = _Countries();
  late final state = AppState(
    authService: auth,
    nativeBridgeService: native,
    firestore: FakeFirebaseFirestore(),
    leaderboardService: countries,
  );
  bool disposed = false;

  void dispose() {
    state.dispose();
    disposed = true;
  }

  Future<void> close() async {
    if (!disposed) auth.emit(null);
    for (final gate in [native.hydrationGate, native.resetGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    for (final request in countries.requests) {
      if (!request.completion.isCompleted) request.completion.complete();
    }
    await _drain();
    if (!disposed) dispose();
    await auth.changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restored session starts country work before blocked account hydration',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    h.native.hydrationGate = Completer<void>();
    h.state;
    h.auth.emit('alice');
    expect(h.countries.requests.map((r) => r.uid), ['alice']);
    expect(h.countries.requests.single.isActive(), isTrue);
    expect(h.state.isAccountReady, isFalse);

    h.countries.requests.single.completion.complete('JO');
    await _drain();
    expect(h.countries.applied, ['alice']);
    expect(h.native.hydrationGate!.isCompleted, isFalse);
    expect(h.state.isAccountReady, isFalse);
  });

  test('slow country detection never delays normal account readiness',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    h.state;
    h.auth.emit('alice');
    await _until(() => h.state.isAccountReady);
    expect(h.state.isCommerceReady, isTrue);
    expect(h.countries.requests.single.completion.isCompleted, isFalse);
    expect(h.state.user?.uid, 'alice');
  });

  test(
      'account switch starts its own country work before a blocked native reset',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    h.native.hydrationGate = Completer<void>();
    h.state;
    h.auth.emit('alice');
    final oldRequest = h.countries.requests.single;
    h.native.resetGate = Completer<void>();
    h.auth.emit('bob');

    expect(h.countries.requests.map((r) => r.uid), ['alice', 'bob']);
    expect(h.native.resetCalls, 1);
    expect(h.native.resetGate!.isCompleted, isFalse);
    expect(oldRequest.isActive(), isFalse);
    expect(h.countries.requests.last.isActive(), isTrue);
    oldRequest.completion.complete('JO');
    h.countries.requests.last.completion.complete('EG');
    await _drain();
    expect(h.countries.applied, ['bob']);
    expect(h.state.user?.uid, 'bob');
  });

  test('sign-out invalidates pending automatic country work', () async {
    final h = _Harness();
    addTearDown(h.close);
    h.state;
    h.auth.emit('alice');
    await _until(() => h.state.isAccountReady);
    final request = h.countries.requests.single;
    h.auth.emit(null);
    expect(request.isActive(), isFalse);
    request.completion.complete('JO');
    await _drain();
    expect(h.countries.applied, isEmpty);
    expect(h.countries.requests, hasLength(1));
  });

  test('disposing AppState invalidates pending country work', () async {
    final h = _Harness();
    addTearDown(h.close);
    h.state;
    h.auth.emit('alice');
    await _until(() => h.state.isAccountReady);
    await _drain();
    final request = h.countries.requests.single;
    h.dispose();
    expect(request.isActive(), isFalse);
    request.completion.complete('JO');
    await _drain();
    expect(h.countries.applied, isEmpty);
  });

  test('country failure is contained and never breaks authentication',
      () async {
    final h = _Harness();
    addTearDown(h.close);
    h.state;
    h.auth.emit('alice');
    h.countries.requests.single.completion
        .completeError(StateError('country unavailable'));
    await _until(() => h.state.isAccountReady);
    await _drain();
    expect(h.state.user?.uid, 'alice');
    expect(h.state.isCommerceReady, isTrue);
    expect(h.state.error, isNull);
    expect(h.countries.applied, isEmpty);
  });
}
