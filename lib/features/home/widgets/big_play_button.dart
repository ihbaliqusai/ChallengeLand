import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class BigPlayButton extends StatefulWidget {
  const BigPlayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<BigPlayButton> createState() => _BigPlayButtonState();
}

class _BigPlayButtonState extends State<BigPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedScale(
      duration: const Duration(milliseconds: 100),
      scale: _pressed ? 0.96 : 1,
      child: Semantics(
        button: true,
        label: AppStrings.playNow,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Container(
            width: (width * 0.43).clamp(164.0, compact ? 184.0 : 206.0),
            height: compact ? 62 : 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFFF00),
                  Color(0xFFFFEA00),
                  Color(0xFFFFA000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFFFE100).withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  right: 12,
                  top: 9,
                  child: Container(
                    height: compact ? 11 : 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: compact ? 14 : 17,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB35800).withValues(alpha: 0.56),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(compact ? 8 : 9),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppStrings.playNow,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 28 : 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          shadows: const [
                            Shadow(
                              color: AppColors.challengeDark,
                              blurRadius: 0,
                              offset: Offset(2, 2),
                            ),
                            Shadow(
                              color: AppColors.challengeDark,
                              blurRadius: 2,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
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
