import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/sound_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool soundOn = true;
  double soundVolume = 0.85;
  bool vibrationOn = true;
  bool notificationsOn = false;
  String languageCode = 'ar';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    soundOn = preferences.getBool('soundOn') ?? true;
    soundVolume = preferences.getDouble('soundVolume') ?? 0.85;
    vibrationOn = preferences.getBool('vibrationOn') ?? true;
    notificationsOn = preferences.getBool('notificationsOn') ?? false;
    languageCode = preferences.getString('languageCode') ?? 'ar';
    await SoundService.instance.setMuted(!soundOn);
    await SoundService.instance.setVolume(soundVolume);
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    soundOn = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('soundOn', value);
    await SoundService.instance.setMuted(!value);
  }

  Future<void> setSoundVolume(double value) async {
    soundVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await SoundService.instance.setVolume(soundVolume);
  }

  Future<void> setVibration(bool value) =>
      _setBool('vibrationOn', value, (next) {
        vibrationOn = next;
      });

  Future<void> setNotifications(bool value) =>
      _setBool('notificationsOn', value, (next) {
        notificationsOn = next;
      });

  Future<void> _setBool(
    String key,
    bool value,
    void Function(bool value) apply,
  ) async {
    apply(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }
}
