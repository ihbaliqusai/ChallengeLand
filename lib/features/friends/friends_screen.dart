import 'package:flutter/material.dart';

import '../home/widgets/game_page_shell.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GamePageShell(
      selectedIndex: 1,
      showHud: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, compact ? 18 : 32, 22, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  _TeamHero(compact: compact),
                  SizedBox(height: compact ? 20 : 34),
                  const _TeamsTitle(),
                  SizedBox(height: compact ? 14 : 24),
                  const _TeamFeature(
                    icon: Icons.card_giftcard_rounded,
                    text: 'Get FREE rewards',
                  ),
                  const _TeamFeature(
                    icon: Icons.swap_horizontal_circle_rounded,
                    text: 'Trade Stickers',
                  ),
                  const _TeamFeature(
                    icon: Icons.chat_bubble_rounded,
                    text: 'Chat with players',
                  ),
                  const _TeamFeature(
                    icon: Icons.sticky_note_2_rounded,
                    text: 'Exclusive team events',
                  ),
                  SizedBox(height: compact ? 20 : 34),
                  const LockedRibbon(text: 'UNLOCKS AT  550'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeamHero extends StatelessWidget {
  const _TeamHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 360 : 440,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: compact ? 250 : 310,
            height: compact ? 250 : 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.65),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          Positioned(
            left: compact ? 4 : 2,
            top: compact ? 72 : 86,
            child: Transform.rotate(
              angle: -0.22,
              child: _HappyCharacter(
                size: compact ? 142 : 176,
                bodyColor: const Color(0xFFE6B760),
                faceColor: const Color(0xFFE6D3DD),
                icon: Icons.auto_awesome_rounded,
              ),
            ),
          ),
          Positioned(
            right: compact ? 2 : 0,
            top: compact ? 80 : 96,
            child: Transform.rotate(
              angle: 0.22,
              child: _HappyCharacter(
                size: compact ? 146 : 180,
                bodyColor: const Color(0xFF1FBDE5),
                faceColor: const Color(0xFFFFD34B),
                icon: Icons.flash_on_rounded,
              ),
            ),
          ),
          Positioned(
            top: compact ? 34 : 54,
            child: _HappyCharacter(
              size: compact ? 210 : 260,
              bodyColor: const Color(0xFFE52B2E),
              faceColor: const Color(0xFFFF8D8B),
              icon: Icons.front_hand_rounded,
            ),
          ),
          const Positioned(
            top: 8,
            left: 36,
            child: _FlyingPrize(icon: Icons.style_rounded),
          ),
          const Positioned(
            top: 10,
            right: 46,
            child: _FlyingPrize(icon: Icons.diamond_rounded),
          ),
          const Positioned(
            bottom: 26,
            right: 24,
            child: _FlyingPrize(icon: Icons.confirmation_number_rounded),
          ),
        ],
      ),
    );
  }
}

class _HappyCharacter extends StatelessWidget {
  const _HappyCharacter({
    required this.size,
    required this.bodyColor,
    required this.faceColor,
    required this.icon,
  });

  final double size;
  final Color bodyColor;
  final Color faceColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.12,
            child: Container(
              width: size * 0.54,
              height: size * 0.58,
              decoration: BoxDecoration(
                color: bodyColor,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: const Color(0xFF2A1441), width: 3),
              ),
            ),
          ),
          Positioned(
            top: size * 0.12,
            child: Container(
              width: size * 0.72,
              height: size * 0.62,
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(size * 0.30),
                border: Border.all(color: const Color(0xFF2A1441), width: 3),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2A1441),
                size: size * 0.28,
              ),
            ),
          ),
          Positioned(
            top: size * 0.36,
            child: Container(
              width: size * 0.32,
              height: size * 0.20,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1441),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyingPrize extends StatelessWidget {
  const _FlyingPrize({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: const Color(0xFFFFE548),
      size: 42,
      shadows: const [
        Shadow(color: Colors.white, blurRadius: 12),
        Shadow(color: Color(0xFFFF3FA7), blurRadius: 2, offset: Offset(1, 2)),
      ],
    );
  }
}

class _TeamsTitle extends StatelessWidget {
  const _TeamsTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'TEAMS',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFFFFE337),
        fontSize: 54,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Color(0xFFFF346E), blurRadius: 0, offset: Offset(2, 3)),
          Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 3)),
        ],
      ),
    );
  }
}

class _TeamFeature extends StatelessWidget {
  const _TeamFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFE247), size: 36),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
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
