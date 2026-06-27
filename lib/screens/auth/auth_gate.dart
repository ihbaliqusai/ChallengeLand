import 'package:flutter/material.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../character/character_select_screen.dart';
import 'login_screen.dart';
import 'offline_welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.user == null) {
          return appState.isOnline
              ? const LoginScreen()
              : const OfflineWelcomeScreen();
        }
        // Wait for the native character state before deciding, so the forced
        // picker never flashes for a player who already chose a character.
        if (!appState.characterStateLoaded) {
          return const _CharacterLoadingScreen();
        }
        if (!appState.hasChosenCharacter) {
          return const CharacterSelectScreen(forced: true);
        }
        return const HomeScreen();
      },
    );
  }
}

class _CharacterLoadingScreen extends StatelessWidget {
  const _CharacterLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF071126),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFFACC15)),
      ),
    );
  }
}
