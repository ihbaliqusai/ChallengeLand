import 'package:challenge_land/models/game_session.dart';
import 'package:challenge_land/models/question.dart';
import 'package:challenge_land/models/room.dart';
import 'package:challenge_land/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_models.dart';

void main() {
  group('UserProfile', () {
    test('round-trips through JSON and supports copyWith', () {
      final profile = sampleUserProfile();
      final json = profile.toJson();
      final parsed = UserProfile.fromJson(json);
      final copied = parsed.copyWith(username: 'لاعب جديد', wins: 10);

      expect(parsed.uid, profile.uid);
      expect(parsed.username, profile.username);
      expect(parsed.createdAt, profile.createdAt);
      expect(json, containsPair('coins', 180));
      expect(copied.username, 'لاعب جديد');
      expect(copied.wins, 10);
      expect(copied.losses, profile.losses);
    });
  });

  group('Question', () {
    test('round-trips through JSON and supports copyWith', () {
      final question = sampleQuestion();
      final json = question.toJson();
      final parsed = Question.fromJson(json);
      final copied = parsed.copyWith(points: 150, difficulty: 'medium');

      expect(parsed.id, question.id);
      expect(parsed.options, question.options);
      expect(parsed.isCorrect(' عمّان '), isTrue);
      expect(json, containsPair('isActive', true));
      expect(copied.points, 150);
      expect(copied.difficulty, 'medium');
      expect(copied.correctAnswer, question.correctAnswer);
    });
  });

  group('GameSession', () {
    test('round-trips through JSON and supports copyWith', () {
      final session = sampleGameSession(status: 'finished');
      final json = session.toJson();
      final parsed = GameSession.fromJson(json);
      final copied = parsed.copyWith(
        currentQuestionIndex: 1,
        playerScores: const {'player-1': 220, 'bot-arena': 150},
      );

      expect(parsed.id, session.id);
      expect(parsed.isFinished, isTrue);
      expect(parsed.playerScores['player-1'], 150);
      expect(json, containsPair('winnerId', 'player-1'));
      expect(copied.currentQuestionIndex, 1);
      expect(copied.playerScores['player-1'], 220);
      expect(copied.timerSeconds, session.timerSeconds);
    });
  });

  group('Room', () {
    test('round-trips nested players and teams and supports copyWith', () {
      final room = sampleRoom();
      final json = room.toJson();
      final parsed = Room.fromJson(json);
      final copied = parsed.copyWith(status: 'active', maxPlayers: 1);

      expect(parsed.id, room.id);
      expect(parsed.players.single.uid, 'player-1');
      expect(parsed.teams, hasLength(2));
      expect(parsed.isWaiting, isTrue);
      expect(json['players'], isA<List<dynamic>>());
      expect(copied.status, 'active');
      expect(copied.isFull, isTrue);
      expect(copied.code, room.code);
    });
  });
}
