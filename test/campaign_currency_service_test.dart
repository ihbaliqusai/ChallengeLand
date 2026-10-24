import 'package:challenge_land/services/campaign_currency_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late CampaignCurrencyService service;

  setUp(() {
    firestore = _MergeAwareFirestore();
    service = CampaignCurrencyService(firestore: firestore);
  });

  test('a claim can be retried from another instance without another increase',
      () async {
    await firestore.doc('users/player').set({'coins': 100, 'gems': 7});
    final first = await service.grant(
      uid: 'player',
      claimId: 'base:stage_001',
      coins: 10,
      gems: 2,
    );
    final restored = CampaignCurrencyService(firestore: firestore);
    final replay = await restored.grant(
      uid: 'player',
      claimId: 'base:stage_001',
      coins: 10,
      gems: 2,
      fallbackCoins: 999,
      fallbackGems: 999,
    );
    expect(first, {'coins': 110, 'gems': 9});
    expect(replay, first);
    final stored = (await firestore.doc('users/player').get()).data()!;
    expect(stored['coins'], 110);
    expect(stored['gems'], 9);
    expect(stored['appliedCampaignCurrencyClaimIds'], ['base:stage_001']);
  });

  test('balances saturate at the native int limit without overflow on retries',
      () async {
    const maximum = CampaignCurrencyService.maxBalance;
    await firestore.doc('users/player').set({
      'coins': maximum - 2,
      'gems': maximum - 1,
    });
    final granted = await service.grant(
      uid: 'player',
      claimId: 'overflow',
      coins: 10,
      gems: 5,
    );
    final replay = await service.grant(
      uid: 'player',
      claimId: 'overflow',
      coins: 10,
      gems: 5,
    );
    expect(granted, {'coins': maximum, 'gems': maximum});
    expect(replay, granted);
    final stored = (await firestore.doc('users/player').get()).data()!;
    expect(stored['coins'], maximum);
    expect(stored['gems'], maximum);
  });

  test('huge cloud values, rewards and fallbacks remain native safe', () async {
    const huge = 9223372036854775807;
    const maximum = CampaignCurrencyService.maxBalance;
    await firestore.doc('users/player').set({'coins': huge});
    expect(
        await service.grant(
          uid: 'player',
          claimId: 'large',
          coins: huge,
          gems: huge,
          fallbackGems: huge,
        ),
        {'coins': maximum, 'gems': maximum});
  });

  test('hasClaimed restores base and doubled reward status without writing',
      () async {
    expect(await service.hasClaimed(uid: 'player', claimId: 'double:one'),
        isFalse);
    expect((await firestore.collection('users').get()).docs, isEmpty);
    await service.grant(
      uid: 'player',
      claimId: 'base:one',
      coins: 12,
      gems: 1,
    );
    expect(
        await service.hasClaimed(uid: 'player', claimId: 'base:one'), isTrue);
    expect(await service.hasClaimed(uid: 'player', claimId: 'double:one'),
        isFalse);
    await service.grant(
      uid: 'player',
      claimId: 'double:one',
      coins: 12,
      gems: 1,
    );
    final restored = CampaignCurrencyService(firestore: firestore);
    expect(await restored.hasClaimed(uid: ' player ', claimId: ' double:one '),
        isTrue);
    expect(await restored.hasClaimed(uid: 'other', claimId: 'double:one'),
        isFalse);
    expect((await firestore.doc('users/player').get()).data()!['coins'], 24);
  });

  test('hasClaimed preserves read failures and validates identity', () async {
    final failing = CampaignCurrencyService(firestore: _UnavailableFirestore());
    await expectLater(failing.hasClaimed(uid: 'player', claimId: 'double:one'),
        throwsA(isA<FirebaseException>()));
    await expectLater(service.hasClaimed(uid: 'users/player', claimId: 'one'),
        throwsArgumentError);
    await expectLater(
        service.hasClaimed(uid: 'player', claimId: ' '), throwsArgumentError);
  });

  test('base and doubled rewards have independent durable receipts', () async {
    await service.grant(
      uid: 'player',
      claimId: 'base:stage_001',
      coins: 12,
      gems: 1,
    );
    final doubled = await service.grant(
      uid: 'player',
      claimId: 'double:stage_001',
      coins: 12,
      gems: 1,
    );
    await service.grant(
      uid: 'player',
      claimId: 'double:stage_001',
      coins: 12,
      gems: 1,
    );
    final next = await service.grant(
      uid: 'player',
      claimId: 'base:stage_002',
      coins: 30,
      gems: 3,
    );
    expect(doubled, {'coins': 24, 'gems': 2});
    expect(next, {'coins': 54, 'gems': 5});
    expect(
        (await firestore.doc('users/player').get())
            .data()!['appliedCampaignCurrencyClaimIds'],
        ['base:stage_001', 'double:stage_001', 'base:stage_002']);
  });

  test('currency updates preserve profile and unrelated commerce fields',
      () async {
    final original = <String, dynamic>{
      'coins': 100,
      'gems': 1,
      'xp': 300,
      'displayName': 'لاعب',
      'profile': {'theme': 'blue'},
      'appliedCommerceDeliveryIds': ['purchase_receipt'],
    };
    await firestore.doc('users/player').set(original);
    await service.grant(
      uid: 'player',
      claimId: 'campaign_receipt',
      coins: 5,
      gems: 2,
    );
    final stored = (await firestore.doc('users/player').get()).data()!;
    expect(stored['coins'], 105);
    expect(stored['gems'], 3);
    for (final key in [
      'xp',
      'displayName',
      'profile',
      'appliedCommerceDeliveryIds'
    ]) {
      expect(stored[key], original[key]);
    }
  });

  test('a new cloud profile preserves captured fallback balances', () async {
    final balances = await service.grant(
      uid: ' player ',
      claimId: ' first ',
      coins: 8,
      gems: 1,
      fallbackCoins: 50,
      fallbackGems: 4,
    );
    expect(balances, {'coins': 58, 'gems': 5});
    expect(
        (await firestore.doc('users/player').get())
            .data()!['appliedCampaignCurrencyClaimIds'],
        ['first']);
  });

  test('zero rewards record a receipt and cannot later change its amount',
      () async {
    await firestore.doc('users/player').set({'coins': 50, 'gems': 2});
    final zero = await service.grant(
      uid: 'player',
      claimId: 'zero',
      coins: 0,
      gems: 0,
    );
    final retry = await service.grant(
      uid: 'player',
      claimId: 'zero',
      coins: 100,
      gems: 10,
    );
    expect(zero, {'coins': 50, 'gems': 2});
    expect(retry, zero);
  });

  test(
      'malformed balances use fallback and malformed receipts retain valid IDs',
      () async {
    await firestore.doc('users/player').set({
      'coins': 'invalid',
      'gems': -5,
      'appliedCampaignCurrencyClaimIds': [12, ' old ', null, 'old', ''],
    });
    final balances = await service.grant(
      uid: 'player',
      claimId: 'new',
      coins: 4,
      gems: 1,
      fallbackCoins: 12,
      fallbackGems: 3,
    );
    expect(balances, {'coins': 16, 'gems': 4});
    expect(
        (await firestore.doc('users/player').get())
            .data()!['appliedCampaignCurrencyClaimIds'],
        ['old', 'new']);
    final previous = await service.grant(
      uid: 'player',
      claimId: 'old',
      coins: 100,
      gems: 100,
    );
    expect(previous, balances);
  });

  test('legacy numeric strings and a malformed receipt collection recover',
      () async {
    await firestore.doc('users/player').set({
      'coins': ' 25 ',
      'gems': 2.0,
      'appliedCampaignCurrencyClaimIds': false,
    });
    expect(
        await service.grant(
          uid: 'player',
          claimId: 'one',
          coins: 5,
          gems: 1,
        ),
        {'coins': 30, 'gems': 3});
    expect(
        await service.grant(
          uid: 'player',
          claimId: 'one',
          coins: 5,
          gems: 1,
        ),
        {'coins': 30, 'gems': 3});
  });

  test('different players can use the same receipt independently', () async {
    await service.grant(uid: 'first', claimId: 'same', coins: 5, gems: 1);
    final second = await service.grant(
      uid: 'second',
      claimId: 'same',
      coins: 5,
      gems: 1,
    );
    expect(second, {'coins': 5, 'gems': 1});
    expect((await firestore.collection('users').get()).docs, hasLength(2));
  });

  test('invalid identities and negative rewards fail without creating users',
      () async {
    for (final uid in ['', ' ', 'users/player', '.', '..']) {
      await expectLater(
          service.grant(
            uid: uid,
            claimId: 'receipt',
            coins: 1,
            gems: 1,
          ),
          throwsArgumentError);
    }
    await expectLater(
        service.grant(
          uid: 'player',
          claimId: ' ',
          coins: 1,
          gems: 1,
        ),
        throwsArgumentError);
    await expectLater(
        service.grant(
          uid: 'player',
          claimId: 'receipt',
          coins: -1,
          gems: 0,
        ),
        throwsArgumentError);
    await expectLater(
        service.grant(
          uid: 'player',
          claimId: 'receipt',
          coins: 0,
          gems: -1,
        ),
        throwsArgumentError);
    expect((await firestore.collection('users').get()).docs, isEmpty);
  });

  test('database failures propagate so callers can retain the pending reward',
      () async {
    final failing = CampaignCurrencyService(firestore: _UnavailableFirestore());
    await expectLater(
        failing.grant(
          uid: 'player',
          claimId: 'receipt',
          coins: 5,
          gems: 1,
        ),
        throwsA(isA<FirebaseException>()
            .having((error) => error.code, 'code', 'unavailable')));
  });
}

class _UnavailableFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

// fake_cloud_firestore 3.1.0 drops SetOptions in _DummyTransaction.set.
// Forward the options to the fake document so merge tests exercise the same
// behavior as Firestore instead of replacing unrelated profile fields.
class _MergeAwareFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) =>
      super.runTransaction<T>(
        (transaction) =>
            transactionHandler(_MergeAwareTransaction(transaction)),
        timeout: timeout,
        maxAttempts: maxAttempts,
      );
}

class _MergeAwareTransaction implements Transaction {
  _MergeAwareTransaction(this.delegate);
  final Transaction delegate;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) =>
      delegate.get(ref);

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    ref.set(data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    delegate.update(ref, data);
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    delegate.delete(ref);
    return this;
  }
}
