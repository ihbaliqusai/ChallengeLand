import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final error in [
    PlatformException(code: 'NOT_FOUND', message: 'NOT_FOUND'),
    PlatformException(code: 'UNIMPLEMENTED'),
    PlatformException(code: 'FRIEND_STAKES_FAILED', message: 'Not_found'),
  ]) {
    test('paid challenge explains unavailable callable: ${error.code}',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'friendStakes');
        throw error;
      });

      await expectLater(
        NativeBridgeService().friendStakes({'action': 'invite'}),
        throwsA(isA<EconomyOperationException>().having(
          (error) => error.message,
          'message',
          'خدمة تحدي القطع غير متاحة حاليًا. حاول مجددًا لاحقًا.',
        )),
      );
    });
  }

  for (final error in [
    PlatformException(code: 'FAILED_PRECONDITION', message: 'رصيدك لا يكفي'),
    PlatformException(code: 'NOT_FOUND', message: 'الدعوة غير موجودة'),
  ]) {
    test('paid challenge preserves server reason: ${error.code}', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => throw error);

      await expectLater(
        NativeBridgeService().friendStakes({'action': 'invite'}),
        throwsA(isA<EconomyOperationException>().having(
          (error) => error.message,
          'message',
          error.message,
        )),
      );
    });
  }
}
