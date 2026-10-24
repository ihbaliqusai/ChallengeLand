import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/auth_provider.dart';
import 'state/friends_provider.dart';
import 'state/game_provider.dart';
import 'state/home_provider.dart';
import 'state/leaderboard_provider.dart';
import 'state/matchmaking_provider.dart';
import 'state/profile_provider.dart';
import 'state/room_provider.dart';
import 'state/settings_provider.dart';

class ChallengeLandApp extends StatelessWidget {
  const ChallengeLandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => MatchmakingProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.appNameEn,
        theme: AppTheme.darkArabicTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        initialRoute: AppRouter.initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
