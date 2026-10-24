import 'dart:math';

import 'package:challenge_land/core/utils/room_code_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoomCodeGenerator', () {
    test('generates a six-character code by default', () {
      final code = RoomCodeGenerator(random: Random(1)).generate();

      expect(code, hasLength(6));
      expect(code, matches(RegExp(r'^[A-Z2-9]{6}$')));
      expect(code.contains('I'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('1'), isFalse);
    });

    test('respects custom lengths', () {
      final generator = RoomCodeGenerator(random: Random(2));

      expect(generator.generate(length: 4), hasLength(4));
      expect(generator.generate(length: 8), hasLength(8));
      expect(generator.generate(length: 0), isEmpty);
    });
  });
}
