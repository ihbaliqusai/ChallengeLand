import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player_profile.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('public_profiles');

  Future<PlayerProfile?> fetchProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    if (!doc.exists) return null;
    return _profileFromDocument(doc);
  }

  Stream<PlayerProfile> watchProfile(String uid) {
    return _profiles.doc(uid).snapshots().map(
          (doc) =>
              doc.exists ? _profileFromDocument(doc) : PlayerProfile.empty(),
        );
  }

  Stream<Map<String, PlayerProfile>> watchProfiles(Iterable<String> uids) {
    final uniqueIds = uids
        .where((uid) => uid.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueIds.isEmpty) {
      return Stream.value(const <String, PlayerProfile>{});
    }

    late final StreamController<Map<String, PlayerProfile>> controller;
    final profiles = <String, PlayerProfile>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    var cancelled = false;

    void emit() {
      if (!cancelled && !controller.isClosed) {
        controller.add(Map<String, PlayerProfile>.unmodifiable(profiles));
      }
    }

    controller = StreamController<Map<String, PlayerProfile>>(
      onListen: () {
        // Firestore supports up to 30 document IDs in one whereIn query.
        // A room list now needs a few listeners rather than one per host.
        for (var start = 0; start < uniqueIds.length; start += 30) {
          final end = (start + 30).clamp(0, uniqueIds.length).toInt();
          final batch = uniqueIds.sublist(start, end);
          final subscription = _profiles
              .where(FieldPath.documentId, whereIn: batch)
              .snapshots()
              .listen((snapshot) {
            for (final uid in batch) {
              profiles.remove(uid);
            }
            for (final doc in snapshot.docs) {
              profiles[doc.id] = _profileFromDocument(doc);
            }
            emit();
          }, onError: controller.addError);
          subscriptions.add(subscription);
        }
        emit();
      },
      onCancel: () async {
        cancelled = true;
        await Future.wait(subscriptions.map((s) => s.cancel()));
      },
    );

    return controller.stream;
  }

  PlayerProfile _profileFromDocument(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PlayerProfile.fromMap(<String, dynamic>{
        ...?doc.data(),
        'uid': doc.id,
      });
}
