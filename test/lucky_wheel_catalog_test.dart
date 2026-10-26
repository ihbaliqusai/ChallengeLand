import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/models/lucky_wheel_prize.dart';
import 'package:challenge_land/services/lucky_wheel_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bridge implements NativeBridgeService {
  Map<String, dynamic>? request;

  @override
  Future<Map<String, dynamic>> economy(Map<String, dynamic> data) async {
    request = data;
    return {
      'spin': {
        'prizeId': 'coins_1000',
        'grants': {'coins': 1000},
        'newlyGranted': true,
        'catalogVersion': 2,
      },
      'state': {'revision': 9, 'wheelCharacterIndex': 4},
      'currency': {'coins': 1400, 'gems': 5},
      'purchasedCharacters': [2],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('quantity variants and disclosed chances cover the complete wheel', () {
    expect(LuckyWheelPrize.catalog, hasLength(12));
    expect(LuckyWheelPrize.catalog.map((prize) => prize.id).toSet(),
        hasLength(12));
    expect(LuckyWheelPrize.catalog.map((prize) => prize.index).toSet(),
        containsAll(List.generate(12, (index) => index)));
    expect(
        LuckyWheelPrize.catalog
            .fold(0.0, (sum, prize) => sum + prize.probability),
        closeTo(1, .000001));
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.coins), .25);
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.gems), .25);
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.keys),
        closeTo(1 / 6, .000001));
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.tickets),
        closeTo(1 / 6, .000001));
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.character),
        closeTo(1 / 12, .000001));
    expect(LuckyWheelPrize.kindProbability(LuckyWheelPrizeKind.chest),
        closeTo(1 / 12, .000001));
    expect(
        LuckyWheelPrize.catalog
            .where((prize) => prize.kind == LuckyWheelPrizeKind.coins)
            .map((prize) => prize.amount),
        unorderedEquals([250, 500, 1000]));
    expect(
        LuckyWheelPrize.catalog
            .where((prize) => prize.kind == LuckyWheelPrizeKind.gems)
            .map((prize) => prize.amount),
        unorderedEquals([5, 10, 20]));
  });

  test('older saved receipts keep their original prize identifiers and indices',
      () {
    final ids = ['keys', 'tickets', 'coins', 'gems', 'character', 'chest'];
    for (var index = 0; index < ids.length; index++) {
      final spin = LuckyWheelSpin.fromMap({
        'prizeId': ids[index],
        'grants': {'coins': 500},
        'newlyGranted': false,
      });
      expect(spin.prize.index, index);
      expect(spin.catalogVersion, 1);
      expect(spin.newlyGranted, isFalse);
    }
  });

  test('the chest contents are one complete guaranteed bundle', () {
    expect(LuckyWheelPrize.byId('chest').grants,
        {'coins': 1000, 'gems': 20, 'keys': 2, 'tickets': 2});
    expect(LuckyWheelPrize.byId('keys_2').grants, {'keys': 2});
    expect(LuckyWheelPrize.byId('tickets_2').grants, {'tickets': 2});
  });

  test(
      'a completed character roster differs from an old wallet with no preview',
      () {
    final legacy = EconomyWallet.fromMap({'revision': 1});
    final completed =
        EconomyWallet.fromMap({'revision': 2, 'wheelCharacterIndex': null});
    final next =
        EconomyWallet.fromMap({'revision': 3, 'wheelCharacterIndex': 4});
    expect(legacy.hasWheelCharacterPreview, isFalse);
    expect(completed.hasWheelCharacterPreview, isTrue);
    expect(completed.wheelCharacterIndex, isNull);
    expect(next.wheelCharacterIndex, 4);
  });

  test('the service requests v2 and preserves the server character preview',
      () async {
    final bridge = _Bridge();
    final result = await LuckyWheelService(bridge: bridge)
        .spin(uid: 'player', operationId: 'existing_receipt');
    expect(bridge.request, {
      'action': 'spinWheel',
      'expectedUid': 'player',
      'operationId': 'existing_receipt',
      'wheelCatalogVersion': 2,
    });
    expect(result.spin.prize.id, 'coins_1000');
    expect(result.spin.catalogVersion, 2);
    expect(result.currency['coins'], 1400);
    expect(result.state['wheelCharacterIndex'], 4);
    expect(result.purchasedCharacters, {2});
  });
}
