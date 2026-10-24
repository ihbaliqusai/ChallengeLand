class CampaignDailyProgress {
  const CampaignDailyProgress({
    required this.dayKey,
    this.attempts = 0,
    this.wins = 0,
    this.stars = 0,
    this.activityDays = const [],
    this.recentAttemptIds = const [],
  });

  final String dayKey;
  final int attempts;
  final int wins;
  final int stars;
  final List<String> activityDays;
  final List<String> recentAttemptIds;

  int get goalsCompleted =>
      (attempts >= 2 ? 1 : 0) + (wins >= 1 ? 1 : 0) + (stars >= 3 ? 1 : 0);

  bool get allGoalsCompleted => goalsCompleted == 3;

  Map<String, dynamic> toMap() => {
        'dayKey': dayKey,
        'attempts': attempts,
        'wins': wins,
        'stars': stars,
        'activityDays': activityDays,
        'recentAttemptIds': recentAttemptIds,
      };

  factory CampaignDailyProgress.fromMap(
    Map<String, dynamic> map, {
    required String today,
  }) {
    final sameDay = map['dayKey'] == today;
    int count(String key) {
      final value = map[key];
      return value is num ? value.toInt().clamp(0, 100000) : 0;
    }

    List<String> strings(String key) =>
        map[key] is List ? (map[key] as List).whereType<String>().toList() : [];

    return CampaignDailyProgress(
      dayKey: today,
      attempts: sameDay ? count('attempts') : 0,
      wins: sameDay ? count('wins') : 0,
      stars: sameDay ? count('stars') : 0,
      activityDays: strings('activityDays'),
      recentAttemptIds: strings('recentAttemptIds'),
    );
  }
}
