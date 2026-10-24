import 'package:flutter/material.dart';

class TrophyLeague {
  const TrophyLeague({
    required this.name,
    required this.nameAr,
    required this.color,
    required this.icon,
    required this.min,
    required this.max,
  });

  final String name;
  final String nameAr;
  final Color color;
  final IconData icon;
  final int min;
  final int? max;

  bool contains(int trophies) =>
      trophies >= min && (max == null || trophies <= max!);

  double progress(int trophies) {
    if (max == null) return 1.0;
    return ((trophies - min) / (max! - min + 1)).clamp(0.0, 1.0);
  }

  int trophiesLeft(int trophies) {
    if (max == null) return 0;
    return (max! + 1 - trophies).clamp(0, max! + 1);
  }

  String rangeLabel() => max == null ? '$min+' : '$min-${max!}';
}

class TrophyRule {
  const TrophyRule({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class TrophyProgression {
  static const List<TrophyLeague> leagues = [
    TrophyLeague(
      name: 'Rookie',
      nameAr: 'مبتدئ',
      color: Color(0xFF94A3B8),
      icon: Icons.star_outline_rounded,
      min: 0,
      max: 199,
    ),
    TrophyLeague(
      name: 'Bronze',
      nameAr: 'برونزي',
      color: Color(0xFFCD7F32),
      icon: Icons.shield_rounded,
      min: 200,
      max: 499,
    ),
    TrophyLeague(
      name: 'Silver',
      nameAr: 'فضي',
      color: Color(0xFFCBD5E1),
      icon: Icons.shield_moon_rounded,
      min: 500,
      max: 999,
    ),
    TrophyLeague(
      name: 'Gold',
      nameAr: 'ذهبي',
      color: Color(0xFFFACC15),
      icon: Icons.military_tech_rounded,
      min: 1000,
      max: 1799,
    ),
    TrophyLeague(
      name: 'Diamond',
      nameAr: 'ماسي',
      color: Color(0xFF38BDF8),
      icon: Icons.diamond_rounded,
      min: 1800,
      max: 2999,
    ),
    TrophyLeague(
      name: 'Master',
      nameAr: 'خبير',
      color: Color(0xFF8B5CF6),
      icon: Icons.workspace_premium_rounded,
      min: 3000,
      max: 4999,
    ),
    TrophyLeague(
      name: 'Legend',
      nameAr: 'أسطورة',
      color: Color(0xFFEF4444),
      icon: Icons.local_fire_department_rounded,
      min: 5000,
      max: null,
    ),
  ];

  static const List<TrophyRule> rules = [
    TrophyRule(
      label: 'فوز في مباراة',
      value: '+22',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFACC15),
    ),
    TrophyRule(
      label: 'فوز أونلاين ضد لاعب حقيقي',
      value: '+8 إضافي',
      icon: Icons.public_rounded,
      color: Color(0xFF22D3EE),
    ),
    TrophyRule(
      label: 'الخسارة في مباراة',
      value: '-18',
      icon: Icons.flag_rounded,
      color: Color(0xFFFB7185),
    ),
    TrophyRule(
      label: 'سلسلة انتصارات (3+ فوز)',
      value: '+2 إلى +10 لكل فوز',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFFB020),
    ),
    TrophyRule(
      label: 'التعادل',
      value: '0 • تبقى كؤوسك',
      icon: Icons.balance_rounded,
      color: Color(0xFF34D399),
    ),
    TrophyRule(
      label: 'إتمام جلسة الفرق المحلية المشتركة',
      value: '+6 • بعد إجابة محتسبة',
      icon: Icons.groups_rounded,
      color: Color(0xFF2DD4BF),
    ),
    TrophyRule(
      label: 'دقة الفوز بعد 5 إجابات على الأقل',
      value: '75%: +3 • 90%: +5',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF38BDF8),
    ),
    TrophyRule(
      label: 'حماية أول 8 مباريات',
      value: 'الخسارة -10 • الحد الأدنى 0',
      icon: Icons.shield_outlined,
      color: Color(0xFFA78BFA),
    ),
  ];

  static TrophyLeague leagueFor(int trophies) =>
      leagues.lastWhere((league) => league.contains(trophies),
          orElse: () => leagues.first);

  static TrophyLeague? nextLeagueFor(int trophies) {
    final index = leagues.indexOf(leagueFor(trophies));
    return index + 1 < leagues.length ? leagues[index + 1] : null;
  }

  /// Three visible milestones within each finite league, from III up to I.
  static String divisionLabelFor(int trophies) {
    final league = leagueFor(trophies);
    if (league.max == null) return league.nameAr;
    final division = (league.progress(trophies) * 3).floor().clamp(0, 2);
    return '${league.nameAr} ${const ['III', 'II', 'I'][division]}';
  }

  /// Delta for one settled match, mirrored by native ProgressionRules.
  /// This is independent of lifetime accuracy/rate: crossing a statistics
  /// threshold can never retroactively alter trophies from previous matches.
  static int trophyDelta({
    required bool won,
    bool draw = false,
    bool online = false,
    bool sharedLocalCompletion = false,
    required int gamesBefore,
    int winStreak = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) {
    if (sharedLocalCompletion) return 6;
    if (draw) return 0;
    if (!won) return gamesBefore < 8 ? -10 : -18;
    final streak = ((winStreak - 2) * 2).clamp(0, 10);
    final correct = correctAnswers.clamp(0, 2147483647);
    final wrong = wrongAnswers.clamp(0, 2147483647);
    final answered = correct + wrong;
    var accuracy = 0;
    if (answered >= 5) {
      if (correct * 100 >= answered * 90) {
        accuracy = 5;
      } else if (correct * 100 >= answered * 75) {
        accuracy = 3;
      }
    }
    return 22 + (online ? 8 : 0) + streak + accuracy;
  }

  /// Legacy migration estimate only. New matches persist per-result deltas;
  /// callers must never replace an existing trophy balance with this estimate.
  static int computeTrophies(Map<String, int> stats) {
    final gamesPlayed = stats['gamesPlayed'] ?? 0;
    final wins = stats['wins'] ?? 0;
    final losses = stats['losses'] ?? 0;
    final onlineWins = stats['onlineWins'] ?? 0;
    final correctAnswers = stats['correctAnswers'] ?? 0;
    final wrongAnswers = stats['wrongAnswers'] ?? 0;
    final bestWinStreak = stats['bestWinStreak'] ?? 0;
    final totalAnswered = correctAnswers + wrongAnswers;

    // Zero wins or zero games = 0 trophies. Trophies must be earned through actual victory.
    if (wins == 0 || gamesPlayed == 0) return 0;

    // 1. Net Wins Differential (Zero-sum Ladder with Beginner Protection)
    // For beginners (under 8 wins), losses are cushioned (-10). Higher up, losses hurt (-18).
    final lossPenaltyPerGame = (wins < 8) ? 10 : 18;
    final winScore = wins * 22;
    final lossPenalty = losses * lossPenaltyPerGame;
    final netScore = winScore - lossPenalty;

    // A negative or zero net score cannot climb the competitive ladder
    if (netScore <= 0) return 0;

    // 2. High-Stakes Online Wins (Playing against live human opponents)
    final onlineBonus = onlineWins * 8;

    // 3. Win Streak Skill Bonus (capped to prevent runaway numbers)
    final streakBonus =
        (bestWinStreak >= 3) ? ((bestWinStreak - 2) * 5).clamp(0, 80) : 0;

    // 4. Competitive Win Rate Evaluation (requires at least 10 matches)
    final winRateBonus = _computeWinRateBonus(gamesPlayed, wins);

    // 5. Accuracy & Knowledge Skill Bonus (requires at least 25 answered questions)
    final accuracyBonus = _computeAccuracyBonus(totalAnswered, correctAnswers);

    // 6. Aggregate Net Trophies
    final rawTrophies =
        netScore + onlineBonus + streakBonus + winRateBonus + accuracyBonus;

    return rawTrophies.clamp(0, 99999);
  }

  static int _computeWinRateBonus(int gamesPlayed, int wins) {
    if (gamesPlayed < 10) return 0;
    final rate = wins / gamesPlayed;
    if (rate >= 0.75) return 150;
    if (rate >= 0.65) return 90;
    if (rate >= 0.55) return 40;
    if (rate < 0.40) return -40;
    return 0;
  }

  static int _computeAccuracyBonus(int totalAnswered, int correctAnswers) {
    if (totalAnswered < 25) return 0;
    final accuracy = correctAnswers / totalAnswered;
    if (accuracy >= 0.88) return 60;
    if (accuracy >= 0.75) return 30;
    if (accuracy < 0.50) return -30;
    return 0;
  }

  static const String trophyBasisLabelAr =
      'كؤوس لكل نتيجة في جميع الأطوار، مع مكافآت الفوز والدقة والسلسلة. '
      'رتبة الخبرة ترتفع بالمستوى، والدوري يتحدد بالكؤوس.';
}
