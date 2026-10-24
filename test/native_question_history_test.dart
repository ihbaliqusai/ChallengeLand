import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('round modes use the reserved sequence returned by native history',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'reserveRoomQuestions');
      expect(call.arguments,
          {'roomId': 'room', 'matchMode': 'survival', 'roundNumber': 1});
      return [104, 18, 603];
    });
    expect(
        await NativeBridgeService().reserveRoomQuestionIds(
            roomId: 'room', matchMode: 'survival', roundNumber: 1),
        [104, 18, 603]);
  });

  test('exhaustion never falls back to the first eighty bank indices',
      () async {
    messenger.setMockMethodCallHandler(channel, (_) async => <int>[]);
    await expectLater(
      NativeBridgeService().reserveRoomQuestionIds(
          roomId: 'room', matchMode: 'elimination', roundNumber: 1),
      throwsA(isA<EconomyOperationException>()),
    );
  });

  test(
      'history failures stop room allocation instead of generating replacement indices',
      () async {
    messenger.setMockMethodCallHandler(channel,
        (_) async => throw PlatformException(code: 'QUESTION_HISTORY_FAILED'));
    await expectLater(
      NativeBridgeService().reserveRoomQuestionIds(
          roomId: 'room', matchMode: 'elimination', roundNumber: 1),
      throwsA(isA<EconomyOperationException>()),
    );
  });
}
