import 'package:challenge_land/models/app_update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> policy(
          {Object? enabled = true,
          Object? minimum = 50,
          Object? installed = 49,
          bool remote = true}) =>
      {
        'enabled': enabled,
        'minimumBuild': minimum,
        'installedBuild': installed,
        'remotePolicy': remote,
      };

  test('only verified enabled policies block builds below the minimum', () {
    expect(AppUpdatePolicy.fromMap(policy()).requiresUpdate, isTrue);
    expect(
        AppUpdatePolicy.fromMap(policy(installed: 50)).requiresUpdate, isFalse);
    expect(
        AppUpdatePolicy.fromMap(policy(installed: 51)).requiresUpdate, isFalse);
    expect(AppUpdatePolicy.fromMap(policy(enabled: false)).requiresUpdate,
        isFalse);
    expect(
        AppUpdatePolicy.fromMap(policy(remote: false)).requiresUpdate, isFalse);
  });

  test('missing, malformed and out-of-range values cannot block players', () {
    expect(AppUpdatePolicy.fromMap({}).requiresUpdate, isFalse);
    for (final minimum in [-1, 0, 50.5, '50', 2147483648, null]) {
      expect(AppUpdatePolicy.fromMap(policy(minimum: minimum)).requiresUpdate,
          isFalse);
    }
    for (final installed in [-1, 0, '49', null]) {
      expect(
          AppUpdatePolicy.fromMap(policy(installed: installed)).requiresUpdate,
          isFalse);
    }
    expect(AppUpdatePolicy.fromMap(policy(enabled: 'true')).requiresUpdate,
        isFalse);
  });

  test('Arabic messages have a safe default and a bounded display length', () {
    expect(AppUpdatePolicy.fromMap({'message': '  '}).message,
        AppUpdatePolicy.defaultMessage);
    expect(
        AppUpdatePolicy.fromMap({'message': List.filled(400, 'أ').join()})
            .message
            .length,
        300);
  });
}
