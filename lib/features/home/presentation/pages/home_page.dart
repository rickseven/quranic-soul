import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../../../core/providers/service_providers.dart';
import '../../../../domain/entities/surah.dart';
import '../providers/home_provider.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Static flag to track if popup has been shown this session
  static bool _hasShownPremiumPopup = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _showPremiumPopupIfNeeded() {
    if (_hasShownPremiumPopup) return;
    if (!mounted) return;

    final isPro = ref.read(isProProvider);
    if (!isPro) {
      _hasShownPremiumPopup = true;
      _showPremiumActivationDialog();
    }
  }

  void _showPremiumActivationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Go PRO',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              // Simple description
              Text(
                'Enjoy ad-free listening, background play, and offline downloads.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Activate Premium button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Activate Premium',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Maybe later button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeServices() async {
    final soundEffectService = ref.read(soundEffectServiceProvider);
    final audioService = ref.read(audioPlayerServiceProvider);
    final adService = ref.read(adServiceProvider);

    await soundEffectService.initialize();
    audioService.setSoundEffectService(soundEffectService);
    audioService.setAdTrackingCallback(() async {
      await adService.onSurahPlayed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (homeState.isLoading) {
      return _buildLoadingState(theme, isDark);
    }

    if (homeState.error != null) {
      return _buildErrorState(homeState.error!, isDark);
    }

    // Show premium popup after data is loaded (subscription status is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPremiumPopupIfNeeded();
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(homeProvider.notifier).loadSurahs(showLoading: false),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, isDark)),
              SliverToBoxAdapter(
                child: _buildNowPlaying(context, isDark, homeState),
              ),
              SliverToBoxAdapter(child: _buildSectionTitle(context, 'For You')),
              SliverToBoxAdapter(
                child: _buildHorizontalList(context, isDark, homeState),
              ),
              SliverToBoxAdapter(
                child: _buildSectionTitle(context, 'All Surahs'),
              ),
              _buildSurahGrid(context, isDark, homeState),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading Surahs...',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load surahs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(homeProvider.notifier).loadSurahs(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    // Watch the pro status listener to keep it active
    ref.watch(proStatusListenerProvider);
    // Get the current PRO status
    final isPro = ref.watch(isProProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalamu\'alaikum',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quranic Soul',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPro
                      ? [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ]
                      : [
                          isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFE0E0E0),
                          isDark
                              ? const Color(0xFF222222)
                              : const Color(0xFFD0D0D0),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isPro
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPro)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.black,
                      size: 14,
                    ),
                  if (isPro) const SizedBox(width: 4),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPro
                          ? Colors.black
                          : (isDark ? Colors.white70 : Colors.black54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(
    BuildContext context,
    bool isDark,
    HomeState homeState,
  ) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Surah?>(
      stream: audioService.currentSurahStream,
      initialData: audioService.currentSurah,
      builder: (context, snapshot) {
        final currentSurah = snapshot.data ?? audioService.currentSurah;
        final surah =
            currentSurah ??
            (homeState.recommendedSurahs.isNotEmpty
                ? homeState.recommendedSurahs[0]
                : null);

        if (surah == null) return const SizedBox.shrink();

        final isCurrentlyPlaying = currentSurah != null;

        return GestureDetector(
          onTap: () => _navigateToPlayer(context, surah),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.95),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentlyPlaying ? 'NOW PLAYING' : 'START LISTENING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        surah.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surah.reciter,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildPreviousButton(),
                          const SizedBox(width: 8),
                          _buildMainPlayButton(surah),
                          const SizedBox(width: 8),
                          _buildNextButton(),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildArtwork(isCurrentlyPlaying),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviousButton() {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final canGoPrevious =
        audioService.hasPrevious || audioService.currentSurah != null;
    return GestureDetector(
      onTap: canGoPrevious ? () => audioService.previous() : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: canGoPrevious ? 0.15 : 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.skip_previous_rounded,
          color: canGoPrevious ? Colors.black : Colors.black38,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildMainPlayButton(Surah surah) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<ja.PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final isPlaying = playerState?.playing ?? false;
        final isCurrentSurah = audioService.currentSurah?.id == surah.id;

        Widget icon;
        VoidCallback? onPressed;

        if (isCurrentSurah &&
            (processingState == ja.ProcessingState.loading ||
                processingState == ja.ProcessingState.buffering)) {
          icon = const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          );
          onPressed = null;
        } else if (isCurrentSurah && isPlaying) {
          icon = const Icon(Icons.pause_rounded, color: Colors.white, size: 32);
          onPressed = () => audioService.pause();
        } else {
          icon = const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          );
          onPressed = () => audioService.loadAndPlay(surah);
        }

        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        );
      },
    );
  }

  Widget _buildNextButton() {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final canGoNext = audioService.hasNext;
    return GestureDetector(
      onTap: canGoNext ? () => audioService.next() : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: canGoNext ? 0.15 : 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.skip_next_rounded,
          color: canGoNext ? Colors.black : Colors.black38,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildArtwork(bool isPlaying) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/surah_icon.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
          if (isPlaying)
            StreamBuilder<bool>(
              stream: audioService.playingStream,
              builder: (context, snapshot) {
                if (snapshot.data ?? false) {
                  return Positioned(
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => _AnimatedWave(
                          delay: Duration(milliseconds: i * 100),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildHorizontalList(
    BuildContext context,
    bool isDark,
    HomeState homeState,
  ) {
    if (homeState.recommendedSurahs.isEmpty) return const SizedBox(height: 140);
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: homeState.recommendedSurahs.length,
        itemBuilder: (context, index) => _buildSurahCard(
          context,
          homeState.recommendedSurahs[index],
          isDark,
        ),
      ),
    );
  }

  Widget _buildSurahCard(BuildContext context, Surah surah, bool isDark) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Surah?>(
      stream: audioService.currentSurahStream,
      initialData: audioService.currentSurah,
      builder: (context, surahSnapshot) {
        final isCurrentSurah =
            surahSnapshot.data?.id == surah.id ||
            audioService.currentSurah?.id == surah.id;

        return GestureDetector(
          onTap: () => _navigateToPlayer(context, surah),
          child: Container(
            width: 140,
            height: 140,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrentSurah
                    ? [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ]
                    : [
                        isDark
                            ? const Color(0xFF282828)
                            : const Color(0xFFF5F5F5),
                        isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFEEEEEE),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: isCurrentSurah
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isCurrentSurah
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: isCurrentSurah ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surah.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.2,
                            color: isCurrentSurah
                                ? Colors.black
                                : (isDark ? Colors.white : Colors.black),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          surah.reciter,
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrentSurah
                                ? Colors.black.withValues(alpha: 0.7)
                                : (isDark ? Colors.white60 : Colors.black54),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StreamBuilder<ja.PlayerState>(
                        stream: audioService.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying =
                              (snapshot.data?.playing ?? false) &&
                              isCurrentSurah;
                          return GestureDetector(
                            onTap: () => isCurrentSurah && isPlaying
                                ? audioService.pause()
                                : audioService.loadAndPlay(surah),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrentSurah
                                    ? Colors.black
                                    : Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isCurrentSurah
                                                ? Colors.black
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary)
                                            .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: isCurrentSurah
                                    ? Colors.white
                                    : Colors.black,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurahGrid(
    BuildContext context,
    bool isDark,
    HomeState homeState,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildSurahListItem(context, homeState.allSurahs[index], isDark),
          childCount: homeState.allSurahs.length,
        ),
      ),
    );
  }

  Widget _buildSurahListItem(BuildContext context, Surah surah, bool isDark) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Surah?>(
      stream: audioService.currentSurahStream,
      initialData: audioService.currentSurah,
      builder: (context, surahSnapshot) {
        final isCurrentSurah =
            surahSnapshot.data?.id == surah.id ||
            audioService.currentSurah?.id == surah.id;

        return GestureDetector(
          onTap: () => _navigateToPlayer(context, surah),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentSurah
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                StreamBuilder<ja.PlayerState>(
                  stream: audioService.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying =
                        (snapshot.data?.playing ?? false) && isCurrentSurah;
                    return GestureDetector(
                      onTap: () => isCurrentSurah && isPlaying
                          ? audioService.pause()
                          : audioService.loadAndPlay(surah),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isCurrentSurah
                              ? Theme.of(context).colorScheme.primary
                              : (isDark
                                    ? const Color(0xFF282828)
                                    : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 24,
                            color: isCurrentSurah
                                ? Colors.black
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isCurrentSurah
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white : Colors.black),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surah.reciter,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  surah.duration,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    surah.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: surah.isFavorite
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                    size: 22,
                  ),
                  onPressed: () =>
                      ref.read(homeProvider.notifier).toggleFavorite(surah.id),
                ),
                Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToPlayer(BuildContext context, Surah surah) {
    final audioService = ref.read(audioPlayerServiceProvider);
    if (audioService.currentSurah?.id != surah.id) {
      audioService.loadAndPlay(surah);
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PlayerPage(surah: surah),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _AnimatedWave extends StatefulWidget {
  final Duration delay;
  const _AnimatedWave({required this.delay});

  @override
  State<_AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<_AnimatedWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: 2,
        height: 16 * _animation.value,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
