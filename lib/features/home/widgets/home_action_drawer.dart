import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';

class HomeActionDrawer extends StatelessWidget {
  const HomeActionDrawer({super.key});

  static void show(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black.withValues(alpha: 0.64),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SafeArea(child: HomeActionDrawer());
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 122,
          right: 24,
          child: CustomPaint(
            painter: _MenuPointerPainter(),
            child: const SizedBox(width: 34, height: 26),
          ),
        ),
        Align(
          alignment: const Alignment(0.82, -0.35),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43C2FF), Color(0xFF198BE9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF075DA5), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItem(
                    icon: Icons.account_circle_rounded,
                    label: 'YOUR PROFILE',
                    onTap: () => _go(context, AppRoutes.profile),
                  ),
                  _MenuItem(
                    icon: Icons.diversity_3_rounded,
                    label: 'FRIENDS',
                    onTap: () => _go(context, AppRoutes.friends),
                  ),
                  _MenuItem(
                    icon: Icons.leaderboard_rounded,
                    label: 'LEADERBOARDS',
                    onTap: () => _go(context, AppRoutes.leaderboard),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _MenuItem(
                        icon: Icons.article_rounded,
                        label: 'NEWS',
                        onTap: () => _go(context, AppRoutes.dailyChallenge),
                      ),
                      const Positioned(left: -28, top: 13, child: _Badge()),
                    ],
                  ),
                  _MenuItem(
                    icon: Icons.thumb_up_alt_rounded,
                    label: 'JOIN US',
                    onTap: () => _go(context, AppRoutes.userSearch),
                  ),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    label: 'SUPPORT',
                    onTap: () => _go(context, AppRoutes.settings),
                  ),
                  _MenuItem(
                    icon: Icons.link_rounded,
                    label: 'CONNECT ACCOUNT',
                    onTap: () => _go(context, AppRoutes.settings),
                  ),
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    label: 'SETTINGS',
                    onTap: () => _go(context, AppRoutes.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.pushNamed(context, route);
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D67AD),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.16),
                  blurRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 43),
                const SizedBox(width: 18),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFE91524),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: const Center(
        child: Text(
          '1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF43C2FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width * 0.60, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
