import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/online/achievements_screen.dart';
import 'package:challenge_land/services/achievement_reward_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  String get uid => 'player';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Achievements extends ChangeNotifier implements AppState {
  final data = <String, dynamic>{
    'accountUid': 'player',
    'ACH_FIRST_GAME': true,
    'ACH_FIRST_WIN': true,
    'unclaimedAchievements': 999,
  };
  int calls = 0;
  bool failLoad = false;
  Completer<AchievementPayout?>? response;
  @override
  User get currentUser => _User();
  @override
  String? achievementRewardError = 'تعذّر الاتصال. أعد المحاولة.';
  @override
  Future<Map<String, dynamic>> loadAchievementState() async {
    if (failLoad) throw StateError('Offline');
    return Map.of(data);
  }

  @override
  Future<AchievementPayout?> claimAchievementRewards({String? key}) async {
    calls++;
    final result = await response!.future;
    if (result != null) {
      for (final id in result.claimedIds) {
        data['${id}_CLAIMED'] = true;
      }
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _payout = AchievementPayout(
  claimedIds: {'ACH_FIRST_GAME', 'ACH_FIRST_WIN'},
  unlockedIds: {'ACH_FIRST_GAME', 'ACH_FIRST_WIN'},
  newlyClaimedIds: {'ACH_FIRST_GAME', 'ACH_FIRST_WIN'},
  coins: 130,
  xp: 80,
  balances: {'coins': 630, 'gems': 10},
  stats: {'xp': 180},
);

Widget _app(_Achievements state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: AchievementsScreen()),
    );

void main() {
  testWidgets('claim all locks other actions and stays claimed after reopening',
      (tester) async {
    final state = _Achievements()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    expect(find.text('تحصيل الكل (2)'), findsOneWidget);
    expect(find.text('تحصيل الكل (999)'), findsNothing);
    await tester.tap(find.text('تحصيل الكل (2)'));
    await tester.pump();
    expect(find.text('جاري التحصيل...'), findsOneWidget);
    await tester.tap(find.text('جاري التحصيل...'));
    expect(state.calls, 1);
    state.response!.complete(_payout);
    await tester.pumpAndSettle();
    expect(find.text('تحصيل الكل (2)'), findsNothing);
    expect(find.textContaining('تم تحصيل 2 إنجاز'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    expect(find.text('تحصيل الكل (2)'), findsNothing);
    expect(state.data['ACH_FIRST_GAME_CLAIMED'], isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed claim releases the button and shows a retryable error',
      (tester) async {
    final state = _Achievements()..response = Completer();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحصيل الكل (2)'));
    state.response!.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الاتصال. أعد المحاولة.'), findsOneWidget);
    expect(find.text('تحصيل الكل (2)'), findsOneWidget);
    state.response = Completer();
    await tester.tap(find.text('تحصيل الكل (2)'));
    expect(state.calls, 2);
    state.response!.complete(_payout);
    await tester.pumpAndSettle();
    expect(find.text('تحصيل الكل (2)'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed load requires synchronization before enabling rewards',
      (tester) async {
    final state = _Achievements()..failLoad = true;
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المزامنة'), findsOneWidget);
    expect(find.text('تحصيل الكل (2)'), findsNothing);
    state.failLoad = false;
    await tester.tap(find.text('إعادة المزامنة'));
    await tester.pumpAndSettle();
    expect(find.text('تحصيل الكل (2)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
