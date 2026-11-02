import 'package:challenge_land/models/player_profile.dart';
import 'package:challenge_land/services/profile_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile batches preserve updates, missing users and deletions',
      () async {
    final db = FakeFirebaseFirestore();
    final service = ProfileService(firestore: db);
    final ids = [for (var i = 0; i < 35; i++) 'host_$i'];
    for (final id in ids) {
      await db.doc('public_profiles/$id').set({'username': id});
    }
    Map<String, PlayerProfile> profiles = {};
    final subscription = service.watchProfiles(
        [...ids, ids.first, 'missing']).listen((value) => profiles = value);
    try {
      await _until(() => profiles.length == 35);
      expect(profiles.containsKey('missing'), isFalse);
      await db.doc('public_profiles/host_34').update({'username': 'updated'});
      await _until(() => profiles['host_34']?.username == 'updated');
      expect(profiles['host_0']!.username, 'host_0');
      await db.doc('public_profiles/host_0').delete();
      await _until(() => profiles.length == 34);
      expect(profiles.containsKey('host_0'), isFalse);
      expect(profiles['host_34']!.username, 'updated');
    } finally {
      await subscription.cancel();
    }
  });
}
