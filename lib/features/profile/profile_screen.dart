import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../state/auth_provider.dart';
import '../../state/profile_provider.dart';
import '../home/widgets/game_page_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) context.read<ProfileProvider>().load(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final profile = context.watch<ProfileProvider>().profile ?? user;

    return GamePageShell(
      selectedIndex: 2,
      child: profile == null
          ? const Center(child: Text('Sign in first'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
              children: [
                const GameSectionTitle('YOUR PROFILE'),
                const SizedBox(height: 18),
                _ProfileHero(
                  name: profile.username,
                  level: profile.level,
                  xp: profile.xp,
                  nextLevelXp: profile.level * 250,
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.48,
                  children: [
                    _ProfileStat(
                      label: 'COINS',
                      value: '${profile.coins}',
                      icon: Icons.monetization_on_rounded,
                    ),
                    _ProfileStat(
                      label: 'TROPHIES',
                      value: '${profile.trophies}',
                      icon: Icons.emoji_events_rounded,
                    ),
                    _ProfileStat(
                      label: 'RATING',
                      value: '${profile.rating}',
                      icon: Icons.trending_up_rounded,
                    ),
                    _ProfileStat(
                      label: 'WINS',
                      value: '${profile.wins}',
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProfileAction(
                  label: 'EDIT PLAYER NAME',
                  icon: Icons.edit_rounded,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.username),
                ),
                const SizedBox(height: 12),
                _ProfileAction(
                  label: 'MATCH HISTORY',
                  icon: Icons.history_rounded,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.matchHistory),
                ),
              ],
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
  });

  final String name;
  final int level;
  final int xp;
  final int nextLevelXp;

  @override
  Widget build(BuildContext context) {
    final progress = (xp / nextLevelXp).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BFFF), Color(0xFF116BCA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF073E8E), width: 3),
      ),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB7C0), Color(0xFFFF6675)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'LEVEL $level',
            style: const TextStyle(
              color: Color(0xFFFFE545),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: const Color(0xFF0A2A69),
              color: const Color(0xFFFFE200),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE62EFF), Color(0xFF8411C7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFE32E), size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StoreButton(label: label, icon: icon, onPressed: onPressed);
  }
}
