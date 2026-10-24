import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../state/game_provider.dart';

class AnswerRevealScreen extends StatelessWidget {
  const AnswerRevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final question = context.watch<GameProvider>().currentQuestion;
    return ChallengeScaffold(
      title: 'كشف الإجابة',
      children: [
        AppCard(
          child: Text(
            question == null
                ? 'لا توجد إجابة لعرضها.'
                : 'الإجابة الصحيحة: ${question.correctAnswer}\n${question.explanation ?? ''}',
          ),
        ),
      ],
    );
  }
}
