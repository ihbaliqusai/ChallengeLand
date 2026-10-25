import 'package:challenge_land/services/referral_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const code = 'CL-ABCDEF012345';
  late List<MethodCall> calls;
  var fail = false;
  var canAccept = true;
  var pendingCode = code;
  const service = ReferralService();

  setUp(() {
    calls = [];
    fail = false;
    canAccept = true;
    pendingCode = code;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getReferralInstallId') {
        return 'install_0123456789abcdef';
      }
      if (call.method == 'getPendingReferral') return {'code': pendingCode};
      if (call.method == 'clearPendingReferral') return true;
      if (call.method == 'referrals') {
        if (fail) {
          throw PlatformException(code: 'UNAVAILABLE', message: 'حاول مجددًا');
        }
        return {
          'state': {'code': code, 'canAccept': canAccept},
          'currency': {'coins': 1000, 'gems': 15}
        };
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
      'share link retains encoded attribution and supports manual/deep link input',
      () {
    final link = ReferralService.inviteLink(code);
    expect(link.queryParameters['id'], 'com.qi7bali.landchallengeonline');
    expect(
        Uri.splitQueryString(link.queryParameters['referrer']!)['cl_referral'],
        code);
    expect(ReferralService.extractCode(link.toString()), code);
    expect(
        ReferralService.extractCode('challengeland://invite?code=$code'), code);
    expect(ReferralService.extractCode(' cl-abcdef012345 '), code);
    expect(ReferralService.extractCode('CL-OLD123'), '');
    expect(ReferralService.shareMessage(code), contains(link.toString()));
  });

  test(
      'accept sends account-bound installation attribution then clears matching pending code',
      () async {
    await service.accept('alice', ReferralService.inviteLink(code).toString());
    expect(calls.map((call) => call.method), [
      'getReferralInstallId',
      'referrals',
      'getPendingReferral',
      'clearPendingReferral'
    ]);
    expect(calls[1].arguments, {
      'action': 'accept',
      'expectedUid': 'alice',
      'code': code,
      'installationId': 'install_0123456789abcdef'
    });
    expect(calls.last.arguments, {'code': code, 'expectedUid': 'alice'});
  });

  test(
      'ineligible accounts clear unusable attribution to avoid reopening each launch',
      () async {
    canAccept = false;
    await service.load('alice');
    expect(calls.last.method, 'clearPendingReferral');
    expect(calls.last.arguments, {'code': code, 'expectedUid': 'alice'});
  });

  test('accepting a manual code clears a different pending invite too',
      () async {
    pendingCode = 'CL-000000000001';
    await service.accept('alice', code);
    expect(calls.last.arguments, {'code': pendingCode, 'expectedUid': 'alice'});
  });

  test('failed acceptance leaves pending attribution for retry', () async {
    fail = true;
    await expectLater(service.accept('alice', code), throwsStateError);
    expect(calls.any((call) => call.method == 'clearPendingReferral'), false);
  });

  test('invalid code does not contact native or server', () async {
    await expectLater(
        service.accept('alice', 'invalid'), throwsFormatException);
    expect(calls, isEmpty);
  });

  for (final status in ['NOT_FOUND', 'UNIMPLEMENTED']) {
    test('missing callable $status becomes a readable Arabic error', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: status, message: status);
      });
      await expectLater(
          service.load('alice'),
          throwsA(isA<StateError>().having((error) => error.message, 'message',
              'خدمة دعوة الأصدقاء غير متاحة حاليًا. أعد المحاولة بعد قليل.')));
    });
  }

  test('unknown invitation keeps the specific server message', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getReferralInstallId') {
        return 'install_0123456789abcdef';
      }
      throw PlatformException(
          code: 'NOT_FOUND',
          message: 'كود الدعوة غير موجود. تأكد من الكود مع صديقك.');
    });
    await expectLater(
        service.accept('alice', code),
        throwsA(isA<StateError>().having((error) => error.message, 'message',
            'كود الدعوة غير موجود. تأكد من الكود مع صديقك.')));
  });
}
