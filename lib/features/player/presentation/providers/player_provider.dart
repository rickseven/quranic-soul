import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../domain/entities/surah.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';

// =============================================================================
// STATE
// =============================================================================
class PlayerState {
  final Surah? currentSurah;
  final bool isLoading;
  final bool isRepeat;
  final bool isShuffle;
  final String? error;

  const PlayerState({
    this.currentSurah,
    this.isLoading = false,
    this.isRepeat = false,
    this.isShuffle = false,
    this.error,
  });

  PlayerState copyWith({
    Surah? currentSurah,
    bool? isLoading,
    bool? isRepeat,
    bool? isShuffle,
    String? error,
  }) {
    return PlayerState(
      currentSurah: currentSurah ?? this.currentSurah,
      isLoading: isLoading ?? this.isLoading,
      isRepeat: isRepeat ?? this.isRepeat,
      isShuffle: isShuffle ?? this.isShuffle,
      error: error,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;

  PlayerNotifier(this._ref) : super(const PlayerState());

  Future<void> loadAndPlay(Surah surah) async {
    state = state.copyWith(isLoading: true, error: null, currentSurah: surah);

    try {
      final audioService = _ref.read(audioPlayerServiceProvider);
      await audioService.loadAndPlay(surah);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(e),
      );
    }
  }

  void setCurrentSurah(Surah surah) {
    state = state.copyWith(currentSurah: surah);
  }

  Future<void> toggleFavorite() async {
    final currentSurah = state.currentSurah;
    if (currentSurah == null) return;

    final repository = _ref.read(surahRepositoryProvider);
    await repository.toggleFavorite(currentSurah.id);

    final updatedSurah = await repository.getSurahById(currentSurah.id);
    if (updatedSurah != null) {
      state = state.copyWith(currentSurah: updatedSurah);
    }

    // Sync with home and library providers
    _ref.read(homeProvider.notifier).loadSurahs();
    _ref.read(libraryProvider.notifier).loadData();
  }

  void toggleRepeat() {
    final newRepeat = !state.isRepeat;
    state = state.copyWith(isRepeat: newRepeat);

    final audioService = _ref.read(audioPlayerServiceProvider);
    audioService.setLoopMode(newRepeat ? LoopMode.one : LoopMode.off);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffle;
    state = state.copyWith(isShuffle: newShuffle);

    final audioService = _ref.read(audioPlayerServiceProvider);

    if (newShuffle) {
      // Shuffle the playlist
      final playlist = List<Surah>.from(audioService.playlist);
      final currentSurah = audioService.currentSurah;

      // Remove current surah from list, shuffle, then put current at front
      if (currentSurah != null) {
        playlist.removeWhere((s) => s.id == currentSurah.id);
        playlist.shuffle();
        playlist.insert(0, currentSurah);
      } else {
        playlist.shuffle();
      }

      audioService.setPlaylist(playlist);
    } else {
      // Restore original order - reload from repository
      _ref.read(homeProvider.notifier).loadSurahs();
    }
  }
}

// =============================================================================
// PROVIDER
// =============================================================================
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier(ref);
});
