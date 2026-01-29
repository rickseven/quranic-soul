import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../../../core/providers/service_providers.dart';
import '../../../../domain/entities/surah.dart';
import '../providers/library_provider.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark),
            _buildTabChips(context, ref, isDark, state),
            Expanded(
              child: state.isLoading
                  ? _buildLoadingState(context, isDark)
                  : state.error != null
                  ? _buildErrorState(context, ref, isDark, state.error!)
                  : _buildContent(context, ref, isDark, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Text(
        'Library',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildTabChips(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    LibraryState state,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildChip(
            label: 'Favorites',
            isSelected: state.selectedTab == 0,
            onTap: () => ref.read(libraryProvider.notifier).setSelectedTab(0),
            primaryColor: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _buildChip(
            label: 'Downloads',
            isSelected: state.selectedTab == 1,
            onTap: () => ref.read(libraryProvider.notifier).setSelectedTab(1),
            primaryColor: primaryColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    LibraryState state,
  ) {
    final surahs = state.currentSurahs;

    if (surahs.isEmpty) {
      return _buildEmptyState(context, isDark, state.selectedTab == 0);
    }

    return _buildSurahList(context, ref, surahs, isDark, state.selectedTab);
  }

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    String error,
  ) {
    return Center(
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
              'Failed to load',
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
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(libraryProvider.notifier).loadData(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool isFavorites) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFavorites ? Icons.favorite_rounded : Icons.download_rounded,
                size: 48,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFavorites ? 'No favorites yet' : 'No downloads yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFavorites
                  ? 'Tap the heart icon on any surah to add it here'
                  : 'Download surahs to listen offline',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahList(
    BuildContext context,
    WidgetRef ref,
    List<Surah> surahs,
    bool isDark,
    int selectedTab,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          final surah = surahs[index];

          // Downloads tab: use swipe-to-delete
          if (selectedTab == 1) {
            return Dismissible(
              key: Key('download_${surah.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final confirmed = await _showDeleteConfirmation(
                  context,
                  surah.name,
                );
                if (confirmed) {
                  await ref
                      .read(libraryProvider.notifier)
                      .deleteDownload(surah.id);
                  if (context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('${surah.name} deleted'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
                return false; // Don't auto-dismiss, we handle it manually
              },
              child: _buildDownloadItem(context, ref, surah, isDark),
            );
          }

          // Favorites tab: normal item
          return _buildFavoriteItem(context, ref, surah, isDark);
        },
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    String name,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete download?'),
            content: Text('Are you sure you want to delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildFavoriteItem(
    BuildContext context,
    WidgetRef ref,
    Surah surah,
    bool isDark,
  ) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Surah?>(
      stream: audioService.currentSurahStream,
      initialData: audioService.currentSurah,
      builder: (context, snapshot) {
        final isCurrentSurah =
            snapshot.data?.id == surah.id ||
            audioService.currentSurah?.id == surah.id;

        return GestureDetector(
          onTap: () => _navigateToPlayer(context, ref, surah),
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
                _buildPlayButton(context, ref, surah, isCurrentSurah, isDark),
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
                Text(
                  surah.duration,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  onPressed: () {
                    ref.read(libraryProvider.notifier).toggleFavorite(surah.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadItem(
    BuildContext context,
    WidgetRef ref,
    Surah surah,
    bool isDark,
  ) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    final isPro = subscriptionService.isPro;
    final isLocked = !isPro;

    return StreamBuilder<Surah?>(
      stream: audioService.currentSurahStream,
      initialData: audioService.currentSurah,
      builder: (context, snapshot) {
        final isCurrentSurah =
            snapshot.data?.id == surah.id ||
            audioService.currentSurah?.id == surah.id;

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              _showLockedDialog(context);
            } else {
              _navigateToPlayer(context, ref, surah);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentSurah && !isLocked
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
                if (isLocked)
                  _buildLockedIcon(context, isDark)
                else
                  _buildPlayButton(context, ref, surah, isCurrentSurah, isDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              surah.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isLocked
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : (isCurrentSurah
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLocked)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surah.reciter,
                        style: TextStyle(
                          fontSize: 13,
                          color: isLocked
                              ? (isDark ? Colors.white24 : Colors.black26)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  surah.duration,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark ? Colors.white24 : Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockedIcon(BuildContext context, bool isDark) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.lock_rounded,
        size: 24,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  Widget _buildPlayButton(
    BuildContext context,
    WidgetRef ref,
    Surah surah,
    bool isCurrentSurah,
    bool isDark,
  ) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<ja.PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = (snapshot.data?.playing ?? false) && isCurrentSurah;
        return GestureDetector(
          onTap: () {
            if (isCurrentSurah && isPlaying) {
              audioService.pause();
            } else {
              audioService.loadAndPlay(surah);
            }
          },
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
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: isCurrentSurah
                    ? Colors.black
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lock_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Content Locked'),
          ],
        ),
        content: const Text(
          'Your subscription has expired. Subscribe to PRO to access your downloaded content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage()),
              );
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _navigateToPlayer(BuildContext context, WidgetRef ref, Surah surah) {
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
