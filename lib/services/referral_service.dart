import 'package:flutter/services.dart';

/// Referral attribution and rewards are checked and committed by the server.
class ReferralService {
  const ReferralService(
      {MethodChannel channel = const MethodChannel('millionaire/native')})
      : _channel = channel;

  final MethodChannel _channel;
  static final _codePattern = RegExp(r'^CL-[A-F0-9]{12}$');

  static String extractCode(String input) {
    final text = input.trim();
    final direct = text.toUpperCase();
    if (_codePattern.hasMatch(direct)) return direct;
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final code =
          uri.queryParameters['code'] ?? uri.queryParameters['cl_referral'];
      if (code != null && _codePattern.hasMatch(code.toUpperCase())) {
        return code.toUpperCase();
      }
      final referrer = uri.queryParameters['referrer'];
      if (referrer != null) {
        final code = Uri.splitQueryString(referrer)['cl_referral'];
        if (code != null && _codePattern.hasMatch(code.toUpperCase())) {
          return code.toUpperCase();
        }
      }
    }
    return '';
  }

  static Uri inviteLink(String code) {
    if (!_codePattern.hasMatch(code)) throw ArgumentError.value(code, 'code');
    return Uri.https('play.google.com', '/store/apps/details', {
      'id': 'com.qi7bali.landchallengeonline',
      'referrer': Uri(queryParameters: {'cl_referral': code}).query,
    });
  }

  static String shareMessage(String code) => 'تعال نلعب أرض التحدي معًا! 🎮\n'
      'حمّل اللعبة وسجّل الدخول واقبل كود دعوتي لتحصل على '
      '500 عملة و5 جواهر، وأحصل أنا على مكافأة أيضًا 🎁\n\n'
      'كود الدعوة: $code\n${inviteLink(code)}\n\n'
      'إذا كانت اللعبة لديك: challengeland://invite?code=$code\n'
      'الهدية للحسابات الجديدة خلال أول 7 أيام، مرة واحدة لكل حساب وجهاز.';

  Future<Map<String, dynamic>> load(String uid) async {
    final result = await _execute({'action': 'state', 'expectedUid': uid});
    final state = result['state'] as Map;
    if (state['canAccept'] == false || state['acceptedCode'] != null) {
      await _clearPending(uid);
    }
    return result;
  }

  Future<Map<String, dynamic>> accept(String uid, String input) async {
    final code = extractCode(input);
    if (code.isEmpty) {
      throw const FormatException('أدخل كود دعوة صحيحًا أو رابط الدعوة.');
    }
    final installId =
        await _channel.invokeMethod<String>('getReferralInstallId');
    if (installId == null || installId.isEmpty) {
      throw StateError('تعذر التحقق من تثبيت اللعبة. أعد المحاولة.');
    }
    final result = await _execute({
      'action': 'accept',
      'expectedUid': uid,
      'code': code,
      'installationId': installId,
    });
    // A failed network request keeps attribution available for retry. Once this
    // account has accepted, any other pending code is no longer usable either.
    await _clearPending(uid);
    return result;
  }

  Future<void> _clearPending(String uid) async {
    try {
      final stored = await pending();
      final code = extractCode(stored['code'] as String? ?? '');
      if (code.isNotEmpty) {
        await _channel.invokeMethod<bool>('clearPendingReferral', {
          'code': code,
          'expectedUid': uid,
        });
      }
    } catch (_) {
      // Clearing is best effort; it must never hide a committed server reward.
    }
  }

  Future<Map<String, dynamic>> pending() async =>
      await _channel.invokeMapMethod<String, dynamic>('getPendingReferral') ??
      {};

  Future<Map<String, dynamic>> _execute(Map<String, dynamic> input) async {
    final uid = input['expectedUid'];
    if (uid is! String || uid.isEmpty || uid.contains('/')) {
      throw StateError('سجّل الدخول للمشاركة في مكافآت الأصدقاء.');
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('referrals', input);
      if (result == null || result['state'] is! Map) {
        throw const FormatException('تعذر تحميل بيانات الدعوات. حاول مجددًا.');
      }
      return result;
    } on PlatformException catch (error) {
      throw StateError(_platformMessage(error));
    } on MissingPluginException {
      throw StateError('حدّث اللعبة لاستخدام مكافآت دعوة الأصدقاء.');
    }
  }

  static String _platformMessage(PlatformException error) {
    String status(String value) =>
        value.trim().toUpperCase().replaceAll('-', '_');
    final code = status(error.code);
    final message = error.message?.trim() ?? '';
    final rawMessage = status(message);
    const rawStatuses = {
      'NOT_FOUND',
      'UNIMPLEMENTED',
      'UNAVAILABLE',
      'DEADLINE_EXCEEDED',
      'UNAUTHENTICATED',
      'PERMISSION_DENIED',
      'INTERNAL',
      'UNKNOWN',
    };
    final hasDescription =
        message.isNotEmpty && !rawStatuses.contains(rawMessage);
    if (code == 'UNAVAILABLE' || code == 'DEADLINE_EXCEEDED') {
      return 'تعذّر الاتصال بخدمة الدعوات. تحقق من الإنترنت ثم أعد المحاولة.';
    }
    // A missing callable reports only NOT_FOUND. An unknown invitation code
    // returns a specific server description that must remain visible.
    if (!hasDescription &&
        ({'NOT_FOUND', 'UNIMPLEMENTED'}.contains(code) ||
            {'NOT_FOUND', 'UNIMPLEMENTED'}.contains(rawMessage))) {
      return 'خدمة دعوة الأصدقاء غير متاحة حاليًا. أعد المحاولة بعد قليل.';
    }
    if (!hasDescription &&
        {'UNAUTHENTICATED', 'PERMISSION_DENIED'}.contains(code)) {
      return 'سجّل الدخول إلى حسابك ثم أعد فتح شاشة دعوة الأصدقاء.';
    }
    return hasDescription
        ? message
        : 'تعذّر تحميل بيانات الدعوات. أعد المحاولة بعد قليل.';
  }
}
