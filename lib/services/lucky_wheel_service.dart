import '../models/lucky_wheel_prize.dart';
import 'native_bridge_service.dart';

/// A server rejection proves this request did not spend a spin or grant a prize.
class LuckyWheelRequestRejected implements Exception {
  const LuckyWheelRequestRejected({required this.code, required this.message});
  final String code;
  final String message;
}

class LuckyWheelDelivery {
  const LuckyWheelDelivery({
    required this.spin,
    required this.state,
    required this.currency,
    required this.purchasedCharacters,
  });

  final LuckyWheelSpin spin;
  final Map<String, dynamic> state;
  final Map<String, int> currency;
  final Set<int> purchasedCharacters;
}

/// Selection, the daily gate, and every grant are committed by gameEconomy.
class LuckyWheelService {
  const LuckyWheelService({required NativeBridgeService bridge})
      : _bridge = bridge;

  final NativeBridgeService _bridge;

  Future<LuckyWheelDelivery> spin({
    required String uid,
    required String operationId,
  }) async {
    if (uid.isEmpty || uid.contains('/')) throw ArgumentError.value(uid, 'uid');
    final result = await _bridge.economy({
      'action': 'spinWheel',
      'expectedUid': uid,
      'operationId': operationId,
      'wheelCatalogVersion': LuckyWheelPrize.currentCatalogVersion,
    });
    if (result['wheelRejection'] is Map) {
      final rejection =
          Map<String, dynamic>.from(result['wheelRejection'] as Map);
      throw LuckyWheelRequestRejected(
        code: rejection['code']?.toString() ?? '',
        message: rejection['message']?.toString() ?? 'تعذّر إتمام اللفة.',
      );
    }
    if (result['spin'] is! Map || result['currency'] is! Map) {
      throw const FormatException('Invalid wheel delivery');
    }
    final currency = Map<String, dynamic>.from(result['currency'] as Map);
    if (currency['coins'] is! num || currency['gems'] is! num) {
      throw const FormatException('Invalid wheel balances');
    }
    return LuckyWheelDelivery(
      spin: LuckyWheelSpin.fromMap(
          Map<String, dynamic>.from(result['spin'] as Map)),
      state: Map<String, dynamic>.from(result['state'] as Map? ?? {}),
      currency: {
        'coins': (currency['coins'] as num).toInt(),
        'gems': (currency['gems'] as num).toInt(),
      },
      purchasedCharacters: {
        for (final index in result['purchasedCharacters'] as List? ?? const [])
          if (index is num && index >= 0 && index < 16) index.toInt(),
      },
    );
  }
}
