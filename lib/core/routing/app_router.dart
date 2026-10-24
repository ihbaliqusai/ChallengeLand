import 'package:flutter/material.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/username_screen.dart';
import '../../features/daily_challenge/daily_challenge_screen.dart';
import '../../features/daily_challenge/daily_result_screen.dart';
import '../../features/friends/friend_requests_screen.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/friends/user_search_screen.dart';
import '../../features/game/answer_reveal_screen.dart';
import '../../features/game/category_selection_screen.dart';
import '../../features/game/game_board_screen.dart';
import '../../features/game/game_mode_selection_screen.dart';
import '../../features/game/game_result_screen.dart';
import '../../features/game/game_over_screen.dart';
import '../../features/game/live_game_screen.dart';
import '../../features/game/question_screen.dart';
import '../../features/game/round_result_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/matchmaking/quick_match_screen.dart';
import '../../features/matchmaking/searching_match_screen.dart';
import '../../features/profile/match_history_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/rooms/create_room_screen.dart';
import '../../features/rooms/join_room_screen.dart';
import '../../features/rooms/room_lobby_screen.dart';
import '../../features/rooms/team_setup_screen.dart';
import '../../features/shop/albums_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../constants/app_routes.dart';

class AppRouter {
  const AppRouter._();

  static const initialRoute = AppRoutes.splash;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget screen = switch (settings.name) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.login => const LoginScreen(),
      AppRoutes.username => const UsernameScreen(),
      AppRoutes.home => const HomeScreen(),
      AppRoutes.gameModes => const GameModeSelectionScreen(),
      AppRoutes.quickMatch => const QuickMatchScreen(),
      AppRoutes.searchingMatch => const SearchingMatchScreen(),
      AppRoutes.createRoom => const CreateRoomScreen(),
      AppRoutes.joinRoom => const JoinRoomScreen(),
      AppRoutes.roomLobby => const RoomLobbyScreen(),
      AppRoutes.teamSetup => const TeamSetupScreen(),
      AppRoutes.categorySelection => const CategorySelectionScreen(),
      AppRoutes.gameBoard => const GameBoardScreen(),
      AppRoutes.liveGame => const LiveGameScreen(),
      AppRoutes.roundResult => const RoundResultScreen(),
      AppRoutes.gameOver => const GameOverScreen(),
      AppRoutes.question => const QuestionScreen(),
      AppRoutes.gameResult => const GameResultScreen(),
      AppRoutes.dailyChallenge => const DailyChallengeScreen(),
      AppRoutes.dailyResult => const DailyResultScreen(),
      AppRoutes.shop => const ShopScreen(),
      AppRoutes.albums => const AlbumsScreen(),
      AppRoutes.leaderboard => const LeaderboardScreen(),
      AppRoutes.profile => const ProfileScreen(),
      AppRoutes.matchHistory => const MatchHistoryScreen(),
      AppRoutes.friends => const FriendsScreen(),
      AppRoutes.userSearch => const UserSearchScreen(),
      AppRoutes.friendRequests => const FriendRequestsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.answerReveal => const AnswerRevealScreen(),
      _ => const SplashScreen(),
    };
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
