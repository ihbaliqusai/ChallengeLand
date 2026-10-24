import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/core/trophy_league.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/home/profile_screen.dart';
import 'package:challenge_land/screens/online/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _ProgressionState extends ChangeNotifier implements AppState {
  int totalXp = 2000;
  int trophyBalance = 1234;
  int trophyPeak = 1450;
  Map<String, int> stats = {
    'gamesPlayed': 5,
    'wins': 1,
    'losses': 0,
    'draws': 4,
    'correctAnswers': 10,
    'wrongAnswers': 5,
    'mode_campaign_games': 3,
    'mode_campaign_wins': 1,
    'mode_campaign_draws': 2,
    'mode_local_teams_games': 2,
    'mode_local_teams_draws': 2,
  };

  @override
  Map<String, int> get playerStats => stats;
  @override
  int get trophies => trophyBalance;
  @override
  int get bestTrophies => trophyPeak;
  @override
  int get xp => totalXp;
  @override
  int get level => PlayerRank.levelForXp(xp);
  @override
  int get xpInCurrentLevel => PlayerRank.xpIntoLevel(xp);
  @override
  int get xpNeededForLevel => PlayerRank.xpNeededForLevel(level);
  @override
  GameCharacter get selectedCharacter => CharacterCatalog.all.first;
  @override
  String get friendCode => 'TESTCODE99';
  @override
  get user => null;
  @override
  get currentUser => null;
  @override
  Future<void> checkAndAwardXpForGames() async {}

  void updateStats(Map<String, int> next) {
    stats = {...stats, ...next};
    notifyListeners();
  }

  void updateProgression({required int xp, required int trophies}) {
    totalXp = xp;
    trophyBalance = trophies;
    if (trophies > trophyPeak) trophyPeak = trophies;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [const Size(400, 900), const Size(1000, 500)]) {
    for (final screen in [const ProfileScreen(), const StatsScreen()]) {
      testWidgets('${screen.runtimeType} uses shared progression at $size',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final state = _ProgressionState();
        await tester.pumpWidget(MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: state,
            child: screen,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('رتبة الخبرة:'), findsOneWidget);
        expect(find.text(TrophyProgression.divisionLabelFor(state.trophies)),
            findsWidgets);

        // The page remains mounted while the shared snapshot is updated.
        state.updateStats({'gamesPlayed': 9, 'wins': 5, 'draws': 4});
        await tester.pumpAndSettle();
        expect(find.text('9'), findsOneWidget);
        expect(tester.takeException(), isNull);

        state.updateProgression(xp: 20000, trophies: 3020);
        await tester.pumpAndSettle();
        expect(
            find.textContaining(
                'رتبة الخبرة: ${PlayerRank.titleForLevel(state.level)}'),
            findsOneWidget);
        expect(find.text(TrophyProgression.divisionLabelFor(state.trophies)),
            findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('دليل التقدم والمكافآت'));
        await tester.pumpAndSettle();
        expect(find.text('دليل التقدم والمكافآت'), findsOneWidget);
        expect(find.text('المستوى ورتبة الخبرة'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('مكافأة الفرق المحلية'), 180,
            scrollable: find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable)));
        expect(find.textContaining('+6 كؤوس'), findsOneWidget);
        expect(find.textContaining('التعادل في بقية الأطوار يمنح 0 كؤوس'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mode breakdown keeps draws separate from losses',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<AppState>.value(
        value: _ProgressionState(),
        child: const StatsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إحصاءات أطوار اللعب'));
    await tester.pumpAndSettle();
    expect(find.text('الحملة • 3 مباراة'), findsOneWidget);
    expect(find.text('فوز 1 • خسارة 0 • تعادل 2 • انسحاب 0'), findsOneWidget);
    expect(find.text('الفرق المحلية • 2 مباراة'), findsOneWidget);
    expect(find.text('فوز 0 • خسارة 0 • تعادل 2 • انسحاب 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
