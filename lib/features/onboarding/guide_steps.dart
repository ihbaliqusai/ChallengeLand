import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';

class GuideStep {
  const GuideStep(
    this.target,
    this.title,
    this.message, {
    this.route = AppRoutes.home,
  });
  final String target, title, message, route;
}

abstract final class GuideTargets {
  static const welcome = 'welcome';
  static const menu = 'menu';
  static const profile = 'profile';
  static const leaderboard = 'leaderboard';
  static const rewards = 'rewards';
  static const stats = 'stats';
  static const achievements = 'achievements';
  static const settings = 'settings';
  static const coins = 'coins';
  static const gems = 'gems';
  static const keys = 'keys';
  static const tickets = 'tickets';
  static const level = 'level';
  static const character = 'character';
  static const friends = 'friends';
  static const store = 'store';
  static const help = 'help';
  static const club = 'club';
  static const play = 'play';
  static const campaign = 'campaign';
  static const modes = 'modes';
  static const main = 'main';
  static const group = 'group';
  static const friendMode = 'friendMode';
  static const offline = 'offline';
  static const ready = 'ready';
}

const guestGuideSteps = [
  GuideStep(
    GuideTargets.welcome,
    AppStrings.guideWelcomeTitle,
    AppStrings.guideWelcomeBody,
  ),
  GuideStep(
    GuideTargets.menu,
    AppStrings.guideMenuTitle,
    AppStrings.guideMenuBody,
  ),
  GuideStep(
    GuideTargets.profile,
    AppStrings.guideProfileTitle,
    AppStrings.guideProfileBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.leaderboard,
    AppStrings.guideLeaderboardTitle,
    AppStrings.guideLeaderboardBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.rewards,
    AppStrings.guideRewardsTitle,
    AppStrings.guideRewardsBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.stats,
    AppStrings.guideStatsTitle,
    AppStrings.guideStatsBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.achievements,
    AppStrings.guideAchievementsTitle,
    AppStrings.guideAchievementsBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.settings,
    AppStrings.guideSettingsTitle,
    AppStrings.guideSettingsBody,
    route: AppRoutes.guideMenu,
  ),
  GuideStep(
    GuideTargets.coins,
    AppStrings.guideCoinsTitle,
    AppStrings.guideCoinsBody,
  ),
  GuideStep(
    GuideTargets.gems,
    AppStrings.guideGemsTitle,
    AppStrings.guideGemsBody,
  ),
  GuideStep(
    GuideTargets.keys,
    AppStrings.guideKeysTitle,
    AppStrings.guideKeysBody,
  ),
  GuideStep(
    GuideTargets.tickets,
    AppStrings.guideTicketsTitle,
    AppStrings.guideTicketsBody,
  ),
  GuideStep(
    GuideTargets.level,
    AppStrings.guideLevelTitle,
    AppStrings.guideLevelBody,
  ),
  GuideStep(
    GuideTargets.character,
    AppStrings.guideCharacterTitle,
    AppStrings.guideCharacterBody,
  ),
  GuideStep(
    GuideTargets.friends,
    AppStrings.guideFriendsTitle,
    AppStrings.guideFriendsBody,
  ),
  GuideStep(
    GuideTargets.store,
    AppStrings.guideStoreTitle,
    AppStrings.guideStoreBody,
  ),
  GuideStep(
    GuideTargets.help,
    AppStrings.guideHelpTitle,
    AppStrings.guideHelpBody,
  ),
  GuideStep(
    GuideTargets.club,
    AppStrings.guideClubTitle,
    AppStrings.guideClubBody,
  ),
  GuideStep(
    GuideTargets.play,
    AppStrings.guidePlayTitle,
    AppStrings.guidePlayBody,
  ),
  GuideStep(
    GuideTargets.campaign,
    AppStrings.guideCampaignTitle,
    AppStrings.guideCampaignBody,
  ),
  GuideStep(
    GuideTargets.modes,
    AppStrings.guideModesTitle,
    AppStrings.guideModesBody,
  ),
  GuideStep(
    GuideTargets.main,
    AppStrings.guideMainTitle,
    AppStrings.guideMainBody,
    route: AppRoutes.gameModes,
  ),
  GuideStep(
    GuideTargets.group,
    AppStrings.guideGroupTitle,
    AppStrings.guideGroupBody,
    route: AppRoutes.gameModes,
  ),
  GuideStep(
    GuideTargets.friendMode,
    AppStrings.guideFriendModeTitle,
    AppStrings.guideFriendModeBody,
    route: AppRoutes.gameModes,
  ),
  GuideStep(
    GuideTargets.offline,
    AppStrings.guideOfflineTitle,
    AppStrings.guideOfflineBody,
    route: AppRoutes.gameModes,
  ),
  GuideStep(
    GuideTargets.ready,
    AppStrings.guideReadyTitle,
    AppStrings.guideReadyBody,
  ),
];
