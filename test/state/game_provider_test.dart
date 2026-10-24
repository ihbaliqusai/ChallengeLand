import 'package:challenge_land/core/constants/app_strings.dart';
import 'package:challenge_land/state/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_models.dart';

void main() {
  group('GameProvider mock gameplay flow', () {
    late GameProvider game;
    final player = sampleUserProfile();

    void seedGame({int questionCount = 1}) {
      final questions = List.generate(
        questionCount,
        (index) => sampleQuestion(id: 'question-$index'),
      );
      game
        ..session = sampleGameSession(playerId: player.uid).copyWith(
          questionIds: questions.map((question) => question.id).toList(),
        )
        ..questions = questions
        ..answers = const []
        ..selectedAnswer = null
        ..revealMessage = null
        ..isRevealVisible = false
        ..didTimeout = false
        ..playerScore = 0
        ..opponentScore = 0
        ..correctAnswers = 0
        ..wrongAnswers = 0
        ..currentIndex = 0
        ..latestHistory = null;
    }

    setUp(() {
      game = GameProvider();
      seedGame();
    });

    test('correct answer adds base score and speed bonus', () async {
      final question = game.currentQuestion!;

      await game.submitAnswer(
        player: player,
        answer: question.correctAnswer,
        remainingTime: 12,
      );

      expect(game.playerScore, 140);
      expect(game.correctAnswers, 1);
      expect(game.wrongAnswers, 0);
      expect(game.isRevealVisible, isTrue);
      expect(game.revealMessage, AppStrings.correctAnswerTitle);
      expect(game.answers.single.score, 140);
      expect(game.answers.single.isCorrect, isTrue);
    });

    test('wrong answer scores zero and reveals the answer', () async {
      await game.submitAnswer(
        player: player,
        answer: 'إربد',
        remainingTime: 12,
      );

      expect(game.playerScore, 0);
      expect(game.correctAnswers, 0);
      expect(game.wrongAnswers, 1);
      expect(game.isRevealVisible, isTrue);
      expect(game.revealMessage, AppStrings.wrongAnswerTitle);
      expect(game.answers.single.score, 0);
      expect(game.answers.single.isCorrect, isFalse);
    });

    test('timeout records a wrong zero-point answer', () async {
      await game.submitTimeout(player: player);

      expect(game.playerScore, 0);
      expect(game.wrongAnswers, 1);
      expect(game.didTimeout, isTrue);
      expect(game.selectedAnswer, AppStrings.timeExpired);
      expect(game.revealMessage, AppStrings.timeExpired);
      expect(game.answers.single.remainingTime, 0);
      expect(game.answers.single.score, 0);
      expect(game.answers.single.isCorrect, isFalse);
    });

    test('duplicate answer is blocked after reveal', () async {
      final question = game.currentQuestion!;
      await game.submitAnswer(
        player: player,
        answer: question.correctAnswer,
        remainingTime: 15,
      );
      final scoreAfterFirstAnswer = game.playerScore;

      await game.submitAnswer(player: player, answer: 'إربد', remainingTime: 5);

      expect(game.answers, hasLength(1));
      expect(game.playerScore, scoreAfterFirstAnswer);
      expect(game.error, AppStrings.duplicateAnswer);
    });

    test(
      'nextQuestion finishes the final question and creates result data',
      () async {
        seedGame(questionCount: 2);

        await game.submitAnswer(
          player: player,
          answer: game.currentQuestion!.correctAnswer,
          remainingTime: 15,
        );
        await game.nextQuestion(player);
        expect(game.currentIndex, 1);
        expect(game.isFinished, isFalse);

        await game.submitAnswer(
          player: player,
          answer: 'إربد',
          remainingTime: 2,
        );
        await game.nextQuestion(player);

        expect(game.isFinished, isTrue);
        expect(game.session?.winnerId, isNotEmpty);
        expect(game.latestHistory, isNotNull);
        expect(game.latestHistory?.correctAnswers, 1);
        expect(game.latestHistory?.wrongAnswers, 1);
      },
    );
  });
}
