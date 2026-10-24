import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/core/trophy_league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XP and experience ranks', () {
    test('all level boundaries retain the existing cumulative curve', () {
      var cumulative = 0;
      for (var level = 1; level <= 500; level++) {
        expect(PlayerRank.xpForLevel(level), cumulative);
        expect(PlayerRank.levelForXp(cumulative), level);
        expect(PlayerRank.xpIntoLevel(cumulative), 0);
        expect(PlayerRank.progressForXp(cumulative), 0);
        if (level > 1) {
          expect(PlayerRank.levelForXp(cumulative - 1), level - 1);
          expect(PlayerRank.xpRemaining(cumulative - 1), 1);
        }
        final required = PlayerRank.xpNeededForLevel(level);
        expect(PlayerRank.xpRemaining(cumulative), required);
        expect(PlayerRank.xpIntoLevel(cumulative + required - 1), required - 1);
        cumulative += required;
      }
    });

    test('handles empty, negative and largest persisted XP safely', () {
      expect(PlayerRank.levelForXp(-100), 1);
      expect(PlayerRank.xpIntoLevel(-100), 0);
      final level = PlayerRank.levelForXp(PlayerRank.maxXp);
      expect(PlayerRank.xpForLevel(level), lessThanOrEqualTo(PlayerRank.maxXp));
      expect(PlayerRank.xpForLevel(level + 1), greaterThan(PlayerRank.maxXp));
      expect(PlayerRank.levelForXp(PlayerRank.maxXp + 500), level);
      expect(
          PlayerRank.progressForXp(PlayerRank.maxXp), inInclusiveRange(0, 1));
    });

    test('experience ranks have independent names and contiguous thresholds',
        () {
      for (var i = 0; i < PlayerRank.tiers.length; i++) {
        final rank = PlayerRank.tiers[i];
        expect(PlayerRank.tierForLevel(rank.minLevel), same(rank));
        expect(TrophyProgression.leagues.map((l) => l.nameAr),
            isNot(contains(rank.nameAr)));
        if (rank.maxLevel != null) {
          expect(rank.progress(rank.minLevel), 0);
          expect(PlayerRank.tiers[i + 1].minLevel, rank.maxLevel! + 1);
          expect(PlayerRank.nextTierForLevel(rank.minLevel),
              same(PlayerRank.tiers[i + 1]));
        }
      }
      expect(PlayerRank.nextTierForLevel(60), isNull);
    });
  });

  group('per-match trophy rewards', () {
    test('wins, human online bonus, losses and draws are distinct', () {
      expect(TrophyProgression.trophyDelta(won: true, gamesBefore: 0), 22);
      expect(
          TrophyProgression.trophyDelta(
              won: true, online: true, gamesBefore: 0),
          30);
      expect(TrophyProgression.trophyDelta(won: false, gamesBefore: 7), -10);
      expect(TrophyProgression.trophyDelta(won: false, gamesBefore: 8), -18);
      expect(
          TrophyProgression.trophyDelta(
              won: false, draw: true, gamesBefore: 20),
          0);
      expect(
          TrophyProgression.trophyDelta(
              won: false,
              draw: true,
              gamesBefore: 20,
              sharedLocalCompletion: true),
          6);
    });

    test('accuracy rewards require a completed meaningful sample and a win',
        () {
      int reward(int correct, int wrong, {bool won = true}) =>
          TrophyProgression.trophyDelta(
            won: won,
            gamesBefore: 10,
            correctAnswers: correct,
            wrongAnswers: wrong,
          );
      expect(reward(4, 0), 22);
      expect(reward(5, 0), 27);
      expect(reward(6, 2), 25);
      expect(reward(7, 3), 22);
      expect(reward(9, 1), 27);
      expect(reward(9, 1, won: false), -18);
      expect(reward(-10, -10), 22);
    });

    test('streak rewards begin at third win and remain bounded', () {
      int reward(int streak) => TrophyProgression.trophyDelta(
          won: true, gamesBefore: 10, winStreak: streak);
      expect(reward(1), 22);
      expect(reward(2), 22);
      expect(reward(3), 24);
      expect(reward(7), 32);
      expect(reward(1000), 32);
      expect(reward(-10), 22);
    });

    test('league boundaries are gap-free and support balances above 99999', () {
      for (var i = 0; i < TrophyProgression.leagues.length; i++) {
        final league = TrophyProgression.leagues[i];
        expect(TrophyProgression.leagueFor(league.min), same(league));
        if (league.max != null) {
          expect(TrophyProgression.leagueFor(league.max!), same(league));
          final next = TrophyProgression.leagues[i + 1];
          expect(next.min, league.max! + 1);
          expect(league.progress(league.min), 0);
          expect(league.trophiesLeft(league.max!), 1);
          expect(TrophyProgression.nextLeagueFor(league.min), same(next));
          expect(TrophyProgression.divisionLabelFor(league.min),
              '${league.nameAr} III');
          expect(TrophyProgression.divisionLabelFor(league.max!),
              '${league.nameAr} I');
        }
      }
      expect(TrophyProgression.leagueFor(-10), TrophyProgression.leagues.first);
      expect(
          TrophyProgression.leagueFor(1000000), TrophyProgression.leagues.last);
      expect(TrophyProgression.nextLeagueFor(1000000), isNull);
    });
  });
}
