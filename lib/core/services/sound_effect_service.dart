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
  bool _shouldBePlaying = false;
  StreamSubscription? _playerStateSubscription;

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

  void cancelSubscription() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
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
  Timer? _healthCheckTimer;

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
    _startHealthCheck();
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    // Check every 1 second for more responsive recovery
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ensureEffectsPlaying();
    });
  }

  Future<void> _ensureEffectsPlaying() async {
    if (_isPaused) return;

    for (final effect in _effects.values) {
      if (effect.shouldBePlaying && !effect.isLoading) {
        final player = effect.player;
        // Check if player is null, not playing, or in bad state
        if (player == null) {
          await _playEffect(effect.id, effect.volume);
        } else {
          final state = player.processingState;
          final isPlaying = player.playing;

          // Restart if completed, idle, or not playing when it should be
          if (state == ProcessingState.completed ||
              state == ProcessingState.idle ||
              !isPlaying) {
            await _restartEffect(effect);
          }
        }
      }
    }
  }

  Future<void> _restartEffect(SoundEffect effect) async {
    if (_isPaused || !effect.shouldBePlaying) return;

    try {
      if (effect.player != null) {
        // Try to seek to start and play
        await effect.player!.seek(Duration.zero);
        if (!effect.player!.playing) {
          await effect.player!.play();
        }
      } else {
        await _playEffect(effect.id, effect.volume);
      }
    } catch (_) {
      // If restart fails, recreate player
      await _recreatePlayer(effect);
    }
  }

  Future<void> _recreatePlayer(SoundEffect effect) async {
    effect.cancelSubscription();
    try {
      await effect.player?.dispose();
    } catch (_) {}
    effect.player = null;

    if (effect.shouldBePlaying && !_isPaused) {
      await _playEffect(effect.id, effect.volume);
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
      } else if (effect.player != null) {
        await effect.player!.setVolume(volume);
        if (!effect.player!.playing) {
          await effect.player!.play();
        }
      } else {
        await _playEffect(id, volume);
      }
    });
  }

  Future<void> _playEffect(String id, double volume) async {
    final effect = _effects[id];
    if (effect == null || _isPaused) return;

    try {
      effect.isLoading = true;

      // Clean up existing player first
      if (effect.player != null) {
        effect.cancelSubscription();
        try {
          await effect.player!.dispose();
        } catch (_) {}
        effect.player = null;
      }

      // Create new player
      effect.player = AudioPlayer();
      final assetPath = 'assets/sounds/${effect.fileName}';

      // Use LoopingAudioSource for more reliable looping
      // count: 9999 effectively makes it infinite for practical purposes
      final audioSource = LoopingAudioSource(
        child: AudioSource.asset(assetPath),
        count: 9999,
      );

      await effect.player!.setAudioSource(audioSource, preload: true);
      await effect.player!.setVolume(volume);
      effect._shouldBePlaying = true;

      // Setup state listener for auto-recovery
      effect._playerStateSubscription = effect.player!.playerStateStream.listen(
        (state) {
          // If player stops unexpectedly while it should be playing
          if (effect.shouldBePlaying &&
              !_isPaused &&
              !effect.isLoading &&
              (state.processingState == ProcessingState.completed ||
                  state.processingState == ProcessingState.idle)) {
            // Schedule restart (don't await to avoid blocking)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (effect.shouldBePlaying && !_isPaused) {
                _restartEffect(effect);
              }
            });
          }
        },
        onError: (_) {
          // On error, schedule recreation
          if (effect.shouldBePlaying && !_isPaused) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _recreatePlayer(effect);
            });
          }
        },
      );

      if (!_isPaused) {
        await effect.player!.play();
      }

      effect.isLoading = false;
    } catch (_) {
      effect.isLoading = false;
      effect.cancelSubscription();
      try {
        await effect.player?.dispose();
      } catch (_) {}
      effect.player = null;
    }
  }

  Future<void> _stopEffect(String id) async {
    final effect = _effects[id];
    if (effect == null) return;

    effect._shouldBePlaying = false;
    effect.cancelSubscription();

    if (effect.player != null) {
      try {
        await effect.player!.stop();
        await effect.player!.dispose();
      } catch (_) {}
      effect.player = null;
    }
  }

  Future<void> stopAll() async {
    _isPaused = false;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
      effect._shouldBePlaying = false;
      effect.volume = 0.0;
    }

    final stopFutures = <Future>[];
    for (final id in _effects.keys) {
      stopFutures.add(_stopEffect(id));
    }
    await Future.wait(stopFutures);
    _broadcastVolumes();
  }

  Future<void> pauseAll() async {
    if (_isPaused) return;

    bool hasActiveEffects = _effects.values.any((e) => e.volume > 0);
    if (!hasActiveEffects) return;

    _isPaused = true;

    for (final effect in _effects.values) {
      effect.cancelDebounce();
    }

    final pauseFutures = <Future>[];
    for (final effect in _effects.values) {
      if (effect.player != null && effect.player!.playing) {
        pauseFutures.add(effect.player!.pause());
      }
    }
    await Future.wait(pauseFutures);
  }

  Future<void> resumeAll() async {
    if (!_isPaused) return;

    _isPaused = false;

    for (final effect in _effects.values) {
      if (effect.volume > 0) {
        effect._shouldBePlaying = true;
      }
    }

    final resumeFutures = <Future>[];
    for (final effect in _effects.values) {
      if (effect.volume > 0.0) {
        if (effect.player != null) {
          resumeFutures.add(_safeResume(effect));
        } else {
          resumeFutures.add(_playEffect(effect.id, effect.volume));
        }
      }
    }
    await Future.wait(resumeFutures);
  }

  Future<void> _safeResume(SoundEffect effect) async {
    try {
      if (effect.player != null && !effect.player!.playing) {
        await effect.player!.play();
      }
    } catch (_) {
      await _recreatePlayer(effect);
    }
  }

  Future<void> clearPauseState() async {
    // Reserved for future use
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
      effect.cancelSubscription();
      effect._shouldBePlaying = false;
    }

    final disposeFutures = <Future>[];
    for (final id in _effects.keys) {
      disposeFutures.add(_stopEffect(id));
    }
    await Future.wait(disposeFutures);

    _effects.clear();
    await _volumeController.close();
    await _sleepTimerController.close();
  }
}
