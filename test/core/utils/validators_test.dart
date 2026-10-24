import 'package:challenge_land/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.username', () {
    test('accepts trimmed names from 3 to 20 characters', () {
      expect(Validators.username('  لاعب  '), isNull);
      expect(Validators.username('abcdefghijklmnopqrst'), isNull);
    });

    test('rejects short and overly long names', () {
      expect(Validators.username(null), isNotNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('abcdefghijklmnopqrstu'), isNotNull);
    });
  });

  group('Validators.roomCode', () {
    test(
      'accepts six alphanumeric characters after trimming and uppercasing',
      () {
        expect(Validators.roomCode(' abc234 '), isNull);
        expect(Validators.roomCode('ZXCV98'), isNull);
      },
    );

    test('rejects invalid lengths and non-alphanumeric characters', () {
      expect(Validators.roomCode('ABC23'), isNotNull);
      expect(Validators.roomCode('ABC2345'), isNotNull);
      expect(Validators.roomCode('ABC-34'), isNotNull);
    });
  });
}
