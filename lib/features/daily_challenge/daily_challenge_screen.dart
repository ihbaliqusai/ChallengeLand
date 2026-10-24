import 'package:flutter/material.dart';

import '../home/widgets/game_page_shell.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GamePageShell(
      selectedIndex: 3,
      child: Column(
        children: const [
          _EventsTabs(),
          Expanded(child: _EventsBody()),
        ],
      ),
    );
  }
}

class _EventsTabs extends StatelessWidget {
  const _EventsTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF061B83).withValues(alpha: 0.74),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF008FFF), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          _EventTab(
            label: 'EVENTS',
            icon: Icons.public_rounded,
            selected: true,
          ),
          _EventTab(
            label: 'PRIVATE',
            icon: Icons.handshake_rounded,
            selected: false,
          ),
          Spacer(),
        ],
      ),
    );
  }
}

class _EventTab extends StatelessWidget {
  const _EventTab({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 146 : 160,
      height: selected ? 88 : 76,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? const [Color(0xFF2BC3FF), Color(0xFF0876D9)]
              : const [Color(0xFF1167E8), Color(0xFF083DAC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 38),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
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
          ),
        ],
      ),
    );
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, compact ? 16 : 28, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
            child: Column(
              children: [
                _EventCollage(height: compact ? 360 : 440),
                SizedBox(height: compact ? 28 : 48),
                const Text(
                  'EXCITING EVENTS AND AMAZING MODES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                const SizedBox(height: 18),
                const _UnlockAt(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventCollage extends StatelessWidget {
  const _EventCollage({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: height * 0.78,
            height: height * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFE8AA).withValues(alpha: 0.98),
                  const Color(0xFFFF2AB6).withValues(alpha: 0.48),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Positioned(
            top: 18,
            left: 28,
            child: _FloatingEventIcon(icon: Icons.map_rounded),
          ),
          const Positioned(
            top: 36,
            right: 58,
            child: _FloatingEventIcon(icon: Icons.rocket_launch_rounded),
          ),
          const Positioned(
            bottom: 34,
            left: 26,
            child: _FloatingEventIcon(
              icon: Icons.directions_car_rounded,
              large: true,
            ),
          ),
          const Positioned(
            bottom: 56,
            right: 42,
            child: _FloatingEventIcon(icon: Icons.emoji_events_rounded),
          ),
          Positioned(
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: height * 0.34,
                height: height * 0.30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4D2249), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFEB83).withValues(alpha: 0.85),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Color(0xFF5B3517),
                  size: 84,
                ),
              ),
            ),
          ),
          const Positioned(
            top: 125,
            left: 10,
            child: _CharacterBadge(icon: Icons.face_retouching_natural_rounded),
          ),
          const Positioned(
            top: 110,
            right: 18,
            child: _CharacterBadge(icon: Icons.celebration_rounded),
          ),
          const Positioned(
            right: 8,
            bottom: 118,
            child: _FloatingEventIcon(icon: Icons.flag_rounded),
          ),
        ],
      ),
    );
  }
}

class _FloatingEventIcon extends StatelessWidget {
  const _FloatingEventIcon({required this.icon, this.large = false});

  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: large ? const Color(0xFFFF365E) : const Color(0xFFFFE745),
      size: large ? 82 : 60,
      shadows: const [
        Shadow(color: Colors.white, blurRadius: 12),
        Shadow(color: Color(0xFF3C073E), blurRadius: 2, offset: Offset(0, 3)),
      ],
    );
  }
}

class _CharacterBadge extends StatelessWidget {
  const _CharacterBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFDE72), Color(0xFFE3558B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFF4A174D), width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 56),
    );
  }
}

class _UnlockAt extends StatelessWidget {
  const _UnlockAt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text(
          'UNLOCK AT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 3)),
            ],
          ),
        ),
        SizedBox(width: 16),
        Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD63D), size: 58),
        SizedBox(width: 10),
        Text(
          '800',
          style: TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 3)),
            ],
          ),
        ),
      ],
    );
  }
}
