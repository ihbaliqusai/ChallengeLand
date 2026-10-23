import 'dart:async';
import 'dart:convert';

import 'package:challenge_land/models/room.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/room_service.dart';
import 'package:challenge_land/widgets/online_match_recovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Rooms implements RoomService {
  Room? room;
  bool offline = false;
  int joins = 0;
  @override
  Future<Room?> getRoomForRecovery(String roomId) async {
    if (offline) throw StateError('offline');
    return room;
  }

  @override
  Future<JoinRoomResult> joinRoom(
      {required String roomId, required String userId}) async {
    joins++;
    return const JoinRoomResult(joinedMidGame: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<String, dynamic>> saved;
  late List<MethodCall> calls;
  late _Rooms rooms;
  bool resumeFails = false;
  bool refreshFails = false;
  Completer<String>? pendingRead;

  setUp(() {
    saved = [];
    calls = [];
    rooms = _Rooms();
    resumeFails = false;
    refreshFails = false;
    pendingRead = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getRecoverableOnlineMatches':
          if (refreshFails) throw PlatformException(code: 'offline');
          return pendingRead?.future ??
              Future.value(jsonEncode(
                  saved.map((match) => {'uid': 'alice', ...match}).toList()));
        case 'resumeOnlineMatch':
          if (resumeFails) throw PlatformException(code: 'offline');
          return true;
        case 'dismissOnlineMatchRecovery':
          saved.removeWhere(
              (match) => match['id'] == (call.arguments as Map)['id']);
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> mount(WidgetTester tester, {String uid = 'alice'}) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<NativeBridgeService>(create: (_) => NativeBridgeService()),
        Provider<RoomService>.value(value: rooms),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 380, child: OnlineMatchRecoveryCard(userId: uid)))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapReturn(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('resume-online-match')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('no return button without a saved match', (tester) async {
    await mount(tester);
    expect(find.byKey(const ValueKey('resume-online-match')), findsNothing);
  });

  for (final id in ['bot:saved-board', 'duel:server-session', 'paid:escrow']) {
    testWidgets('reopening the app returns to the retained match $id',
        (tester) async {
      saved = [
        {'id': id, 'roomId': '', 'finished': false}
      ];
      await mount(tester);
      expect(find.text('العودة إلى المباراة'), findsOneWidget);
      await tapReturn(tester);
      final resumes = calls.where((call) => call.method == 'resumeOnlineMatch');
      expect(resumes.single.arguments, {'id': id});
      expect(
          calls.where((call) => call.method == 'launchRandomMatch'), isEmpty);
      expect(calls.where((call) => call.method == 'dismissOnlineMatchRecovery'),
          isEmpty);
    });
  }

  testWidgets('failed connection preserves the match and allows retry',
      (tester) async {
    saved = [
      {'id': 'duel:1', 'finished': false}
    ];
    resumeFails = true;
    await mount(tester);
    await tapReturn(tester);
    expect(find.text('تعذر استعادة المباراة. تحقق من الاتصال ثم حاول مجددًا.'),
        findsOneWidget);
    expect(find.text('العودة إلى المباراة'), findsOneWidget);
    resumeFails = false;
    await tapReturn(tester);
    expect(calls.where((call) => call.method == 'resumeOnlineMatch'),
        hasLength(2));
  });

  testWidgets('background loss stays until the player reads it',
      (tester) async {
    saved = [
      {
        'id': 'duel:lost',
        'finished': true,
        'message': 'خسرت المباراة بسبب مغادرتك'
      }
    ];
    await mount(tester);
    await tapReturn(tester);
    expect(find.text('خسرت المباراة بسبب مغادرتك'), findsOneWidget);
    expect(calls.where((call) => call.method == 'dismissOnlineMatchRecovery'),
        isEmpty);
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();
    expect(
        calls
            .where((call) => call.method == 'dismissOnlineMatchRecovery')
            .single
            .arguments,
        {'id': 'duel:lost'});
    expect(find.byKey(const ValueKey('resume-online-match')), findsNothing);
  });

  testWidgets('foreground resume refreshes without losing the button offline',
      (tester) async {
    await mount(tester);
    saved = [
      {'id': 'bot:1', 'finished': false}
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('العودة إلى المباراة'), findsOneWidget);
    refreshFails = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('العودة إلى المباراة'), findsOneWidget);
  });

  testWidgets(
      'switching account discards an outstanding read from the old account',
      (tester) async {
    final oldRead = Completer<String>();
    pendingRead = oldRead;
    await mount(tester);
    pendingRead = null;
    await mount(tester, uid: 'bob');
    oldRead.complete(jsonEncode([
      {'id': 'duel:alice', 'finished': false}
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-online-match')), findsNothing);
  });

  testWidgets('native account lag cannot expose another account match',
      (tester) async {
    saved = [
      {'id': 'duel:alice', 'finished': false}
    ];
    await mount(tester, uid: 'bob');
    expect(find.byKey(const ValueKey('resume-online-match')), findsNothing);
  });

  testWidgets('finished room reports the actual winner without joining again',
      (tester) async {
    saved = [
      {'id': 'room:1', 'roomId': '1', 'finished': false}
    ];
    rooms.room = const Room(
        id: '1',
        hostId: 'bob',
        maxPlayers: 2,
        started: true,
        phase: Room.phaseFinished,
        winnerId: 'bob',
        players: {
          'alice': RoomPlayer(score: 200, ready: true),
          'bob': RoomPlayer(score: 600, ready: true),
        });
    await mount(tester);
    await tapReturn(tester);
    expect(find.text('خسرت المباراة التي انتهت أثناء غيابك.'), findsOneWidget);
    expect(rooms.joins, 0);
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });

  testWidgets('offline room lookup keeps recovery instead of reporting a loss',
      (tester) async {
    saved = [
      {'id': 'room:1', 'roomId': '1', 'finished': false}
    ];
    rooms.offline = true;
    await mount(tester);
    await tapReturn(tester);
    expect(find.text('العودة إلى المباراة'), findsOneWidget);
    expect(find.text('انتهت المباراة'), findsNothing);
    expect(saved, hasLength(1));
  });
}
