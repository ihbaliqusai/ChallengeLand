import 'package:challenge_land/core/trophy_league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrophyProgression Competitive Formula Tests', () {
    test('returns 0 trophies if no games played or 0 wins', () {
      expect(TrophyProgression.computeTrophies({}), 0);
      expect(TrophyProgression.computeTrophies({'gamesPlayed': 0, 'wins': 0}), 0);
      expect(
          TrophyProgression.computeTrophies({'gamesPlayed': 20, 'wins': 0, 'losses': 20}),
          0);
    });

    test('loss penalties prevent negative win rate players from climbing', () {
      // 100 games played, but only 30 wins and 70 losses
      final trophies = TrophyProgression.computeTrophies({
        'gamesPlayed': 100,
        'wins': 30,
        'losses': 70,
        'correctAnswers': 150,
        'wrongAnswers': 150,
      });
      // 30 * 22 = 660, 70 * 18 = 1260 -> net < 0 -> 0
      expect(trophies, 0);
    });

    test('beginner player with positive wins advances into Bronze', () {
      // 20 games, 14 wins, 6 losses (70% win rate), 3 win streak
      final trophies = TrophyProgression.computeTrophies({
        'gamesPlayed': 20,
        'wins': 14,
        'losses': 6,
        'bestWinStreak': 4,
        'correctAnswers': 60,
        'wrongAnswers': 15,
      });
      // 14 * 22 - 6 * 18 = 308 - 108 = 200 net
      // + streak bonus + win rate bonus
      expect(trophies, greaterThanOrEqualTo(200));
      expect(trophies, lessThan(600));
      final league = TrophyProgression.leagueFor(trophies);
      expect(league.name, isIn(['Bronze', 'Silver']));
    });

    test('skilled player with strong online performance reaches Gold', () {
      // 80 games, 55 wins, 25 losses, 25 online wins, 80% accuracy
      final trophies = TrophyProgression.computeTrophies({
        'gamesPlayed': 80,
        'wins': 55,
        'losses': 25,
        'onlineWins': 25,
        'bestWinStreak': 7,
        'correctAnswers': 240,
        'wrongAnswers': 60,
      });
      expect(trophies, greaterThanOrEqualTo(1000));
      final league = TrophyProgression.leagueFor(trophies);
      expect(league.name, isIn(['Gold', 'Diamond']));
    });

    test('elite champion player reaches Master or Legend only with massive skill', () {
      // 300 games, 230 wins (76% win rate), 70 losses, 100 online wins, high accuracy
      final trophies = TrophyProgression.computeTrophies({
        'gamesPlayed': 300,
        'wins': 230,
        'losses': 70,
        'onlineWins': 100,
        'bestWinStreak': 15,
        'correctAnswers': 1200,
        'wrongAnswers': 150,
      });
      expect(trophies, greaterThanOrEqualTo(3000));
      final league = TrophyProgression.leagueFor(trophies);
      expect(league.name, isIn(['Master', 'Legend']));
    });

    test('rules list contains professional competitive descriptions', () {
      const rules = TrophyProgression.rules;
      expect(rules.any((r) => r.label.contains('فوز في مباراة')), isTrue);
      expect(rules.any((r) => r.label.contains('فوز أونلاين')), isTrue);
      expect(rules.any((r) => r.label.contains('الخسارة')), isTrue);
      expect(rules.any((r) => r.value.contains('+22')), isTrue);
      expect(rules.any((r) => r.value.contains('-18')), isTrue);
    });
  });
}
