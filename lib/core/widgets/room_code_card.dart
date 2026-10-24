import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';

class RoomCodeCard extends StatelessWidget {
  const RoomCodeCard({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: const LinearGradient(
        colors: [AppColors.challengePurple, AppColors.challengePink],
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('كود الغرفة'),
                Text(
                  code,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'نسخ الكود',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ كود الغرفة')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
