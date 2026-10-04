import 'dart:async';

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

class _CharacterLoadingScreen extends StatefulWidget {
  const _CharacterLoadingScreen();

  @override
  State<_CharacterLoadingScreen> createState() =>
      _CharacterLoadingScreenState();
}

class _CharacterLoadingScreenState extends State<_CharacterLoadingScreen> {
  Timer? _safetyTimer;
  Timer? _actionTimer;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    // After 2.5s, offer manual continue / retry action so user is never trapped
    _actionTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showActions = true);
    });

    // After 4s safety timeout, force-admit to app so the screen never hangs
    _safetyTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      context.read<AppState>().markCharacterStateLoaded();
    });
  }

  @override
  void dispose() {
    _actionTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF071126),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: Color(0xFFFACC15),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'جارٍ تهيئة حساب البطل...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تحميل بياناتك وتجهيز الساحة',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              if (_showActions) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => appState.markCharacterStateLoaded(),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('المتابعة إلى الرئيسية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => appState.signOut(),
                  child: Text(
                    'تسجيل الخروج والعودة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
