import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/auth_service.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuth implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final granted in [true, false]) {
    test('currency balances accept the native granted=$granted receipt',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'grantCurrency');
        expect(call.arguments,
            {'coins': 0, 'gems': 80, 'claimId': 'player:reward'});
        return {'coins': 500, 'gems': 90, 'granted': granted};
      });

      final balances = await NativeBridgeService().grantCurrency(
        gems: 80,
        claimId: 'player:reward',
      );

      // A replay returns the current wallet without paying the reward again.
      expect(balances, {'coins': 500, 'gems': 90});
    });
  }

  test('a native payout error still propagates to the reward caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'CURRENCY_GRANT_FAILED');
    });

    await expectLater(
      NativeBridgeService().grantCurrency(gems: 80),
      throwsA(isA<PlatformException>()),
    );
  });

  testWidgets('download reward updates the wallet and can only be claimed once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var nativeGems = 10;
    var payouts = 0;
    Map<String, dynamic>? payoutArgs;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAppInstalled':
          return true;
        case 'getCategoryState':
        case 'getCommerceState':
          return <String, dynamic>{};
        case 'grantCurrency':
          payouts++;
          final args = Map<String, dynamic>.from(call.arguments as Map);
          payoutArgs = args;
          nativeGems += args['gems'] as int;
          return {'coins': 500, 'gems': nativeGems, 'granted': true};
        default:
          throw StateError('Unexpected native call: ${call.method}');
      }
    });
    final bridge = NativeBridgeService();
    final state = AppState(
      authService: _SignedOutAuth(),
      nativeBridgeService: bridge,
      firestore: FakeFirebaseFirestore(),
    );
    final promo = CrossPromoService(bridge: bridge);
    addTearDown(state.dispose);
    addTearDown(promo.dispose);
    late BuildContext claimContext;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        claimContext = context;
        return const SizedBox.shrink();
      }))),
    ));
    await tester.pump();

    final first = promo.claimDownloadReward(claimContext);
    await tester.pump();
    expect(await first, CrossPromoClaimResult.success);
    expect(
        payoutArgs, {'coins': 0, 'gems': CrossPromoService.downloadRewardGems});
    expect(state.coins, 500);
    expect(state.gems, 90);
    expect(promo.isRewardClaimed, isTrue);
    expect(promo.isClaiming, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cross_promo.millionaire.reward_claimed'), isTrue);

    final retry = promo.claimDownloadReward(claimContext);
    await tester.pump();
    expect(await retry, CrossPromoClaimResult.alreadyClaimed);
    expect(nativeGems, 90);
    expect(payouts, 1);

    // The completion marker also survives recreating the promotion service.
    final restoredPromo = CrossPromoService(bridge: bridge);
    addTearDown(restoredPromo.dispose);
    await tester.pump();
    expect(await restoredPromo.checkRewardClaimed(), isTrue);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
