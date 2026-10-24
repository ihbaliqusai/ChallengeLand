import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
    this.level,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.challengePurple, AppColors.challengeCyan],
              ),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: photoUrl == null || photoUrl!.isEmpty
                ? Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : ClipOval(child: Image.network(photoUrl!, fit: BoxFit.cover)),
          ),
          if (level != null)
            Positioned(
              left: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.challengeGold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.challengeDark),
                ),
                child: Text(
                  '$level',
                  style: const TextStyle(
                    color: AppColors.challengeDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
