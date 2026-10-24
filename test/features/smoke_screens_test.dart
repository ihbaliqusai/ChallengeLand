import 'package:challenge_land/core/constants/app_strings.dart';
import 'package:challenge_land/features/auth/login_screen.dart';
import 'package:challenge_land/features/game/game_mode_selection_screen.dart';
import 'package:challenge_land/features/game/game_result_screen.dart';
import 'package:challenge_land/features/game/question_screen.dart';
import 'package:challenge_land/features/home/home_screen.dart';
import 'package:challenge_land/state/game_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_app.dart';
import '../helpers/sample_models.dart';

void main() {
  testWidgets('LoginScreen renders without Firebase initialization', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: LoginScreen()));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(AppStrings.continueAsGuest), findsOneWidget);
    expect(find.text(AppStrings.loginWithGoogle), findsOneWidget);
  });

  testWidgets('HomeScreen renders in mock mode for a signed-in user', (
    tester,
  ) async {
    final auth = await signedInAuthProvider();

    await tester.pumpWidget(
      TestApp(authProvider: auth, child: const HomeScreen()),
    );
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(AppStrings.playNow), findsOneWidget);
  });

  testWidgets('GameModeSelectionScreen renders main game modes', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: GameModeSelectionScreen()));

    expect(find.byType(GameModeSelectionScreen), findsOneWidget);
    expect(find.text(AppStrings.quickChallenge), findsOneWidget);
    expect(find.text(AppStrings.dailyChallenge), findsOneWidget);
  });

  testWidgets('QuestionScreen renders an existing mock game question', (
    tester,
  ) async {
    final auth = await signedInAuthProvider();
    final game = GameProvider()
      ..session = sampleGameSession(playerId: auth.user!.uid)
      ..questions = [sampleQuestion()]
      ..playerScore = 25
      ..opponentScore = 10;

    await tester.pumpWidget(
      TestApp(
        authProvider: auth,
        gameProvider: game,
        child: const QuestionScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(QuestionScreen), findsOneWidget);
    expect(find.text(sampleQuestion().questionText), findsOneWidget);
    expect(find.text(sampleQuestion().correctAnswer), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('GameResultScreen renders scores and result actions', (
    tester,
  ) async {
    final auth = await signedInAuthProvider();
    final game = GameProvider()
      ..session = sampleGameSession(
        playerId: auth.user!.uid,
        status: 'finished',
      )
      ..playerScore = 320
      ..opponentScore = 210
      ..correctAnswers = 3
      ..wrongAnswers = 1;

    await tester.pumpWidget(
      TestApp(
        authProvider: auth,
        gameProvider: game,
        child: const GameResultScreen(),
      ),
    );

    expect(find.byType(GameResultScreen), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(find.text(AppStrings.playAgain), findsOneWidget);
    expect(find.text(AppStrings.backHome), findsOneWidget);
  });
}
