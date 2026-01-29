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
  bool _shouldBePlaying = false; // Track intended state

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

  bool get shouldBePlaying => _shouldBePlaying && volume > 0;
}

/// Singleton Sound Effect Service
class SoundEffectService {
  static final SoundEffectService _instance = SoundEffectService._internal();
  factory SoundEffectService() => _instance;
  SoundEffectService._internal();

  final Map<String, SoundEffect> _effects = {};
  final _volumeController = StreamController<Map<String, double>>.broadcast();
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  DateTime? _sleepTimerStartTime;
  bool _isPaused = false;
  bool _isInitialized = false;
  Timer? _healthCheckTimer; // Periodic check to ensure effects are playing

  final _sleepTimerController = StreamController<Duration?>.broadcast();

  Stream<Map<String, double>> get volumeStream => _volumeController.stream;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;

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

    // Start health check timer to ensure effects stay in sync
    _startHealthCheck();
  }

  /// Periodic health check to ensure sound effects are playing when they should be
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _ensureEffectsPlaying();
    });
  }

  /// Ensure all effects that should be playing are actually playing
  Future<void> _ensureEffectsPlaying() async {
    if (_isPaused) return;

    for (final effect in _effects.values) {
      if (effect.shouldBePlaying) {
        // Effect should be playing but isn't
        if (effect.player == null || !effect.player!.playing) {
          await _playEffect(effect.id, effect.volume);
        }
      }
    }
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

    // Update intended playing state
    effect._shouldBePlaying = volume > 0 && !_isPaused;

    _broadcastVolumes();

    effect.cancelDebounce();

    if (volume == 0.0) {
      effect._shouldBePlaying = false;
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

        // Listen for playback completion/errors to auto-restart
        effect.player!.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed ||
              state.processingState == ProcessingState.idle) {
            // If effect should be playing but stopped, restart it
            if (effect.shouldBePlaying && !_isPaused) {
              _playEffect(id, effect.volume);
            }
          }
        });
      }

      await effect.player!.setVolume(volume);
      effect._shouldBePlaying = true;

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
      // On error, try to recreate player on next attempt
      effect.player?.dispose();
      effect.player = null;
    }
  }

  Future<void> _stopEffect(String id) async {
    final effect = _effects[id];
    if (effect == null || effect.player == null) return;

    effect._shouldBePlaying = false;

    try {
      await effect.player!.stop();
      await effect.player!.dispose();
      effect.player = null;
    } catch (_) {
      effect.player = null;
    }
  }

  Future<void> stopAll() async {
    _isPaused = false;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
      effect._shouldBePlaying = false;
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
    if (_isPaused) return;

    bool hasActiveEffects = false;
    for (final effect in _effects.values) {
      if (effect.volume > 0) {
        hasActiveEffects = true;
        break;
      }
    }

    if (!hasActiveEffects) return;

    _isPaused = true;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
    }

    // Pause all effects concurrently
    final pauseFutures = <Future>[];
    for (final effect in _effects.values) {
      if (effect.player != null && effect.player!.playing) {
        pauseFutures.add(effect.player!.pause());
      }
    }
    await Future.wait(pauseFutures);
  }

  Future<void> resumeAll() async {
    // Only resume if we were paused
    if (!_isPaused) return;

    _isPaused = false;

    // Update shouldBePlaying state for all effects with volume > 0
    for (final effect in _effects.values) {
      if (effect.volume > 0) {
        effect._shouldBePlaying = true;
      }
    }

    // Resume all effects concurrently
    final resumeFutures = <Future>[];
    for (final id in _effects.keys) {
      final effect = _effects[id];
      if (effect != null && effect.volume > 0.0) {
        if (effect.player != null) {
          if (!effect.player!.playing) {
            resumeFutures.add(_resumeEffect(effect));
          }
        } else {
          resumeFutures.add(_playEffect(id, effect.volume));
        }
      }
    }
    await Future.wait(resumeFutures);
  }

  Future<void> _resumeEffect(SoundEffect effect) async {
    try {
      await effect.player!.play();
    } catch (_) {
      // If play fails, try to recreate the player
      await _playEffect(effect.id, effect.volume);
    }
  }

  Future<void> clearPauseState() async {
    // This is called before resumeAll to ensure effects can be resumed
    // Don't clear here - let resumeAll handle it
  }

  void setSleepTimer(Duration duration, VoidCallback onComplete) {
    _sleepTimer?.cancel();

    _sleepTimerDuration = duration;
    _sleepTimerStartTime = DateTime.now();
    _sleepTimerController.add(duration);

    _sleepTimer = Timer(duration, () async {
      await stopAll();
      _sleepTimerDuration = null;
      _sleepTimerStartTime = null;
      _sleepTimerController.add(null);
      onComplete();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDuration = null;
    _sleepTimerStartTime = null;
    _sleepTimerController.add(null);
  }

  bool get hasSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;

  Duration? get sleepTimerDuration => _sleepTimerDuration;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerStartTime == null || _sleepTimerDuration == null) {
      return null;
    }
    final elapsed = DateTime.now().difference(_sleepTimerStartTime!);
    final remaining = _sleepTimerDuration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _broadcastVolumes() {
    final volumes = <String, double>{};
    for (final entry in _effects.entries) {
      volumes[entry.key] = entry.value.volume;
    }
    _volumeController.add(volumes);
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    _healthCheckTimer?.cancel();

    for (final effect in _effects.values) {
      effect.cancelDebounce();
      effect._shouldBePlaying = false;
    }

    for (final id in _effects.keys) {
      await _stopEffect(id);
    }
    _effects.clear();
    await _volumeController.close();
    await _sleepTimerController.close();
  }
}
