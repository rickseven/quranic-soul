import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/surah.dart';
import 'sound_effect_service.dart';
import 'subscription_service.dart';
import 'download_service.dart';

// Forward declaration for ad tracking callback
typedef AdTrackingCallback = Future<void> Function();

/// Singleton Audio Player Service with Media Notification (Spotify-like)
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  static _QuranicAudioHandler? _audioHandler;
  bool _isInitialized = false;

  List<Surah> _playlist = [];
  int _currentIndex = -1;
  Surah? _currentSurah;

  final _currentSurahController = StreamController<Surah?>.broadcast();

  // Sound effect service integration
  SoundEffectService? _soundEffectService;

  // Download service integration
  final DownloadService _downloadService = DownloadService();

  // Ad tracking callback
  AdTrackingCallback? _adTrackingCallback;
  StreamSubscription<bool>? _playingStreamSubscription;
  Timer? _soundEffectSyncDebounce;
  bool _listenerSetup = false; // Track if listener is already setup

  // Initialize early - call this from main.dart
  static Future<void> initializeService() async {
    if (_audioHandler != null) return;

    try {
      _audioHandler = await AudioService.init<_QuranicAudioHandler>(
        builder: () => _QuranicAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.rickseven.quranicsoul.audio',
          androidNotificationChannelName: 'Quranic Soul',
          androidNotificationChannelDescription: 'Audio playback controls',
          androidNotificationOngoing: false,
          // Small icon for status bar (must be monochrome)
          androidNotificationIcon: 'drawable/notification_icon',
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,
          // Gold color for notification accent
          notificationColor: const Color(0xFFD4AF37),
          androidNotificationClickStartsActivity: true,
        ),
      );
    } catch (e) {
      if (!e.toString().contains('_cacheManager')) {
        rethrow;
      }
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize audio session
      await _initAudioSession();

      // Ensure audio handler is ready
      if (_audioHandler == null) {
        await initializeService();
        if (_audioHandler == null) return;
      }

      // Set service reference in handler
      _audioHandler?._setService(this);

      // Setup player listeners
      _setupPlayerListeners();

      _isInitialized = true;
    } catch (_) {
      // Silently handle initialization errors
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.longFormAudio,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      // Handle interruptions (calls, notifications)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioHandler?.player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _audioHandler?.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioHandler?.player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Handle headphones unplugged
      session.becomingNoisyEventStream.listen((_) {
        _audioHandler?.pause();
      });
    } catch (_) {
      // Silently handle audio session errors
    }
  }

  void _setupPlayerListeners() {
    final player = _audioHandler?.player;
    if (player == null) return;

    // Auto-advance to next track when current finishes
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (hasNext) {
          next();
        } else {
          player.seek(Duration.zero);
          player.pause();
        }
      }
    });

    // Handle player errors
    player.playbackEventStream.listen(
      null,
      onError: (Object e, StackTrace st) {
        if (_currentSurah != null) {
          Future.delayed(const Duration(seconds: 1), () {
            loadAndPlay(_currentSurah!);
          });
        }
      },
    );

    // Setup sound effect sync if service is already connected
    if (_soundEffectService != null) {
      _setupSoundEffectSync();
    }
  }

  // Getters
  AudioPlayer? get player => _audioHandler?.player;
  Surah? get currentSurah => _currentSurah;
  List<Surah> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Stream<Duration> get positionStream =>
      _audioHandler?.player.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream =>
      _audioHandler?.player.durationStream ?? const Stream.empty();
  Stream<PlayerState> get playerStateStream =>
      _audioHandler?.player.playerStateStream ?? const Stream.empty();
  Stream<bool> get playingStream =>
      _audioHandler?.player.playingStream ?? const Stream.empty();
  Stream<Surah?> get currentSurahStream => _currentSurahController.stream;

  bool get isPlaying => _audioHandler?.player.playing ?? false;
  Duration get position => _audioHandler?.player.position ?? Duration.zero;
  Duration? get duration => _audioHandler?.player.duration;

  void setPlaylist(List<Surah> surahs, {bool updateCurrentIndex = true}) {
    _playlist = surahs;

    // Update currentIndex to match current surah position in new playlist
    if (updateCurrentIndex && _currentSurah != null) {
      final newIndex = _playlist.indexWhere((s) => s.id == _currentSurah!.id);
      if (newIndex != -1) {
        _currentIndex = newIndex;
      }
    }
  }

  Future<void> loadAndPlay(Surah surah) async {
    await _initialize();

    final index = _playlist.indexWhere((s) => s.id == surah.id);
    if (index != -1) {
      _currentIndex = index;
    }

    _currentSurah = surah;
    _currentSurahController.add(surah);

    // Get audio source (local file if downloaded, otherwise stream)
    final audioUrl = await _downloadService.getAudioSource(surah);

    try {
      // Create media item for notification
      final mediaItem = MediaItem(
        id: surah.id.toString(),
        title: surah.name,
        artist: surah.reciter,
        duration: Duration(seconds: surah.durationSeconds.round()),
        // artUri removed - causes error with android.resource scheme
        // Notification will use default app icon
        playable: true,
      );

      // Load and play via audio handler
      await _audioHandler?.loadAndPlayUrl(mediaItem, audioUrl);

      // Track ad (fire and forget)
      _adTrackingCallback?.call();

      // Sound effects will be resumed automatically by playingStream listener
    } catch (e) {
      // Reset error state to prevent issues with next track
      try {
        await _audioHandler?.player.stop();
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  // Sound effect service integration
  void setSoundEffectService(SoundEffectService service) {
    _soundEffectService = service;

    // Only setup listener once
    if (!_listenerSetup) {
      _setupSoundEffectSync();
    }
  }

  // Ad tracking callback integration
  void setAdTrackingCallback(AdTrackingCallback callback) {
    _adTrackingCallback = callback;
  }

  void _setupSoundEffectSync() {
    final player = _audioHandler?.player;
    if (player == null || _soundEffectService == null) return;

    // Prevent multiple setup
    if (_listenerSetup) return;

    _listenerSetup = true;

    // Cancel previous subscription just in case
    _playingStreamSubscription?.cancel();
    _soundEffectSyncDebounce?.cancel();

    // Sync sound effects with player state changes
    _playingStreamSubscription = player.playingStream.distinct().listen((
      playing,
    ) {
      // Cancel previous debounce timer
      _soundEffectSyncDebounce?.cancel();

      // Debounce to prevent rapid state changes
      _soundEffectSyncDebounce = Timer(
        const Duration(milliseconds: 100),
        () async {
          if (playing) {
            await _soundEffectService?.resumeAll();
          } else {
            await _soundEffectService?.pauseAll();
          }
        },
      );
    });
  }

  Future<void> playAtIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      await loadAndPlay(_playlist[index]);
    }
  }

  Future<void> play() async {
    await _initialize();

    if (_currentSurah == null && _playlist.isNotEmpty) {
      await loadAndPlay(_playlist[0]);
    } else {
      await _audioHandler?.play();
      // Sound effects will be resumed automatically by playingStream listener
    }
  }

  Future<void> pause() async {
    await _audioHandler?.pause();
    // Sound effects will be paused automatically by playingStream listener
  }

  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentSurah = null;
    _currentIndex = -1;
    _currentSurahController.add(null);
    // Stop all sound effects when main audio stops
    await _soundEffectService?.stopAll();
  }

  Future<void> next() async {
    if (hasNext) {
      _currentIndex++;
      await loadAndPlay(_playlist[_currentIndex]);
    }
  }

  Future<void> previous() async {
    final player = _audioHandler?.player;
    if (player == null) return;

    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
    } else if (hasPrevious) {
      _currentIndex--;
      await loadAndPlay(_playlist[_currentIndex]);
    } else {
      await player.seek(Duration.zero);
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _audioHandler?.setSpeed(speed);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _audioHandler?.player.setLoopMode(mode);
  }

  void dispose() {
    _soundEffectSyncDebounce?.cancel();
    _playingStreamSubscription?.cancel();
    _listenerSetup = false;
    _currentSurahController.close();
  }
}

/// Audio Handler for background playback and media notification controls
class _QuranicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayerService? _service;

  AudioPlayer get player => _player;

  _QuranicAudioHandler() {
    _init();
  }

  void _setService(AudioPlayerService service) {
    _service = service;
  }

  void _init() {
    // Broadcast initial state
    _broadcastState();

    // Listen to player state changes
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e, StackTrace st) {
        // Silently handle playback errors
      },
    );

    // Listen to playing state
    _player.playingStream.listen((_) => _broadcastState());

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  void _broadcastState() {
    final playing = _player.playing;
    final processingState = _player.processingState;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _service?.currentIndex ?? 0,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> loadAndPlayUrl(MediaItem item, String url) async {
    try {
      // Stop current playback and clear any error state
      try {
        await _player.stop();
      } catch (_) {
        // Ignore stop errors
      }

      // Update media item for notification
      mediaItem.add(item);

      // Load audio source - check if it's a local file or URL
      AudioSource audioSource;

      // Check if it's a local file path (starts with / or contains :\ for Windows)
      final isLocalFile =
          url.startsWith('/') ||
          url.startsWith('file://') ||
          url.contains(':\\') ||
          url.contains('Documents/surahs/');

      if (isLocalFile) {
        // Local file path - remove file:// prefix if present
        final filePath = url.replaceFirst('file://', '');
        audioSource = AudioSource.file(filePath, tag: item);
      } else {
        // Remote URL - add timeout for offline detection
        audioSource = LockCachingAudioSource(Uri.parse(url), tag: item);
      }

      // Set audio source with timeout to detect offline mode faster
      await _player
          .setAudioSource(audioSource, preload: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Audio loading timeout - check internet connection',
              );
            },
          );

      await _player.play();
    } catch (e) {
      // Clean up on error - stop player and clear audio source
      try {
        await _player.stop();
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    // Check if user is PRO when app is in background
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      // For non-PRO users, only allow play if app is in foreground
      // This prevents playing from notification when app is minimized
      final isAppInForeground = await _isAppInForeground();
      if (!isAppInForeground) return;
    }

    await _player.play();
    // Sound effects will be resumed automatically by playingStream listener
  }

  Future<bool> _isAppInForeground() async {
    // Use WidgetsBinding to check app lifecycle state
    final binding = WidgetsBinding.instance;
    return binding.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    // Sound effects will be paused automatically by playingStream listener
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    // Stop sound effects when stopping from notification
    await _service?._soundEffectService?.stopAll();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    // Check if user is PRO when app is in background
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final isAppInForeground = await _isAppInForeground();
      if (!isAppInForeground) return;
    }
    await _service?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    // Check if user is PRO when app is in background
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final isAppInForeground = await _isAppInForeground();
      if (!isAppInForeground) return;
    }
    await _service?.previous();
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 10);
    await _player.seek(newPosition);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await _player.seek(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  @override
  Future<void> onTaskRemoved() async {
    // Keep playing when app is swiped away only for PRO users
    final isPro = SubscriptionService().isPro;
    if (!_player.playing || !isPro) {
      await stop();
    }
  }
}
