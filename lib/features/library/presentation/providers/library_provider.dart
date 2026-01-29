import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../domain/entities/surah.dart';
import '../../../home/presentation/providers/home_provider.dart';

// =============================================================================
// STATE
// =============================================================================
class LibraryState {
  final List<Surah> favoriteSurahs;
  final List<Surah> downloadedSurahs;
  final int selectedTab; // 0 = Favorites, 1 = Downloads
  final bool isLoading;
  final String? error;

  const LibraryState({
    this.favoriteSurahs = const [],
    this.downloadedSurahs = const [],
    this.selectedTab = 0,
    this.isLoading = true,
    this.error,
  });

  LibraryState copyWith({
    List<Surah>? favoriteSurahs,
    List<Surah>? downloadedSurahs,
    int? selectedTab,
    bool? isLoading,
    String? error,
  }) {
    return LibraryState(
      favoriteSurahs: favoriteSurahs ?? this.favoriteSurahs,
      downloadedSurahs: downloadedSurahs ?? this.downloadedSurahs,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<Surah> get currentSurahs =>
      selectedTab == 0 ? favoriteSurahs : downloadedSurahs;
}

// =============================================================================
// NOTIFIER
// =============================================================================
class LibraryNotifier extends StateNotifier<LibraryState> {
  final Ref _ref;

  LibraryNotifier(this._ref) : super(const LibraryState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = _ref.read(surahRepositoryProvider);

      final favorites = await repository.getFavoriteSurahs();
      final downloaded = await repository.getDownloadedSurahs();

      state = state.copyWith(
        favoriteSurahs: favorites,
        downloadedSurahs: downloaded,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(e),
      );
    }
  }

  void setSelectedTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  Future<void> toggleFavorite(int surahId) async {
    final repository = _ref.read(surahRepositoryProvider);
    await repository.toggleFavorite(surahId);
    await loadData();

    // Sync with home provider
    _ref.read(homeProvider.notifier).loadSurahs();
  }

  Future<void> deleteDownload(int surahId) async {
    final downloadService = _ref.read(downloadServiceProvider);
    await downloadService.deleteSurah(surahId);
    await loadData();

    // Sync with home provider (download status might affect UI)
    _ref.read(homeProvider.notifier).loadSurahs();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  return LibraryNotifier(ref);
});
