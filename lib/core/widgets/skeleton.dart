import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 96});

  final double height;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_controller),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.challengeCard.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
