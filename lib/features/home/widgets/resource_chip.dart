import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ResourceChip extends StatelessWidget {
  const ResourceChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.challengeGold,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Container(
        constraints: BoxConstraints(
          minHeight: compact ? 42 : 48,
          minWidth: compact ? 54 : 94,
        ),
        padding: EdgeInsetsDirectional.only(
          start: compact ? 7 : 9,
          end: compact ? 8 : 12,
          top: compact ? 6 : 7,
          bottom: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.challengeNavy.withValues(alpha: 0.9),
              AppColors.challengeCard.withValues(alpha: 0.88),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.62)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: icon == Icons.local_fire_department_rounded
                    ? Colors.white
                    : AppColors.challengeDark,
                size: compact ? 18 : 20,
              ),
            ),
            SizedBox(width: compact ? 5 : 7),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.challengeGray,
                      fontSize: compact ? 8.5 : 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 14 : 16,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
