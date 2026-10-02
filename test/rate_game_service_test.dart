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

    test('shouldPromptAuto returns false if victories are below minimum', () async {
      final service = RateGameService.instance;
      // 0 victories
      expect(await service.shouldPromptAuto(), isFalse);

      // 1 victory (less than 2)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 1);
      expect(await service.shouldPromptAuto(), isFalse);
    });

    test('shouldPromptAuto returns true if victories >= 2 and never prompted before', () async {
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

    test('shouldPromptAuto returns false if max auto prompts exceeded', () async {
      final service = RateGameService.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rate_victories_count', 5);
      await prefs.setInt('rate_prompt_count', RateGameService.maxAutoPrompts);
      expect(await service.shouldPromptAuto(), isFalse);
    });

    test('markPromptShown increments prompt count and updates last prompt time', () async {
      final service = RateGameService.instance;
      await service.markPromptShown();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rate_prompt_count'), equals(1));
      expect(prefs.getInt('rate_last_prompt_timestamp'), isNotNull);
    });
  });
}
