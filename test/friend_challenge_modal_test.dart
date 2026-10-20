import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/player_profile.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/services/invite_service.dart';
import 'package:challenge_land/widgets/friend_challenge_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _App extends ChangeNotifier implements AppState {
  int balance = 1000;
  int? launchedStake;
  @override
  User? get user => null;
  @override
  String get friendCode => 'MYCODE1234';
  @override
  int get level => 7;
  @override
  GameCharacter get selectedCharacter => CharacterCatalog.byIndex(1);
  @override
  int get coins => balance;
  @override
  bool get isOnline => true;
  @override
  Future<void> openRandomMatch({int? stakeCoins}) async {
    launchedStake = stakeCoins;
    throw StateError('Network unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Invites implements InviteService {
  @override
  Future<List<PlayerProfile>> getRecentOpponents() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> mount(WidgetTester tester, _App app) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          Provider<InviteService>.value(value: _Invites()),
        ],
        child: const MaterialApp(
            home: Scaffold(body: FriendChallengeModal(initialStake: 500)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ابدأ البحث عن منافس الآن ⚡'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'alternate random entry retains the selected stake and launch errors',
      (tester) async {
    final app = _App();
    await mount(tester, app);
    await tester.tap(find.text('ابدأ البحث عن منافس الآن ⚡'));
    await tester.pumpAndSettle();
    expect(app.launchedStake, 500);
    expect(find.byType(FriendChallengeModal), findsOneWidget);
    expect(find.textContaining('تعذر بدء البحث'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('alternate random entry rejects an unaffordable stake',
      (tester) async {
    final app = _App()..balance = 100;
    await mount(tester, app);
    await tester.tap(find.text('ابدأ البحث عن منافس الآن ⚡'));
    await tester.pumpAndSettle();
    expect(app.launchedStake, isNull);
    expect(find.textContaining('رصيدك لا يكفي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
