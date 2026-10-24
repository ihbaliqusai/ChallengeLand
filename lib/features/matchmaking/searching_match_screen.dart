import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../state/auth_provider.dart';
import '../../state/game_provider.dart';
import '../../state/matchmaking_provider.dart';

class SearchingMatchScreen extends StatefulWidget {
  const SearchingMatchScreen({super.key});

  @override
  State<SearchingMatchScreen> createState() => _SearchingMatchScreenState();
}

class _SearchingMatchScreenState extends State<SearchingMatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _search();
  }

  Future<void> _search() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }
    await context.read<MatchmakingProvider>().startQuickMatch(user);
    if (!mounted) return;
    await context.read<GameProvider>().startGame(
      player: user,
      mode: 'quick_1v1',
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.question);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchmaking = context.watch<MatchmakingProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.challengeCyan,
                          AppColors.challengePurple,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.challengeCyan.withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radar_rounded, size: 62),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  matchmaking.error ?? 'نبحث عن منافس...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('حضّر أصابعك، السرعة تصنع الفارق.'),
                const SizedBox(height: 26),
                AppButton(
                  label: 'إلغاء البحث',
                  icon: Icons.close_rounded,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
