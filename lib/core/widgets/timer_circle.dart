import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class TimerCircle extends StatelessWidget {
  const TimerCircle({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 70,
  });

  final int remaining;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final color = progress > 0.35
        ? AppColors.challengeGreen
        : progress > 0.15
        ? AppColors.challengeGold
        : AppColors.challengeRed;
    return Semantics(
      label: 'المؤقت $remaining ثانية',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: remaining <= 5 ? 1.06 : 1,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.challengeCard, AppColors.challengeNavy],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: remaining <= 5 ? 0.38 : 0.18),
                blurRadius: remaining <= 5 ? 18 : 10,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: color,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remaining',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: size > 74 ? 22 : 19,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ث',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
