import 'dart:math';

class RoomCodeGenerator {
  RoomCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Random _random;

  String generate({int length = 6}) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}
