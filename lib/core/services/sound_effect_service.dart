import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Sound Effect Model
class SoundEffect {
  final String id;
  final String name;
  final String fileName;
  final IconData icon;
  double volume;
  AudioPlayer? player;
  bool isLoading;
  Timer? _debounceTimer;

  SoundEffect({
    required this.id,
    required this.name,
    required this.fileName,
    required this.icon,
    this.volume = 0.0,
    this.isLoading = false,
  });

  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

/// Singleton Sound Effect Service
class SoundEffectService {
  static final SoundEffectService _instance = SoundEffectService._internal();
  factory SoundEffectService() => _instance;
  SoundEffectService._internal();

  final Map<String, SoundEffect> _effects = {};
  final _volumeController = StreamController<Map<String, double>>.broadcast();
  Timer? _sleepTimer;
  bool _isPaused = false;
  bool _isInitialized = false;

  Stream<Map<String, double>> get volumeStream => _volumeController.stream;

  void initialize() {
    if (_isInitialized) return;

    _effects.clear();

    final effects = [
      SoundEffect(
        id: 'train',
        name: 'Train',
        fileName: 'train.opus',
        icon: Icons.train_rounded,
      ),
      SoundEffect(
        id: 'waves',
        name: 'Ocean waves',
        fileName: 'waves.opus',
        icon: Icons.waves_rounded,
      ),
      SoundEffect(
        id: 'rain',
        name: 'Rain',
        fileName: 'rain.opus',
        icon: Icons.water_drop_rounded,
      ),
      SoundEffect(
        id: 'thunder',
        name: 'Thunder',
        fileName: 'thunder.opus',
        icon: Icons.flash_on_rounded,
      ),
      SoundEffect(
        id: 'steps',
        name: 'Steps',
        fileName: 'steps.opus',
        icon: Icons.directions_walk_rounded,
      ),
      SoundEffect(
        id: 'fire',
        name: 'Fire',
        fileName: 'fire.opus',
        icon: Icons.local_fire_department_rounded,
      ),
      SoundEffect(
        id: 'wind',
        name: 'Wind',
        fileName: 'wind.opus',
        icon: Icons.air_rounded,
      ),
      SoundEffect(
        id: 'bird',
        name: 'Birds',
        fileName: 'bird.opus',
        icon: Icons.flutter_dash_rounded,
      ),
    ];

    for (final effect in effects) {
      _effects[effect.id] = effect;
    }

    _isInitialized = true;
  }

  List<SoundEffect> getAllEffects() {
    return _effects.values.toList();
  }

  SoundEffect? getEffect(String id) {
    return _effects[id];
  }

  Future<void> setVolume(String id, double volume) async {
    final effect = _effects[id];
    if (effect == null) return;

    volume = volume.clamp(0.0, 1.0);
    final oldVolume = effect.volume;
    effect.volume = volume;

    _broadcastVolumes();

    effect.cancelDebounce();

    if (volume == 0.0) {
      await _stopEffect(id);
      return;
    }

    effect._debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      if (_isPaused) return;

      if (oldVolume == 0.0 && volume > 0.0) {
        await _playEffect(id, volume);
      } else if (effect.player != null && effect.player!.playing) {
        await effect.player!.setVolume(volume);
      } else if (effect.player != null && !effect.player!.playing) {
        await effect.player!.setVolume(volume);
        await effect.player!.play();
      } else {
        await _playEffect(id, volume);
      }
    });
  }

  Future<void> _playEffect(String id, double volume) async {
    final effect = _effects[id];
    if (effect == null) return;

    if (_isPaused) return;

    try {
      effect.isLoading = true;

      if (effect.player == null) {
        effect.player = AudioPlayer();

        final assetPath = 'assets/sounds/${effect.fileName}';

        await effect.player!.setAudioSource(
          AudioSource.asset(assetPath),
          preload: true,
        );

        await effect.player!.setLoopMode(LoopMode.one);
      }

      await effect.player!.setVolume(volume);

      if (_isPaused) {
        effect.isLoading = false;
        return;
      }

      if (!effect.player!.playing) {
        await effect.player!.play();
      }

      effect.isLoading = false;
    } catch (_) {
      effect.isLoading = false;
    }
  }

  Future<void> _stopEffect(String id) async {
    final effect = _effects[id];
    if (effect == null || effect.player == null) return;

    try {
      await effect.player!.stop();
      await effect.player!.dispose();
      effect.player = null;
    } catch (_) {}
  }

  Future<void> stopAll() async {
    _isPaused = false;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
    }

    for (final id in _effects.keys) {
      final effect = _effects[id];
      if (effect != null) {
        effect.volume = 0.0;
        await _stopEffect(id);
      }
    }
    _broadcastVolumes();
  }

  Future<void> pauseAll() async {
    bool hasPlayingEffects = false;
    for (final effect in _effects.values) {
      if (effect.player != null && effect.player!.playing) {
        hasPlayingEffects = true;
        break;
      }
    }

    if (!hasPlayingEffects) return;

    if (_isPaused) return;

    _isPaused = true;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
    }

    for (final id in _effects.keys) {
      final effect = _effects[id];
      if (effect?.player != null && effect!.player!.playing) {
        await effect.player!.pause();
      }
    }
  }

  Future<void> resumeAll() async {
    if (_isPaused) return;

    for (final id in _effects.keys) {
      final effect = _effects[id];
      if (effect != null && effect.volume > 0.0) {
        if (_isPaused) break;

        if (effect.player != null) {
          if (!effect.player!.playing) {
            try {
              await effect.player!.play();
            } catch (_) {
              if (!_isPaused) {
                await _playEffect(id, effect.volume);
              }
            }
          }
        } else {
          if (!_isPaused) {
            await _playEffect(id, effect.volume);
          }
        }
      }
    }
  }

  Future<void> clearPauseState() async {
    _isPaused = false;
  }

  void setSleepTimer(Duration duration, VoidCallback onComplete) {
    _sleepTimer?.cancel();

    _sleepTimer = Timer(duration, () async {
      await stopAll();
      onComplete();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  bool get hasSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;

  void _broadcastVolumes() {
    final volumes = <String, double>{};
    for (final entry in _effects.entries) {
      volumes[entry.key] = entry.value.volume;
    }
    _volumeController.add(volumes);
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();

    for (final effect in _effects.values) {
      effect.cancelDebounce();
    }

    for (final id in _effects.keys) {
      await _stopEffect(id);
    }
    _effects.clear();
    await _volumeController.close();
  }
}
