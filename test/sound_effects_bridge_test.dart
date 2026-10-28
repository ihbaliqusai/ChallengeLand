import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockNativeBridge extends NativeBridgeService {
  final List<String> playedEffects = [];
  bool sfxEnabled = true;

  @override
  Future<Map<String, dynamic>> getSettings() async {
    return {
      'sfx': sfxEnabled,
      'music': false,
      'haptic': true,
      'hapticAvailable': true,
      'notifications': true,
      'systemNotifications': true,
      'dialogs': true,
      'language': 'ar',
    };
  }

  @override
  Future<bool> playSoundEffect({String effect = 'click'}) async {
    playedEffects.add(effect);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSettings.resetClickDebounce();
  });

  test('AppSettings respects sfx setting when triggering sound effects', () async {
    final bridge = _MockNativeBridge();
    final settings = AppSettings(bridge);
    await settings.load();

    expect(settings.sfx, isTrue);

    // Test playing when sfx is true
    await settings.playButtonClick();
    await settings.playWheelTick();
    await settings.playWheelWin();

    expect(bridge.playedEffects, equals(['click', 'wheel_tick', 'wheel_win']));

    // Disable SFX
    bridge.playedEffects.clear();
    settings.sfx = false;

    await settings.playButtonClick();
    await settings.playWheelTick();
    await settings.playWheelWin();

    expect(bridge.playedEffects, isEmpty,
        reason: 'Disabled SFX should never invoke the native sound effect channel');
  });

  test('AppSettings throttles rapid duplicate clicks within debounce window', () async {
    final bridge = _MockNativeBridge();
    final settings = AppSettings(bridge);
    await settings.load();

    // Rapid successive click calls
    await settings.playButtonClick();
    await settings.playButtonClick();
    await AppSettings.playClick();

    // Should only have triggered 'click' once because subsequent calls within 90ms are debounced
    expect(bridge.playedEffects, equals(['click']));

    // Wait past debounce threshold
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await settings.playButtonClick();

    expect(bridge.playedEffects, equals(['click', 'click']));
  });
}
