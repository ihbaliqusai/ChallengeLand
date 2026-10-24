import 'package:flutter/material.dart';

import '../../models/question.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.total,
  });

  final Question question;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : index / total;
    return AppCard(
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF263653), AppColors.challengeNavy],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.challengeGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.challengeGold.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  'السؤال $index من $total',
                  style: const TextStyle(
                    color: AppColors.challengeGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress.clamp(0, 1),
                    color: AppColors.challengeCyan,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.challengeGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.mediaUrl == null
                        ? 'اختر الإجابة بسرعة لتحصل على مكافأة سرعة.'
                        : 'وسائط السؤال ستظهر هنا عند تفعيل أسئلة الصور والصوت.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (question.mediaUrl != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(Icons.image_rounded, size: 42)),
            ),
          ],
        ],
      ),
    );
  }
}
