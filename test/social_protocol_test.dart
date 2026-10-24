import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/services/social_service.dart';

void main() {
  test('friendship identity is symmetric and rejects invalid or self peers',
      () {
    expect(SocialService.pairId('alice', 'bob'),
        SocialService.pairId('bob', 'alice'));
    expect(() => SocialService.pairId('alice', 'alice'),
        throwsA(isA<SocialException>()));
    expect(() => SocialService.pairId('alice', 'bad:uid'),
        throwsA(isA<SocialException>()));
    expect(() => SocialService.pairId('alice', 'bad/uid'),
        throwsA(isA<SocialException>()));
  });
  test('presence expires at its lease boundary and away is immediately offline',
      () {
    final now = DateTime.utc(2026, 10, 10);
    Map<String, dynamic> presence(int seconds, String state) => {
          'heartbeatAt':
              Timestamp.fromDate(now.subtract(Duration(seconds: seconds))),
          'state': state,
        };
    expect(SocialService.fresh(presence(74, 'available'), now), isTrue);
    expect(SocialService.fresh(presence(75, 'available'), now), isFalse);
    expect(SocialService.fresh(presence(0, 'away'), now), isFalse);
    expect(SocialService.fresh(presence(20, 'in_match'), now), isTrue);
    expect(SocialService.fresh(presence(-11, 'available'), now), isFalse);
    expect(SocialService.fresh(null, now), isFalse);
  });
  test('an invitation cannot reappear after its expiry or acceptance', () {
    final now = DateTime.utc(2026, 10, 10);
    final invitation = {
      'status': 'pending',
      'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30)))
    };
    expect(SocialService.pending(invitation, now), isTrue);
    expect(
        SocialService.pending(invitation, now.add(const Duration(seconds: 30))),
        isFalse);
    expect(SocialService.pending({...invitation, 'status': 'accepted'}, now),
        isFalse);
  });
}
