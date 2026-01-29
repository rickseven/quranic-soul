import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/surah.dart';
import 'sound_effect_service.dart';
import 'subscription_service.dart';
import 'download_service.dart';

typedef AdTrackingCallback = Future<void> Function();

/// Singleton Audio Player Service with Media Notification
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

  SoundEffectService? _soundEffectService;
  final DownloadService _downloadService = DownloadService();

  AdTrackingCallback? _adTrackingCallback;
  StreamSubscription<bool>? _playingStreamSubscription;
  Timer? _soundEffectSyncDebounce;
  bool _listenerSetup = false;

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
          androidNotificationIcon: 'drawable/notification_icon',
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,
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
      await _initAudioSession();

      if (_audioHandler == null) {
        await initializeService();
        if (_audioHandler == null) return;
      }

      _audioHandler?._setService(this);
      _setupPlayerListeners();

      _isInitialized = true;
    } catch (_) {}
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

      session.becomingNoisyEventStream.listen((_) {
        _audioHandler?.pause();
      });
    } catch (_) {}
  }

  void _setupPlayerListeners() {
    final player = _audioHandler?.player;
    if (player == null) return;

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

    if (_soundEffectService != null) {
      _setupSoundEffectSync();
    }
  }

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

    final audioUrl = await _downloadService.getAudioSource(surah);

    try {
      final mediaItem = MediaItem(
        id: surah.id.toString(),
        title: surah.name,
        artist: surah.reciter,
        duration: Duration(seconds: surah.durationSeconds.round()),
        playable: true,
      );

      await _audioHandler?.loadAndPlayUrl(mediaItem, audioUrl);
      _adTrackingCallback?.call();
    } catch (e) {
      try {
        await _audioHandler?.player.stop();
      } catch (_) {}
      rethrow;
    }
  }

  void setSoundEffectService(SoundEffectService service) {
    _soundEffectService = service;

    if (!_listenerSetup) {
      _setupSoundEffectSync();
    }
  }

  void setAdTrackingCallback(AdTrackingCallback callback) {
    _adTrackingCallback = callback;
  }

  void _setupSoundEffectSync() {
    final player = _audioHandler?.player;
    if (player == null || _soundEffectService == null) return;

    if (_listenerSetup) return;

    _listenerSetup = true;

    _playingStreamSubscription?.cancel();
    _soundEffectSyncDebounce?.cancel();

    _playingStreamSubscription = player.playingStream.distinct().listen((
      playing,
    ) {
      _soundEffectSyncDebounce?.cancel();

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
    }
  }

  Future<void> pause() async {
    await _audioHandler?.pause();
  }

  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentSurah = null;
    _currentIndex = -1;
    _currentSurahController.add(null);
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
    _broadcastState();

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e, StackTrace st) {},
    );

    _player.playingStream.listen((_) => _broadcastState());

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
      try {
        await _player.stop();
      } catch (_) {}

      mediaItem.add(item);

      AudioSource audioSource;

      final isLocalFile =
          url.startsWith('/') ||
          url.startsWith('file://') ||
          url.contains(':\\') ||
          url.contains('Documents/surahs/');

      if (isLocalFile) {
        final filePath = url.replaceFirst('file://', '');
        audioSource = AudioSource.file(filePath, tag: item);
      } else {
        audioSource = LockCachingAudioSource(Uri.parse(url), tag: item);
      }

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
      try {
        await _player.stop();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final isAppInForeground = await _isAppInForeground();
      if (!isAppInForeground) return;
    }

    await _player.play();
  }

  Future<bool> _isAppInForeground() async {
    final binding = WidgetsBinding.instance;
    return binding.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _service?._soundEffectService?.stopAll();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final isAppInForeground = await _isAppInForeground();
      if (!isAppInForeground) return;
    }
    await _service?.next();
  }

  @override
  Future<void> skipToPrevious() async {
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
    final isPro = SubscriptionService().isPro;
    if (!_player.playing || !isPro) {
      await stop();
    }
  }
}
