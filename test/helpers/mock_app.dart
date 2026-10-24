import 'package:challenge_land/core/routing/app_router.dart';
import 'package:challenge_land/core/theme/app_theme.dart';
import 'package:challenge_land/state/auth_provider.dart';
import 'package:challenge_land/state/friends_provider.dart';
import 'package:challenge_land/state/game_provider.dart';
import 'package:challenge_land/state/home_provider.dart';
import 'package:challenge_land/state/leaderboard_provider.dart';
import 'package:challenge_land/state/matchmaking_provider.dart';
import 'package:challenge_land/state/profile_provider.dart';
import 'package:challenge_land/state/room_provider.dart';
import 'package:challenge_land/state/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

class TestApp extends StatelessWidget {
  const TestApp({
    super.key,
    required this.child,
    this.authProvider,
    this.gameProvider,
    this.homeProvider,
  });

  final Widget child;
  final AuthProvider? authProvider;
  final GameProvider? gameProvider;
  final HomeProvider? homeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        authProvider == null
            ? ChangeNotifierProvider(create: (_) => AuthProvider())
            : ChangeNotifierProvider.value(value: authProvider!),
        homeProvider == null
            ? ChangeNotifierProvider(create: (_) => HomeProvider())
            : ChangeNotifierProvider.value(value: homeProvider!),
        ChangeNotifierProvider(create: (_) => MatchmakingProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        gameProvider == null
            ? ChangeNotifierProvider(create: (_) => GameProvider())
            : ChangeNotifierProvider.value(value: gameProvider!),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: child,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}

Future<AuthProvider> signedInAuthProvider() async {
  final auth = AuthProvider();
  await auth.signInAsGuest();
  return auth;
}
