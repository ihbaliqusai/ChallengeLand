import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

class ProgressUnlockBanner extends StatelessWidget {
  const ProgressUnlockBanner({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: compact ? 100 : 118,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: compact ? 17 : 22,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C38FF),
                      Color(0xFFC24CFF),
                      Color(0xFFFE4BA6),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFEFC7FF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B1FD9).withValues(alpha: 0.42),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: compact ? 40 : 51,
              left: compact ? 55 : 68,
              right: compact ? 88 : 108,
              child: _ProgressTrack(progress: progress),
            ),
            Positioned(
              top: compact ? 73 : 88,
              left: 0,
              right: 0,
              child: Text(
                AppStrings.winTwoMore,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Color(0xFF190B36),
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: compact ? 35 : 44,
              left: compact ? 14 : 18,
              child: _TrophyMedal(size: compact ? 52 : 62),
            ),
            Positioned(
              top: compact ? 6 : 4,
              right: compact ? 56 : 74,
              child: _NextUnlockTag(compact: compact),
            ),
            Positioned(
              top: compact ? 13 : 16,
              right: compact ? 14 : 20,
              child: _RewardShield(size: compact ? 65 : 76),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1854),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF160B38), width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 780),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF500), Color(0xFFFF9E00)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Center(
            child: Text(
              AppStrings.unlockProgress,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xFF120621),
                    blurRadius: 3,
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

class _NextUnlockTag extends StatelessWidget {
  const _NextUnlockTag({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-0.16),
      child: Container(
        width: compact ? 132 : 156,
        height: compact ? 34 : 39,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF49A5), Color(0xFFFF69C4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF401047), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Transform(
            transform: Matrix4.skewX(0.16),
            child: Text(
              AppStrings.nextReward,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    color: Color(0xFF33072C),
                    blurRadius: 2,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrophyMedal extends StatelessWidget {
  const _TrophyMedal({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF35A), Color(0xFFFF9900)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: const Color(0xFF763900), width: 2),
            ),
          ),
          const Icon(
            Icons.emoji_events_rounded,
            color: Colors.white,
            size: 38,
            shadows: [
              Shadow(
                color: Color(0xFF6C3300),
                blurRadius: 2,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardShield extends StatelessWidget {
  const _RewardShield({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.03,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB864), Color(0xFFE76B21)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF361232), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.card_giftcard_rounded,
            color: Color(0xFF5C2A20),
            size: 46,
          ),
        ],
      ),
    );
  }
}
