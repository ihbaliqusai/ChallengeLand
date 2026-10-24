import '../../models/game_session.dart';
import '../../models/team.dart';

class ScoreUtils {
  const ScoreUtils._();

  static int calculateSpeedBonus({
    required int remainingTime,
    required int totalTime,
  }) {
    if (remainingTime <= 0 || totalTime <= 0) return 0;
    return ((remainingTime / totalTime) * 50).round().clamp(0, 50);
  }

  static int calculateQuestionScore({
    required bool isCorrect,
    required int remainingTime,
    required int totalTime,
    int basePoints = 100,
  }) {
    if (!isCorrect) return 0;
    return basePoints +
        calculateSpeedBonus(remainingTime: remainingTime, totalTime: totalTime);
  }

  static String? calculateWinner(GameSession session) {
    if (session.playerScores.isEmpty) return null;
    final entries = session.playerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.length > 1 && entries[0].value == entries[1].value) {
      return null;
    }
    return entries.first.key;
  }

  static String? calculateTeamWinner(List<Team> teams) {
    if (teams.isEmpty) return null;
    final sorted = [...teams]..sort((a, b) => b.score.compareTo(a.score));
    if (sorted.length > 1 && sorted[0].score == sorted[1].score) return null;
    return sorted.first.id;
  }

  static int calculateXpEarned({
    required int score,
    required int correctAnswers,
    required bool won,
  }) {
    return (score ~/ 12) + (correctAnswers * 6) + (won ? 35 : 15);
  }

  static double calculateLevelProgress({required int xp, required int level}) {
    final requiredXp = (level.clamp(1, 999) * 250);
    return (xp / requiredXp).clamp(0, 1);
  }

  static double percentage(int part, int total) {
    if (total <= 0) return 0;
    return (part / total).clamp(0, 1);
  }
}
