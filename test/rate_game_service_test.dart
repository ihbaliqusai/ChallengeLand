import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:challenge_land/services/rate_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RateGameService', () {
    test('initial state hasRated is false and reward is not claimed', () async {
      final service = RateGameService.instance;
      expect(await service.hasRated(), isFalse);
      expect(await service.hasClaimedReward(), isFalse);
    });

    test('home rating entry is visible before rating or claiming its reward',
        () async {
      expect(await RateGameService.instance.shouldShowRatingEntry(), isTrue);
    });

    for (final flags in [
      (rated: true, claimed: false),
      (rated: false, claimed: true),
      (rated: true, claimed: true),
    ]) {
      test(
          'home rating entry hides for rated=${flags.rated}, claimed=${flags.claimed}',
          () async {
        SharedPreferences.setMockInitialValues({
          'has_rated_challenge_land': flags.rated,
          'rate_reward_claimed': flags.claimed,
        });
        expect(await RateGameService.instance.shouldShowRatingEntry(), isFalse);
      });
    }

    test('home rating entry hides when persisted flags cannot be read',
        () async {
      SharedPreferences.setMockInitialValues({
        'has_rated_challenge_land': 'invalid',
      });
      expect(await RateGameService.instance.shouldShowRatingEntry(), isFalse);
    });

    test('shouldPromptAuto returns false if victories are below minimum',
        () async {
      final service = RateGameService.instance;
      // 0 victories
      expect(await service.shouldPromptAuto(), isFalse);

      // 1 victory (less than 2)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 1);
      expect(await service.shouldPromptAuto(), isFalse);
    });

    test(
        'shouldPromptAuto returns true if victories >= 2 and never prompted before',
        () async {
      final service = RateGameService.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 2);
      expect(await service.shouldPromptAuto(), isTrue);
    });

    test('shouldPromptAuto returns false if already rated', () async {
      final service = RateGameService.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 5);
      await service.markRated();
      expect(await service.hasRated(), isTrue);
      expect(await service.shouldPromptAuto(), isFalse);
    });

    test('shouldPromptAuto excludes legacy claimed-only rewards', () async {
      SharedPreferences.setMockInitialValues({
        'rate_victories_count': 5,
        'rate_reward_claimed': true,
        'has_rated_challenge_land': false,
      });
      expect(await RateGameService.instance.shouldPromptAuto(), isFalse);
    });

    test('shouldPromptAuto returns false if max auto prompts exceeded',
        () async {
      final service = RateGameService.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 5);
      await prefs.setInt('rate_prompt_count', RateGameService.maxAutoPrompts);
      expect(await service.shouldPromptAuto(), isFalse);
    });

    test('markPromptShown increments prompt count and updates last prompt time',
        () async {
      final service = RateGameService.instance;
      await service.markPromptShown();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rate_prompt_count'), equals(1));
      expect(prefs.getInt('rate_last_prompt_timestamp'), isNotNull);
    });

    test('per-uid rating and claim flags hide rating entry', () async {
      const uid = 'test_user_123';
      SharedPreferences.setMockInitialValues({
        RateGameService.userRatedKey(uid): true,
      });

      expect(
          await RateGameService.instance.shouldShowRatingEntry(uid: uid), isFalse);
      expect(await RateGameService.instance.hasRated(uid: uid), isTrue);
    });

    test('per-uid reward claim flag prevents duplicate showing', () async {
      const uid = 'test_user_456';
      SharedPreferences.setMockInitialValues({
        RateGameService.userRewardKey(uid): true,
      });

      expect(
          await RateGameService.instance.shouldShowRatingEntry(uid: uid), isFalse);
      expect(await RateGameService.instance.hasClaimedReward(uid: uid), isTrue);
    });

    test('markRated with uid sets both global and per-uid preference keys',
        () async {
      const uid = 'test_user_789';
      final service = RateGameService.instance;
      await service.markRated(uid: uid);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_rated_challenge_land'), isTrue);
      expect(prefs.getBool(RateGameService.userRatedKey(uid)), isTrue);
      expect(await service.hasRated(uid: uid), isTrue);
      expect(await service.shouldShowRatingEntry(uid: uid), isFalse);
    });
  });
}
