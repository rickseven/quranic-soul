import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/services/sound_effect_service.dart';
import '../../../../domain/entities/surah.dart';
import '../providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final Surah surah;

  const PlayerPage({super.key, required this.surah});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Surah _currentSurah;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<Surah?>? _surahSubscription;

  @override
  void initState() {
    super.initState();
    _currentSurah = widget.surah;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
  }

  void _initializePlayer() async {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    final audioService = ref.read(audioPlayerServiceProvider);

    await soundEffectService.initialize();
    audioService.setSoundEffectService(soundEffectService);

    _surahSubscription = audioService.currentSurahStream.listen((surah) {
      if (surah != null && mounted) setState(() => _currentSurah = surah);
    });

    if (audioService.currentSurah?.id != widget.surah.id) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(audioPlayerServiceProvider).loadAndPlay(_currentSurah);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load audio: $e';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _surahSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2D2D2D), const Color(0xFF121212)]
                : [const Color(0xFFF5F5F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, isDark),
              Expanded(child: _buildArtwork(context, isDark)),
              _buildTrackInfo(context, isDark),
              _buildProgressBar(context, isDark),
              _buildControls(context, isDark, playerState),
              _buildBottomActions(context, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
            color: isDark ? Colors.white : Colors.black,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'PLAYING FROM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quran Recitations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showOptionsSheet(context),
            color: isDark ? Colors.white : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, bool isDark) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StreamBuilder<bool>(
        stream: audioService.playingStream,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? false;
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Transform.rotate(
              angle: isPlaying ? _animationController.value * 2 * 3.14159 : 0,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: 1.2,
                            child: Image.asset(
                              'assets/images/player_artwork.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  CircularProgressIndicator(
                    color: isDark ? Colors.white : Colors.black,
                    strokeWidth: 2,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSurah.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSurah.reciter,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _currentSurah.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _currentSurah.isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
                onPressed: () async {
                  // Use playerProvider to sync state across all pages
                  ref
                      .read(playerProvider.notifier)
                      .setCurrentSurah(_currentSurah);
                  await ref.read(playerProvider.notifier).toggleFavorite();

                  // Update local state
                  final updated = await ref
                      .read(surahRepositoryProvider)
                      .getSurahById(_currentSurah.id);
                  if (updated != null && mounted) {
                    setState(() => _currentSurah = updated);
                  }
                },
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, bool isDark) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: StreamBuilder<Duration>(
        stream: audioService.positionStream,
        builder: (context, positionSnapshot) {
          final position = positionSnapshot.data ?? Duration.zero;
          final duration =
              audioService.duration ??
              Duration(seconds: _currentSurah.durationSeconds.round());
          final progress = duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;

          return Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged:
                      (_) {}, // Required but we use onChangeEnd for actual seek
                  onChangeEnd: (value) => audioService.seek(
                    Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    bool isDark,
    PlayerState playerState,
  ) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => ref.read(playerProvider.notifier).toggleShuffle(),
            child: Icon(
              Icons.shuffle_rounded,
              size: 24,
              color: playerState.isShuffle
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          GestureDetector(
            onTap: () => audioService.previous(),
            child: Icon(
              Icons.skip_previous_rounded,
              size: 40,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          _buildPlayPauseButton(context),
          GestureDetector(
            onTap: () => audioService.next(),
            child: Icon(
              Icons.skip_next_rounded,
              size: 40,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(playerProvider.notifier).toggleRepeat(),
            child: Icon(
              Icons.repeat_rounded,
              size: 24,
              color: playerState.isRepeat
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<ja.PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final processingState = state?.processingState;
        final playing = state?.playing ?? false;

        Widget icon;
        VoidCallback? onPressed;

        if (processingState == ja.ProcessingState.loading ||
            processingState == ja.ProcessingState.buffering) {
          icon = const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 3,
            ),
          );
          onPressed = null;
        } else if (playing) {
          icon = const Icon(Icons.pause_rounded, color: Colors.black, size: 36);
          onPressed = audioService.pause;
        } else {
          icon = const Icon(
            Icons.play_arrow_rounded,
            color: Colors.black,
            size: 36,
          );
          onPressed = audioService.play;
        }

        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isDark) {
    final soundEffectService = ref.watch(soundEffectServiceProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sleep Timer with realtime stream
          StreamBuilder<Duration?>(
            stream: soundEffectService.sleepTimerStream,
            builder: (context, snapshot) {
              final hasSleepTimer = soundEffectService.hasSleepTimer;
              return _buildBottomButton(
                icon: Icons.bedtime_rounded,
                label: 'Sleep Timer',
                isDark: isDark,
                isActive: hasSleepTimer,
                activeColor: primaryColor,
                onTap: () => _showSleepTimerSheet(context),
              );
            },
          ),
          // Sound Effect with realtime stream
          StreamBuilder<Map<String, double>>(
            stream: soundEffectService.volumeStream,
            builder: (context, snapshot) {
              // Check if any effect has volume > 0
              final hasActiveEffect = soundEffectService.getAllEffects().any(
                (e) => e.volume > 0,
              );
              return _buildBottomButton(
                icon: Icons.graphic_eq_rounded,
                label: 'Sound Effect',
                isDark: isDark,
                isActive: hasActiveEffect,
                activeColor: primaryColor,
                onTap: () => _showSoundEffectSheet(context),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive
                ? activeColor
                : (isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive
                  ? activeColor
                  : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showOptionsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildOptionsContent(context, isDark),
    );
  }

  Widget _buildOptionsContent(BuildContext context, bool isDark) {
    final downloadService = ref.read(downloadServiceProvider);
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final isDownloaded = downloadService.isDownloaded(_currentSurah.id);
    final isPro = subscriptionService.isPro;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _buildOptionItem(
            Icons.share_rounded,
            'Share',
            isDark,
            () => _shareSurah(),
          ),
          _buildOptionItem(
            isDownloaded ? Icons.delete_rounded : Icons.download_rounded,
            isDownloaded ? 'Delete download' : 'Download',
            isDark,
            () => _handleDownload(context, isDownloaded, isPro),
            trailing: !isPro && !isDownloaded
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : null,
          ),
          _buildOptionItem(
            Icons.info_outline_rounded,
            'Surah info',
            isDark,
            () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${_currentSurah.name}\n${_currentSurah.reciter}\nDuration: ${_currentSurah.duration}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    bool isDownloaded,
    bool isPro,
  ) async {
    if (!isPro && !isDownloaded) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
      );
      return;
    }

    final downloadService = ref.read(downloadServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (isDownloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete download?'),
          content: Text(
            'Are you sure you want to delete ${_currentSurah.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final success = await downloadService.deleteSurah(_currentSurah.id);
        final updated = await ref
            .read(surahRepositoryProvider)
            .getSurahById(_currentSurah.id);
        if (!mounted) return;

        // Sync library provider
        ref.read(libraryProvider.notifier).loadData();

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Download deleted' : 'Failed to delete download',
            ),
          ),
        );
        if (updated != null) setState(() => _currentSurah = updated);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Downloading ${_currentSurah.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      final success = await downloadService.downloadSurah(_currentSurah);
      final updated = await ref
          .read(surahRepositoryProvider)
          .getSurahById(_currentSurah.id);
      if (!mounted) return;

      // Sync library provider after download
      ref.read(libraryProvider.notifier).loadData();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Download completed!'
                : 'Download failed. Please try again.',
          ),
        ),
      );
      if (updated != null) setState(() => _currentSurah = updated);
    }
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      title: Text(
        label,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSleepTimerContent(context, isDark),
    );
  }

  Widget _buildSleepTimerContent(BuildContext context, bool isDark) {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    final hasSleepTimer = soundEffectService.hasSleepTimer;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final times = [
      {'label': '5 min', 'duration': const Duration(minutes: 5)},
      {'label': '10 min', 'duration': const Duration(minutes: 10)},
      {'label': '15 min', 'duration': const Duration(minutes: 15)},
      {'label': '30 min', 'duration': const Duration(minutes: 30)},
      {'label': '45 min', 'duration': const Duration(minutes: 45)},
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sleep Timer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          // Show active timer status
          if (hasSleepTimer) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Timer Active',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SleepTimerCountdown(
                    soundEffectService: soundEffectService,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      soundEffectService.cancelSleepTimer();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sleep timer cancelled'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Cancel Timer',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Or set a new timer:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: times
                .map(
                  (t) => _buildTimerChip(
                    t['label'] as String,
                    t['duration'] as Duration,
                    isDark,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimerChip(String label, Duration duration, bool isDark) {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    final audioService = ref.read(audioPlayerServiceProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Check if this duration is currently active
    final currentDuration = soundEffectService.sleepTimerDuration;
    final isActive =
        currentDuration == duration && soundEffectService.hasSleepTimer;

    return GestureDetector(
      onTap: () {
        soundEffectService.setSleepTimer(duration, () {
          audioService.pause();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sleep timer finished'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sleep timer set for $label'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.2)
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: primaryColor, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? primaryColor
                : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showSoundEffectSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSoundEffectContent(context, isDark),
    );
  }

  Widget _buildSoundEffectContent(BuildContext context, bool isDark) {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    final effects = soundEffectService.getAllEffects();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Background sounds volume',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: StreamBuilder<Map<String, double>>(
              stream: soundEffectService.volumeStream,
              initialData: {for (var e in effects) e.id: e.volume},
              builder: (context, snapshot) => ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: effects.length,
                itemBuilder: (context, index) {
                  final effect = effects[index];
                  final volume = snapshot.data?[effect.id] ?? effect.volume;
                  return _buildSoundEffectSlider(effect, volume, isDark);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSoundEffectSlider(
    SoundEffect effect,
    double volume,
    bool isDark,
  ) {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              effect.icon,
              size: 24,
              color: volume > 0
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effect.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    thumbColor: volume > 0
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (value) =>
                        soundEffectService.setVolume(effect.id, value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSurah() async {
    final shareText =
        '''🎧 Listening to ${_currentSurah.name}

Recited by ${_currentSurah.reciter}

Download Quranic Soul app for soothing Quran recitations:
https://play.google.com/store/apps/details?id=com.rickseven.quranicsoul''';

    await Share.share(
      shareText,
      subject: 'Quranic Soul - ${_currentSurah.name}',
    );
  }
}

/// Widget for realtime sleep timer countdown
class _SleepTimerCountdown extends StatefulWidget {
  final SoundEffectService soundEffectService;
  final bool isDark;

  const _SleepTimerCountdown({
    required this.soundEffectService,
    required this.isDark,
  });

  @override
  State<_SleepTimerCountdown> createState() => _SleepTimerCountdownState();
}

class _SleepTimerCountdownState extends State<_SleepTimerCountdown> {
  Timer? _updateTimer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.soundEffectService.sleepTimerRemaining;
    // Update every second
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = widget.soundEffectService.sleepTimerRemaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == null) return const SizedBox.shrink();

    return Text(
      _formatDuration(_remaining!),
      style: TextStyle(
        color: widget.isDark ? Colors.white70 : Colors.black87,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
