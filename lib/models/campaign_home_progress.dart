/// The furthest reached stage and the size of the player's current campaign.
class CampaignHomeProgress {
  const CampaignHomeProgress({
    required this.reachedStage,
    required this.totalStages,
  });

  final int reachedStage;
  final int totalStages;

  String get label => '$reachedStage/$totalStages';
}
