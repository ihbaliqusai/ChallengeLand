import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/economy_wallet.dart';
import 'package:challenge_land/models/player_profile.dart';
import 'package:challenge_land/models/legacy_room.dart';
import 'package:challenge_land/screens/home/resource_shop_screen.dart';
import 'package:challenge_land/screens/online/room_lobby_screen.dart';
import 'package:challenge_land/services/in_app_purchase_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/profile_service.dart';
import 'package:challenge_land/services/legacy_room_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  String get uid => 'host';
  @override
  String get displayName => 'Host';
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallet extends ChangeNotifier implements AppState {
  @override
  User get user => _User();
  @override
  bool isOnline = true;
  @override
  bool economyLoaded = true;
  @override
  String? economyError;
  @override
  EconomyWallet economyWallet = const EconomyWallet(dailyKeys: 1);
  int loads = 0;
  Future<void>? pendingLoad;
  @override
  int get coins => 0;
  @override
  int get gems => 0;
  @override
  Future<void> loadCurrency() async {}
  @override
  Future<void> loadEconomy() async {
    loads++;
    await pendingLoad;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rooms implements RoomService {
  final controller = StreamController<Room?>.broadcast(sync: true);
  late final rooms = controller.stream;
  final ready = <bool>[];
  int starts = 0;
  int leaves = 0;
  @override
  Stream<Room?> watchRoom(String roomId) => rooms;
  @override
  Future<void> setPlayerReady(
      {required String roomId,
      required String userId,
      required bool ready}) async {
    this.ready.add(ready);
  }

  @override
  Future<void> startRoom(
      {required String roomId,
      required String userId,
      List<int>? eliminationQuestionIds}) async {
    starts++;
  }

  @override
  Future<void> leaveRoom(
      {required String roomId, required String userId}) async {
    leaves++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileService {
  final values = {
    for (final uid in ['host', 'other'])
      uid: PlayerProfile.fromMap({'uid': uid, 'username': uid}),
  };
  late final profiles = Stream.value(values);
  @override
  Stream<Map<String, PlayerProfile>> watchProfiles(Iterable<String> uids) =>
      profiles;
  @override
  Future<PlayerProfile?> fetchProfile(String uid) async => values[uid];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Billing extends InAppPurchaseService {
  _Billing() : super(nativeBridge: NativeBridgeService());
  @override
  Future<void> loadProducts() async {}
}

Room _room(
        {bool started = false, int round = 1, String mode = Room.modeBattle}) =>
    Room(
        id: 'room',
        hostId: 'host',
        maxPlayers: 2,
        started: started,
        phase: started
            ? (mode == Room.modeSeries
                ? Room.phasePlayingRound
                : Room.phasePlaying)
            : Room.phaseLobby,
        startedAt: started ? DateTime.utc(2026, 10, 19, 0, round) : null,
        economyMatchId: 'room_match',
        roundNumber: round,
        mode: mode,
        players: const {
          'host': RoomPlayer(score: 0, ready: false),
          'other': RoomPlayer(score: 0, ready: false),
        });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Wallet wallet;
  late _Rooms rooms;
  late _Billing billing;
  final calls = <MethodCall>[];
  const channel = MethodChannel('millionaire/native');

  setUp(() {
    wallet = _Wallet();
    rooms = _Rooms();
    billing = _Billing();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await rooms.controller.close();
    wallet.dispose();
    billing.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(WidgetTester tester, Room room,
      {bool reconnect = false}) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: wallet),
          Provider<RoomService>.value(value: rooms),
          Provider<ProfileService>.value(value: _Profiles()),
          Provider<NativeBridgeService>.value(value: NativeBridgeService()),
          ChangeNotifierProvider<InAppPurchaseService>.value(value: billing),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => RoomLobbyScreen(
                                    roomId: room.id,
                                    isJoiningMidGame: reconnect))),
                        child: const Text('Lobby')))))));
    await tester.tap(find.text('Lobby'));
    await settle(tester);
    rooms.controller.add(room);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    expect(calls.where((c) => c.method == 'gameEconomy'), isEmpty,
        reason: 'Flutter preflight must never reserve or spend a resource.');
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  testWidgets('zero keys block readiness and room start without leaving',
      (tester) async {
    wallet.economyWallet = const EconomyWallet();
    await mount(tester, _room());
    await tester.tap(find.text('غير جاهز'));
    await settle(tester);
    expect(find.text('تحتاج إلى مفتاح'), findsOneWidget);
    expect(rooms.ready, isEmpty);
    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    final start = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('ابدأ '));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await settle(tester);
    expect(find.text('تحتاج إلى مفتاح'), findsOneWidget);
    expect(rooms.starts, 0);
    expect(rooms.leaves, 0);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), isEmpty);
    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('readiness checks a key without spending it', (tester) async {
    await mount(tester, _room());
    await tester.tap(find.text('غير جاهز'));
    await settle(tester);
    expect(rooms.ready, [true]);
    expect(wallet.economyWallet.totalKeys, 1);
    expect(wallet.loads, 1);
    await unmount(tester);
  });

  testWidgets('a room starting during the ready check still launches once',
      (tester) async {
    await mount(tester, _room());
    final pending = Completer<void>();
    wallet.pendingLoad = pending.future;
    await tester.tap(find.text('غير جاهز'));
    await tester.pump(const Duration(milliseconds: 100));
    rooms.controller.add(_room(started: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls.where((c) => c.method == 'launchRoomMatch'), isEmpty);
    pending.complete();
    await settle(tester);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(1));
    expect(rooms.leaves, 0);
    await unmount(tester);
  });

  testWidgets('unavailable balance keeps a started room and offers a retry',
      (tester) async {
    wallet.economyLoaded = false;
    wallet.economyError = 'Connection failed';
    await mount(tester, _room(started: true));
    expect(
        find.text('تعذر التحقق من المفاتيح. تحقق من الاتصال ثم أعد المحاولة.'),
        findsOneWidget);
    expect(rooms.leaves, 0);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), isEmpty);
    wallet.economyLoaded = true;
    wallet.economyError = null;
    await tester.tap(find.text('إعادة المحاولة'));
    await settle(tester);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(1));
    expect(rooms.leaves, 0);
    await unmount(tester);
  });

  testWidgets('started room is left only after choosing to leave for the shop',
      (tester) async {
    wallet.economyWallet = const EconomyWallet();
    await mount(tester, _room(started: true));
    expect(rooms.leaves, 0);
    await tester.tap(find.text('البقاء في الغرفة'));
    await settle(tester);
    expect(rooms.leaves, 0);
    await tester.tap(find.text('إعادة المحاولة'));
    await settle(tester);
    await tester.tap(find.text('مغادرة وفتح الأرصدة'));
    await settle(tester);
    expect(rooms.leaves, 1);
    expect(find.byType(ResourceShopScreen), findsOneWidget);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), isEmpty);
    await unmount(tester);
  });

  testWidgets('offline cached zero balance never becomes a forced forfeit',
      (tester) async {
    wallet.isOnline = false;
    wallet.economyWallet = const EconomyWallet();
    await mount(tester, _room(started: true));
    expect(
        find.text('تعذر التحقق من المفاتيح. تحقق من الاتصال ثم أعد المحاولة.'),
        findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(wallet.loads, 0);
    expect(rooms.leaves, 0);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), isEmpty);
    await unmount(tester);
  });

  testWidgets('later rounds continue after the last key was used',
      (tester) async {
    await mount(tester, _room(started: true, mode: Room.modeSeries));
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(1));
    wallet.economyWallet = const EconomyWallet();
    rooms.controller.add(_room(started: true, mode: Room.modeSeries, round: 2));
    await settle(tester);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(2));
    expect(wallet.loads, 1);
    expect(rooms.leaves, 0);
    await unmount(tester);
  });

  testWidgets('reconnecting a paid match delegates admission to Native at zero',
      (tester) async {
    wallet.economyWallet = const EconomyWallet();
    await mount(tester, _room(started: true), reconnect: true);
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(1));
    expect(wallet.loads, 0);
    expect(rooms.leaves, 0);
    await unmount(tester);
  });

  testWidgets('restoring a later series round does not require a second key',
      (tester) async {
    wallet.economyWallet = const EconomyWallet();
    await mount(tester, _room(started: true, mode: Room.modeSeries, round: 2));
    expect(calls.where((c) => c.method == 'launchRoomMatch'), hasLength(1));
    expect(wallet.loads, 0);
    expect(rooms.leaves, 0);
    await unmount(tester);
  });
}
