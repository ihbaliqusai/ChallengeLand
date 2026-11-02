import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/performance_probe.dart';
import '../character/character_select_screen.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart';

/// Prepares account data under the intro, then reveals the resolved destination.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.onReady,
    this.introDuration = Duration.zero,
  });

  final VoidCallback? onReady;

  /// Optional presentation delay; normal launches wait only for account data.
  final Duration introDuration;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introComplete = false;
  bool _didNotifyReady = false;

  @override
  void initState() {
    super.initState();
    _introComplete = widget.introDuration <= Duration.zero;
  }

  void _finishIntro() {
    if (mounted && !_introComplete) {
      setState(() => _introComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final ready = _introComplete && appState.isAccountReady;
        if (ready && !_didNotifyReady) {
          PerformanceProbe.mark('account.destination.ready');
          _didNotifyReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onReady?.call();
          });
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: ready
              ? KeyedSubtree(
                  key: const ValueKey('destination'),
                  child: _destination(appState),
                )
              : SplashScreen(
                  key: const ValueKey('startup-splash'),
                  onComplete: _finishIntro,
                  duration: widget.introDuration,
                ),
        );
      },
    );
  }

  Widget _destination(AppState appState) {
    if (appState.user == null) {
      return const HomeScreen();
    }
    if (!appState.hasChosenCharacter) {
      return const CharacterSelectScreen(forced: true);
    }
    return const HomeScreen();
  }
}
