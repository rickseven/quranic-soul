import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../domain/entities/surah.dart';
import '../../../library/presentation/providers/library_provider.dart';

// =============================================================================
// STATE
// =============================================================================
class HomeState {
  final List<Surah> allSurahs;
  final List<Surah> recommendedSurahs;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.allSurahs = const [],
    this.recommendedSurahs = const [],
    this.isLoading = true,
    this.error,
  });

  HomeState copyWith({
    List<Surah>? allSurahs,
    List<Surah>? recommendedSurahs,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      allSurahs: allSurahs ?? this.allSurahs,
      recommendedSurahs: recommendedSurahs ?? this.recommendedSurahs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================
class HomeNotifier extends StateNotifier<HomeState> {
  final Ref _ref;

  HomeNotifier(this._ref) : super(const HomeState()) {
    loadSurahs();
  }

  Future<void> loadSurahs() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = _ref.read(surahRepositoryProvider);
      final audioService = _ref.read(audioPlayerServiceProvider);
      final subscriptionService = _ref.read(subscriptionServiceProvider);

      // Refresh subscription status from store
      await subscriptionService.restorePurchases();

      // Update the isProProvider with latest status
      _ref.read(isProProvider.notifier).state = subscriptionService.isPro;

      final allSurahs = await repository.getAllSurahs();
      final recommended = await repository.getRecommendedSurahs();

      // Set playlist in audio service
      audioService.setPlaylist(allSurahs);

      state = state.copyWith(
        allSurahs: allSurahs,
        recommendedSurahs: recommended,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(e),
      );
    }
  }

  Future<void> toggleFavorite(int surahId) async {
    final repository = _ref.read(surahRepositoryProvider);
    await repository.toggleFavorite(surahId);
    await loadSurahs();

    // Sync with library provider
    _ref.read(libraryProvider.notifier).loadData();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});
