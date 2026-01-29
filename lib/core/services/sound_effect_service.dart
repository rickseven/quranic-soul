import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Sound Effect Model
class SoundEffect {
  final String id;
  final String name;
  final String fileName;
  final IconData icon;
  double volume;
  AudioSource? source;
  SoundHandle? handle;
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

/// Sound Effect Service using flutter_soloud for proper audio mixing
/// Sound effects run independently and can play alongside main audio
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
  bool _soloudInitialized = false;

  final _sleepTimerController = StreamController<Duration?>.broadcast();

  Stream<Map<String, double>> get volumeStream => _volumeController.stream;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;

  SoLoud get _soloud => SoLoud.instance;

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

    // Initialize SoLoud engine
    await _initSoLoud();
  }

  Future<void> _initSoLoud() async {
    if (_soloudInitialized) return;

    try {
      await _soloud.init();
      _soloudInitialized = true;
    } catch (e) {
      // SoLoud might already be initialized
      if (_soloud.isInitialized) {
        _soloudInitialized = true;
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
    } else if (effect.handle != null) {
      // Just update volume
      try {
        _soloud.setVolume(effect.handle!, volume);
      } catch (_) {
        // Handle might be invalid, restart
        await _playEffect(id, volume);
      }
    } else {
      // No handle, start playing
      await _playEffect(id, volume);
    }
  }

  Future<void> _playEffect(String id, double volume) async {
    final effect = _effects[id];
    if (effect == null || _isPaused) return;

    try {
      effect.isLoading = true;

      // Stop existing playback
      if (effect.handle != null) {
        try {
          await _soloud.stop(effect.handle!);
        } catch (_) {}
        effect.handle = null;
      }

      // Load source if not loaded
      if (effect.source == null) {
        final assetPath = 'assets/sounds/${effect.fileName}';

        // Load asset data
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer.asUint8List();

        effect.source = await _soloud.loadMem(effect.fileName, buffer);
      }

      effect._shouldBePlaying = true;

      if (!_isPaused && effect.source != null) {
        // Play with looping enabled
        effect.handle = await _soloud.play(
          effect.source!,
          volume: volume,
          looping: true,
          loopingStartAt: Duration.zero,
        );
      }

      effect.isLoading = false;
    } catch (e) {
      effect.isLoading = false;
      effect.source = null;
      effect.handle = null;
    }
  }

  Future<void> _stopEffect(String id) async {
    final effect = _effects[id];
    if (effect == null) return;

    effect._shouldBePlaying = false;

    if (effect.handle != null) {
      try {
        await _soloud.stop(effect.handle!);
      } catch (_) {}
      effect.handle = null;
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

    for (final effect in _effects.values) {
      if (effect.handle != null) {
        try {
          _soloud.setPause(effect.handle!, true);
        } catch (_) {}
      }
    }
  }

  Future<void> resumeAll() async {
    if (!_isPaused) return;

    _isPaused = false;

    for (final effect in _effects.values) {
      if (effect.volume > 0) {
        effect._shouldBePlaying = true;

        if (effect.handle != null) {
          try {
            // Check if handle is still valid
            final isValid = _soloud.getIsValidVoiceHandle(effect.handle!);
            if (isValid) {
              _soloud.setPause(effect.handle!, false);
            } else {
              // Handle invalid, restart
              await _playEffect(effect.id, effect.volume);
            }
          } catch (_) {
            // Restart on error
            await _playEffect(effect.id, effect.volume);
          }
        } else {
          // No handle, start playing
          await _playEffect(effect.id, effect.volume);
        }
      }
    }
  }

  void onAppPaused() {
    // SoLoud handles background audio automatically
  }

  Future<void> onAppResumed() async {
    if (_isPaused) return;

    // Check and restart any effects that should be playing
    for (final effect in _effects.values) {
      if (effect.volume > 0 && effect._shouldBePlaying) {
        if (effect.handle != null) {
          try {
            final isValid = _soloud.getIsValidVoiceHandle(effect.handle!);
            if (!isValid) {
              await _playEffect(effect.id, effect.volume);
            }
          } catch (_) {
            await _playEffect(effect.id, effect.volume);
          }
        } else {
          await _playEffect(effect.id, effect.volume);
        }
      }
    }
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

    // Stop all effects
    for (final effect in _effects.values) {
      effect._shouldBePlaying = false;
      if (effect.handle != null) {
        try {
          await _soloud.stop(effect.handle!);
        } catch (_) {}
      }
      if (effect.source != null) {
        try {
          await _soloud.disposeSource(effect.source!);
        } catch (_) {}
      }
    }

    _effects.clear();
    await _volumeController.close();
    await _sleepTimerController.close();

    // Don't deinit SoLoud as it might be used elsewhere
  }
}
