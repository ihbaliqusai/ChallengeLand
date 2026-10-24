import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../state/auth_provider.dart';
import '../../../state/home_provider.dart';
import 'bottom_game_nav.dart';
import 'game_hud.dart';
import 'home_action_drawer.dart';
import 'home_scene.dart';
import 'side_boost_button.dart';

class GamePageShell extends StatelessWidget {
  const GamePageShell({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.background,
    this.showHud = true,
    this.showSideHandle = true,
  });

  final int selectedIndex;
  final Widget child;
  final Widget? background;
  final bool showHud;
  final bool showSideHandle;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final home = context.watch<HomeProvider>();
    final padding = MediaQuery.paddingOf(context);
    final compact = MediaQuery.sizeOf(context).height < 700;
    final contentTop = showHud ? padding.top + (compact ? 64 : 78) : 0.0;
    final contentBottom = padding.bottom + (compact ? 100 : 116);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: background ?? const _NebulaBackground()),
          Positioned.fill(top: contentTop, bottom: contentBottom, child: child),
          if (showHud)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: GameHud(
                username: user?.username ?? 'Player',
                trophies: user?.trophies ?? home.trophies,
                energy: user?.energy ?? home.energy,
                coins: user?.coins ?? home.coins,
                onMenu: () => HomeActionDrawer.show(context),
              ),
            ),
          if (showSideHandle)
            PositionedDirectional(
              end: -1,
              top: MediaQuery.sizeOf(context).height * 0.36,
              child: const SideBoostButton(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomGameNav(
              selectedIndex: selectedIndex,
              onSelected: (index) => goToGameTab(context, index),
            ),
          ),
        ],
      ),
    );
  }
}

void goToGameTab(BuildContext context, int index) {
  final route = switch (index) {
    0 => AppRoutes.shop,
    1 => AppRoutes.friends,
    2 => AppRoutes.home,
    3 => AppRoutes.dailyChallenge,
    4 => AppRoutes.albums,
    _ => AppRoutes.home,
  };

  final current = ModalRoute.of(context)?.settings.name;
  if (current == route) return;
  if (route == AppRoutes.home) {
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  } else if (current == AppRoutes.home) {
    Navigator.pushNamed(context, route);
  } else {
    Navigator.pushReplacementNamed(context, route);
  }
}

class DimmedHomeBackground extends StatelessWidget {
  const DimmedHomeBackground({super.key, this.opacity = 0.62});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: HomeScene()),
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
        ),
      ],
    );
  }
}

class GameSectionTitle extends StatelessWidget {
  const GameSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: _TitleLine()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
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
            const Expanded(child: _TitleLine()),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class LockedRibbon extends StatelessWidget {
  const LockedRibbon({
    super.key,
    required this.text,
    this.icon = Icons.lock_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF120728).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFE600), size: 30),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
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
        ],
      ),
    );
  }
}

class StoreButton extends StatelessWidget {
  const StoreButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5DFF25), Color(0xFF26C916)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0E8218), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFFFFD52F), size: 24),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
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
    );
  }
}

class _NebulaBackground extends StatelessWidget {
  const _NebulaBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _NebulaPainter());
  }
}

class _NebulaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.shader = const LinearGradient(
      colors: [Color(0xFF0E073C), Color(0xFF240064), Color(0xFF090026)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    paint.shader = null;

    final colors = [
      const Color(0xFFB600FF),
      const Color(0xFF365BFF),
      const Color(0xFFFF2EBF),
    ];
    for (var i = 0; i < 18; i++) {
      paint.color = colors[i % colors.length].withValues(alpha: 0.12);
      canvas.drawCircle(
        Offset(
          (i * 67 % size.width).toDouble(),
          size.height * (0.08 + (i % 8) * 0.11),
        ),
        18 + (i % 3) * 10,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TitleLine extends StatelessWidget {
  const _TitleLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
