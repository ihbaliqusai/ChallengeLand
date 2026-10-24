import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/campaign_daily_progress.dart';
import '../models/campaign_stage.dart';
import '../models/stage_attempt.dart';
import '../models/stage_progress.dart';

/// Personal goals only: no currency claims, stage unlocks or cloud writes.
class CampaignEngagementService {
  CampaignEngagementService({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  static Future<void> _pending = Future<void>.value();

  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String _key(String playerId, String campaignId) =>
      'campaign_journey_v1:${Uri.encodeComponent(playerId)}:${Uri.encodeComponent(campaignId)}';

  CampaignDailyProgress _read(SharedPreferences preferences, String key) {
    final today = dayKey(_now());
    try {
      final raw = preferences.getString(key);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CampaignDailyProgress.fromMap(decoded, today: today);
      }
    } catch (_) {
      // An interrupted or obsolete local record must not block the campaign.
    }
    return CampaignDailyProgress(dayKey: today);
  }

  Future<CampaignDailyProgress> load({
    required String playerId,
    required String campaignId,
  }) =>
      _serialize(() async {
        final preferences = await SharedPreferences.getInstance();
        return _read(preferences, _key(playerId, campaignId));
      });

  Future<CampaignDailyProgress> recordAttempt({
    required String playerId,
    required String campaignId,
    required StageAttempt attempt,
  }) =>
      _serialize(() async {
        final preferences = await SharedPreferences.getInstance();
        final key = _key(playerId, campaignId);
        final previous = _read(preferences, key);
        if (attempt.attemptId.isEmpty ||
            previous.recentAttemptIds.contains(attempt.attemptId)) {
          return previous;
        }
        final playedAt = attempt.createdAt ?? _now();
        final playedDay = dayKey(playedAt.toLocal());
        // A delayed result belongs to its original day, never today's goals.
        final today = playedDay == previous.dayKey;
        final activity = {...previous.activityDays, playedDay}.toList()..sort();
        final ids = [...previous.recentAttemptIds, attempt.attemptId];
        final updated = CampaignDailyProgress(
          dayKey: previous.dayKey,
          attempts: previous.attempts + (today ? 1 : 0),
          wins: previous.wins + (today && attempt.completed ? 1 : 0),
          stars: previous.stars +
              (today && attempt.completed ? attempt.stars.clamp(0, 3) : 0),
          activityDays: activity.length > 60
              ? activity.sublist(activity.length - 60)
              : activity,
          recentAttemptIds:
              ids.length > 256 ? ids.sublist(ids.length - 256) : ids,
        );
        final saved =
            await preferences.setString(key, jsonEncode(updated.toMap()));
        if (!saved) throw StateError('Could not save campaign daily progress');
        return updated;
      });

  /// The daily rotation is deterministic, independent of list ordering.
  CampaignStage? recommendedStage({
    required List<CampaignStage> stages,
    required List<StageProgress> progress,
  }) {
    final byId = {for (final item in progress) item.stageId: item};
    final playable = stages.where((stage) {
      final saved = byId[stage.id];
      return saved != null && saved.status != StageProgressStatus.locked;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (playable.isEmpty) return null;
    final completed = playable
        .where(
            (stage) => byId[stage.id]!.status == StageProgressStatus.completed)
        .toList();
    final improving =
        completed.where((stage) => byId[stage.id]!.stars < 3).toList();
    final candidates = improving.isNotEmpty
        ? improving
        : completed.isNotEmpty
            ? completed
            : playable;
    final date = _now();
    final day =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    return candidates[day % candidates.length];
  }
}
