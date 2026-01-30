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
  bool _shouldBePlaying = false;

  SoundEffect({
    required this.id,
    required this.name,
    required this.fileName,
    required this.icon,
    this.volume = 0.0,
    this.isLoading = false,
  });

  bool get shouldBePlaying => _shouldBePlaying && volume > 0;
}

/// Sound Effect Service using just_audio for each effect
/// Each effect has its own player for independent volume control and mixing
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

  final _sleepTimerController = StreamController<Duration?>.broadcast();

  Stream<Map<String, double>> get volumeStream => _volumeController.stream;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;

  Future<void> initialize() async {
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
    effect._shouldBePlaying = volume > 0 && !_isPaused;

    _broadcastVolumes();

    if (volume == 0.0) {
      effect._shouldBePlaying = false;
      await _stopEffect(id);
      return;
    }

    if (oldVolume == 0.0 && volume > 0.0) {
      // Start playing
      await _playEffect(id, volume);
    } else if (effect.player != null) {
      // Just update volume
      await effect.player!.setVolume(volume);
    } else {
      // No player, start playing
      await _playEffect(id, volume);
    }
  }

  Future<void> _playEffect(String id, double volume) async {
    final effect = _effects[id];
    if (effect == null || _isPaused) return;

    try {
      effect.isLoading = true;

      // Create player if not exists
      if (effect.player == null) {
        effect.player = AudioPlayer();

        // Set up looping
        await effect.player!.setLoopMode(LoopMode.one);

        // Load asset
        final assetPath = 'assets/sounds/${effect.fileName}';
        await effect.player!.setAsset(assetPath);
      }

      effect._shouldBePlaying = true;

      if (!_isPaused) {
        await effect.player!.setVolume(volume);
        await effect.player!.play();
      }

      effect.isLoading = false;
    } catch (e) {
      effect.isLoading = false;
      effect.player?.dispose();
      effect.player = null;
    }
  }

  Future<void> _stopEffect(String id) async {
    final effect = _effects[id];
    if (effect == null) return;

    effect._shouldBePlaying = false;

    if (effect.player != null) {
      await effect.player!.stop();
      await effect.player!.dispose();
      effect.player = null;
    }
  }

  Future<void> stopAll() async {
    _isPaused = false;

    for (final effect in _effects.values) {
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

    // Pause all effects in parallel
    final pauseFutures = <Future>[];
    for (final effect in _effects.values) {
      if (effect.player != null && effect.volume > 0) {
        pauseFutures.add(effect.player!.pause());
      }
    }
    await Future.wait(pauseFutures);
  }

  Future<void> resumeAll() async {
    if (!_isPaused) return;

    _isPaused = false;

    // Collect all effects that need to be resumed
    final resumeFutures = <Future>[];

    for (final effect in _effects.values) {
      if (effect.volume > 0) {
        effect._shouldBePlaying = true;

        if (effect.player != null) {
          // Player exists, just play it
          resumeFutures.add(effect.player!.play());
        } else {
          // No player, need to create and play
          resumeFutures.add(_playEffect(effect.id, effect.volume));
        }
      }
    }

    // Wait for all to resume
    await Future.wait(resumeFutures);
  }

  void onAppPaused() {
    // Don't pause - let sound effects continue in background
    // They will play alongside main audio's foreground service
  }

  Future<void> onAppResumed() async {
    if (_isPaused) return;

    // Check and restart any effects that should be playing but stopped
    // (Android might have killed them due to resource constraints)
    final resumeFutures = <Future>[];

    for (final effect in _effects.values) {
      if (effect.volume > 0 && effect._shouldBePlaying) {
        if (effect.player != null) {
          final isPlaying = effect.player!.playing;
          if (!isPlaying) {
            // Player stopped unexpectedly, restart it
            resumeFutures.add(
              effect.player!
                  .seek(Duration.zero)
                  .then((_) => effect.player!.play()),
            );
          }
        } else {
          // No player exists, create and play
          resumeFutures.add(_playEffect(effect.id, effect.volume));
        }
      }
    }

    await Future.wait(resumeFutures);
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

    // Stop and dispose all players
    for (final effect in _effects.values) {
      effect._shouldBePlaying = false;
      if (effect.player != null) {
        await effect.player!.dispose();
        effect.player = null;
      }
    }

    _effects.clear();
    await _volumeController.close();
    await _sleepTimerController.close();
  }
}
