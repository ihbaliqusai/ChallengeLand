import 'package:challenge_land/core/utils/score_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sample_models.dart';

void main() {
  group('ScoreUtils.calculateSpeedBonus', () {
    test('returns proportional bonus capped at 50', () {
      expect(
        ScoreUtils.calculateSpeedBonus(remainingTime: 15, totalTime: 15),
        50,
      );
      expect(
        ScoreUtils.calculateSpeedBonus(remainingTime: 8, totalTime: 15),
        27,
      );
      expect(
        ScoreUtils.calculateSpeedBonus(remainingTime: 30, totalTime: 15),
        50,
      );
    });

    test('returns zero for invalid or expired timers', () {
      expect(
        ScoreUtils.calculateSpeedBonus(remainingTime: 0, totalTime: 15),
        0,
      );
      expect(
        ScoreUtils.calculateSpeedBonus(remainingTime: 10, totalTime: 0),
        0,
      );
    });
  });

  group('ScoreUtils.calculateQuestionScore', () {
    test('adds base points and speed bonus for correct answers', () {
      expect(
        ScoreUtils.calculateQuestionScore(
          isCorrect: true,
          remainingTime: 12,
          totalTime: 15,
        ),
        140,
      );
    });

    test('returns zero for wrong answers', () {
      expect(
        ScoreUtils.calculateQuestionScore(
          isCorrect: false,
          remainingTime: 15,
          totalTime: 15,
        ),
        0,
      );
    });
  });

  group('ScoreUtils.calculateWinner', () {
    test('returns the highest scoring player id', () {
      final session = sampleGameSession().copyWith(
        playerScores: const {'player-1': 210, 'bot-arena': 120},
      );

      expect(ScoreUtils.calculateWinner(session), 'player-1');
    });

    test('returns null for ties or empty scores', () {
      expect(
        ScoreUtils.calculateWinner(
          sampleGameSession().copyWith(
            playerScores: const {'player-1': 100, 'bot-arena': 100},
          ),
        ),
        isNull,
      );
      expect(
        ScoreUtils.calculateWinner(
          sampleGameSession().copyWith(playerScores: const {}),
        ),
        isNull,
      );
    });
  });
}
