import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = AppStrings.noData,
    this.icon = Icons.inbox_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
