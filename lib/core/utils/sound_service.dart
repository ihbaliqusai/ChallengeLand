import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameSound {
  correct('correct.mp3'),
  wrong('wrong.mp3'),
  skip('skip.mp3'),
  timerTick('timer_tick.mp3'),
  timerEnd('timer_end.mp3'),
  win('win.mp3'),
  lose('lose.mp3'),
  buttonTap('button_tap.mp3');

  const GameSound(this.fileName);

  final String fileName;
  String get assetPath => 'sounds/$fileName';
}

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final Map<GameSound, AudioPlayer> _players = {};
  final Set<GameSound> _missingAssets = {};

  bool _isMuted = false;
  double _volume = 0.85;
  bool _isInitialized = false;

  bool get isMuted => _isMuted;
  double get volume => _volume;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    final preferences = await SharedPreferences.getInstance();
    _isMuted = !(preferences.getBool('soundOn') ?? true);
    _volume = preferences.getDouble('soundVolume') ?? _volume;
    _volume = _volume.clamp(0.0, 1.0);
    await preload();
    _isInitialized = true;
  }

  Future<void> preload() async {
    for (final sound in GameSound.values) {
      await _ensurePlayer(sound);
    }
  }

  Future<void> play(GameSound sound, {double? volume}) async {
    if (_isMuted || _missingAssets.contains(sound)) return;
    final player = await _ensurePlayer(sound);
    if (player == null) return;

    try {
      await player.stop();
      await player.setSource(AssetSource(sound.assetPath));
      await player.setVolume((volume ?? _volume).clamp(0.0, 1.0));
      await player.resume();
    } catch (exception, stackTrace) {
      _missingAssets.add(sound);
      debugPrint('Sound asset unavailable: ${sound.assetPath}');
      debugPrintStack(stackTrace: stackTrace, label: exception.toString());
    }
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('soundOn', !muted);
    if (muted) await stopAll();
  }

  Future<void> mute() => setMuted(true);

  Future<void> unmute() => setMuted(false);

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('soundVolume', _volume);
    await Future.wait(
      _players.values.map((player) => player.setVolume(_volume)),
    );
  }

  Future<void> stopAll() async {
    await Future.wait(_players.values.map((player) => player.stop()));
  }

  Future<void> dispose() async {
    await Future.wait(_players.values.map((player) => player.dispose()));
    _players.clear();
    _missingAssets.clear();
    _isInitialized = false;
  }

  Future<AudioPlayer?> _ensurePlayer(GameSound sound) async {
    final existing = _players[sound];
    if (existing != null) return existing;

    final player = AudioPlayer(playerId: 'challenge_land_${sound.name}');
    _players[sound] = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(_volume);
      await player.setSource(AssetSource(sound.assetPath));
    } catch (exception, stackTrace) {
      _missingAssets.add(sound);
      debugPrint('Sound preload skipped: ${sound.assetPath}');
      debugPrintStack(stackTrace: stackTrace, label: exception.toString());
    }
    return player;
  }
}
