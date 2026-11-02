import 'package:challenge_land/models/room.dart';
import 'package:challenge_land/services/room_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seed(FakeFirebaseFirestore db, String id,
      {bool started = false,
      bool? private,
      String phase = Room.phaseLobby,
      Duration createdAge = Duration.zero,
      Duration startedAge = Duration.zero,
      Map<String, RoomPlayer>? players}) async {
    final now = DateTime.now();
    await db.doc('rooms/$id').set({
      'hostId': 'host',
      'maxPlayers': 4,
      'mode': Room.modeBattle,
      'phase': phase,
      'started': started,
      'createdAt': Timestamp.fromDate(now.subtract(createdAge)),
      if (started) 'startedAt': Timestamp.fromDate(now.subtract(startedAge)),
      if (private != null) 'isPrivate': private,
      'players': {
        for (final entry
            in (players ?? {'host': const RoomPlayer(score: 0, ready: true)})
                .entries)
          entry.key: entry.value.toMap(),
      },
    });
  }

  test('bounded feed keeps legacy public lobbies and recently started rooms',
      () async {
    final db = FakeFirebaseFirestore();
    final service = RoomService(firestore: db);
    await seed(db, 'legacy_public');
    await db.doc('rooms/legacy_no_metadata').set({
      'hostId': 'host',
      'maxPlayers': 4,
      'players': {'host': const RoomPlayer(score: 0, ready: true).toMap()},
    });
    await seed(db, 'private', private: true);
    await seed(db, 'playing',
        started: true,
        phase: Room.phasePlaying,
        createdAge: const Duration(hours: 1),
        startedAge: const Duration(minutes: 1));
    await seed(db, 'old_playing',
        started: true,
        phase: Room.phasePlaying,
        startedAge: const Duration(minutes: 11));
    await seed(db, 'expired_lobby', createdAge: const Duration(minutes: 21));
    await seed(db, 'finished', started: true, phase: Room.phaseFinished);
    await seed(db, 'bots', players: {
      'bot_room_bots_1': const RoomPlayer(score: 0, ready: true),
    });
    final feed = await service.watchOpenRooms().first;
    expect(feed.map((r) => r.id),
        unorderedEquals(['legacy_public', 'legacy_no_metadata', 'playing']));
  });

  test('lobby feed returns the newest bounded window', () async {
    final db = FakeFirebaseFirestore();
    final service = RoomService(firestore: db);
    for (var i = 0; i < RoomService.roomFeedLimit + 15; i++) {
      await seed(db, 'room_$i', createdAge: Duration(seconds: i));
    }
    final feed = await service.watchOpenRooms().first;
    expect(feed, hasLength(RoomService.roomFeedLimit));
    expect(feed.first.id, 'room_0');
    expect(feed.any((r) => r.id == 'room_74'), isFalse);
  });

  test('feed visibility limits never prevent a member reconnecting by room id',
      () async {
    final db = FakeFirebaseFirestore();
    final service = RoomService(firestore: db);
    await seed(db, 'saved',
        started: true,
        phase: Room.phasePlaying,
        startedAge: const Duration(minutes: 15),
        players: {
          'host': const RoomPlayer(score: 0, ready: true),
          'alice': const RoomPlayer(score: 10, ready: true, disconnected: true),
        });
    expect(await service.watchOpenRooms(userId: 'alice').first, isEmpty);
    await service.joinRoom(roomId: 'saved', userId: 'alice');
    final room = Room.fromSnapshot(await db.doc('rooms/saved').get());
    expect(room.players['alice']!.disconnected, isFalse);
    expect(room.players['alice']!.score, 10);
  });

  test('newer private rooms cannot crowd an explicit public room out',
      () async {
    final db = FakeFirebaseFirestore();
    final service = RoomService(firestore: db);
    await seed(db, 'public_room',
        private: false, createdAge: const Duration(minutes: 3));
    for (var i = 0; i < RoomService.roomFeedLimit + 15; i++) {
      await seed(db, 'private_$i',
          private: true, createdAge: Duration(seconds: i));
    }
    final feed = await service.watchOpenRooms().first;
    expect(feed.map((room) => room.id), ['public_room']);
  });
}
