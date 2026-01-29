import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/services/download_service.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../library/presentation/pages/library_page.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final Function(bool) onThemeChanged;

  const MainNavigation({super.key, required this.onThemeChanged});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<DownloadState?>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to download state changes to refresh library when download completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final downloadService = ref.read(downloadServiceProvider);
      _downloadSubscription = downloadService.downloadStateStream.listen((
        state,
      ) {
        if (state != null && state.isCompleted) {
          // Refresh library data when download completes
          ref.read(libraryProvider.notifier).loadData();
          // Also refresh home to update download status
          ref.read(homeProvider.notifier).loadSurahs();
        }
      });

      // Check for app updates
      _checkForUpdates();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app goes to background, stop player for non-PRO users
    if (state == AppLifecycleState.paused) {
      _handleAppPaused();
    }
  }

  void _handleAppPaused() {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final audioService = ref.read(audioPlayerServiceProvider);

    // For non-PRO users: stop player completely to dismiss notification
    if (!subscriptionService.isPro && audioService.currentSurah != null) {
      audioService.stop();
    }
  }

  Future<void> _checkForUpdates() async {
    final appUpdateService = ref.read(appUpdateServiceProvider);
    final hasUpdate = await appUpdateService.checkForUpdate();

    if (hasUpdate && mounted) {
      appUpdateService.showUpdateDialog(context);
    }
  }

  List<Widget> _buildPages() {
    return [
      const HomePage(),
      const LibraryPage(),
      SettingsPage(onThemeChanged: widget.onThemeChanged),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadService = ref.watch(downloadServiceProvider);

    return Scaffold(
      body: Column(
        children: [
          // Download progress banner
          StreamBuilder<DownloadState?>(
            stream: downloadService.downloadStateStream,
            builder: (context, snapshot) {
              final downloadState = snapshot.data;
              if (downloadState == null) return const SizedBox.shrink();

              return _buildDownloadBanner(context, isDark, downloadState);
            },
          ),
          // Main content
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _buildPages()),
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(context, isDark),
    );
  }

  Widget _buildDownloadBanner(
    BuildContext context,
    bool isDark,
    DownloadState state,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    Color backgroundColor;
    IconData icon;
    String message;

    if (state.isFailed) {
      backgroundColor = Colors.red;
      icon = Icons.error_rounded;
      message = 'Download failed: ${state.surahName}';
    } else if (state.isCompleted) {
      backgroundColor = Colors.green;
      icon = Icons.check_circle_rounded;
      message = 'Downloaded: ${state.surahName}';
    } else {
      backgroundColor = primaryColor;
      icon = Icons.download_rounded;
      message = 'Downloading: ${state.surahName}';
    }

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: backgroundColor),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!state.isCompleted && !state.isFailed) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!state.isCompleted && !state.isFailed)
              Text(
                '${(state.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNav(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
              isDark: isDark,
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.favorite_rounded,
              label: 'Library',
              isDark: isDark,
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.settings_rounded,
              label: 'Settings',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        // Refresh library data when navigating to Library tab
        if (index == 1) {
          ref.read(libraryProvider.notifier).loadData();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
