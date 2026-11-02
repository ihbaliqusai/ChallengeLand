/// Campaign trophies belong to a stage's first clear, not to each play attempt.
abstract final class CampaignTrophyRules {
  static const firstClearTrophies = 22;
  // Old claims accompanied native per-attempt trophies. Version this phase so
  // recovering an old XP receipt cannot award first-clear trophies again.
  static const firstClearPhase = 'first_completion_v3';

  static String firstClearClaimId(String campaignId, String stageId) =>
      '${_segment(campaignId)}_${_segment(canonicalStageId(stageId))}_$firstClearPhase';

  static String canonicalStageId(String stageId) {
    final id = stageId.trim();
    final match = RegExp(r'^stage_(\d{1,6})$').firstMatch(id);
    final order = match == null ? null : int.tryParse(match.group(1)!);
    return order != null && order >= 1 && order <= 100
        ? 'stage_${order.toString().padLeft(3, '0')}'
        : id;
  }

  static bool isFirstClearClaim(String? claimId) =>
      claimId?.endsWith('_$firstClearPhase') == true;

  static int rewardForClaim({
    required String claimId,
    required String campaignId,
    required String stageId,
    required dynamic previousStars,
    required dynamic newStars,
  }) {
    if (campaignId.trim().isEmpty ||
        stageId.trim().isEmpty ||
        previousStars is! int ||
        previousStars != 0 ||
        newStars is! int ||
        newStars < 1 ||
        newStars > 3 ||
        claimId != firstClearClaimId(campaignId, stageId)) {
      return 0;
    }
    return firstClearTrophies;
  }

  static String _segment(String value) =>
      value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
