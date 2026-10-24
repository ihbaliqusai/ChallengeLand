import 'package:challenge_land/models/achievement_rewards.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/daily_reward_service.dart';
import 'package:challenge_land/services/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full campaign has a bounded currency budget including every ad double',
      () {
    final stages = CampaignDefaults.stages();
    final coins = stages.fold(0, (sum, stage) => sum + stage.rewardCoins);
    final gems = stages.fold(0, (sum, stage) => sum + stage.rewardGems);
    expect(coins, 13050);
    expect(gems, 20);
    expect(coins * 2, lessThan(30000));
    expect(gems * 2, lessThan(80)); // The smallest store gem pack.
    for (final stage in stages) {
      if (!stage.isBossStage) {
        expect(stage.rewardGems, 0, reason: stage.id);
        expect(stage.rewardCoins * 2, lessThan(500), reason: stage.id);
      } else {
        expect(stage.rewardCoins * 2, lessThan(800), reason: stage.id);
      }
    }
  });

  test('saving for resource packs requires multiple stage completions', () {
    final stages = CampaignDefaults.stages();
    for (var world = 0; world < 10; world++) {
      final ordinary = stages.skip(world * 10).take(9).toList();
      final maximum = ordinary.last.rewardCoins;
      // At least three ordinary three-star rewards for one heart (500 in a
      // triple pack), and five for a ticket (800), even in the last world.
      expect((500 / maximum).ceil(), greaterThanOrEqualTo(3));
      expect((800 / maximum).ceil(), greaterThanOrEqualTo(5));
      if (world > 0) {
        expect(ordinary.first.rewardCoins,
            greaterThan(stages[(world - 1) * 10].rewardCoins));
      }
    }
  });

  test('passive monthly rewards cannot replace active progression or ownership',
      () {
    const rewards = DailyRewardService.rewards;
    expect(rewards.fold(0, (sum, day) => sum + day['coins']!), 2730);
    expect(rewards.fold(0, (sum, day) => sum + day['gems']!), 8);
    expect(rewards.every((day) => day['coins']! < 500), isTrue);
    final campaignAchievements = AchievementRewards.catalog.entries
        .where((entry) => entry.key.startsWith('ACH_CAMPAIGN_'))
        .fold(0, (sum, entry) => sum + entry.value.coins);
    expect(campaignAchievements, 1860);
    expect(AdService.rewardGems, 0);
    expect(AdService.rewardCoins * AdService.maxDailyWatches, lessThan(500));
  });
}
