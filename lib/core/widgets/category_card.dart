import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.challengeCyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.category_rounded,
              color: AppColors.challengeCyan,
            ),
          ),
          const Spacer(),
          Text(
            category.titleAr,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text('أسئلة سريعة ومتنوعة'),
        ],
      ),
    );
  }
}
