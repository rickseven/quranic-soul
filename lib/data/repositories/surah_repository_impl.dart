import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/env_config.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/surah.dart';
import '../../domain/repositories/surah_repository.dart';
import '../datasources/surah_remote_datasource.dart';

class SurahRepositoryImpl implements SurahRepository {
  final SurahRemoteDataSource remoteDataSource;
  final DownloadService _downloadService = DownloadService();

  SurahRepositoryImpl({required this.remoteDataSource}) {
    _loadFavorites();
  }

  List<Surah> _cachedSurahs = [];
  final Set<int> _favoriteSurahIds = {};

  // Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_surahs') ?? [];
      _favoriteSurahIds.addAll(favorites.map((e) => int.parse(e)));
    } catch (_) {}
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'favorite_surahs',
        _favoriteSurahIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  @override
  Future<List<Surah>> getAllSurahs() async {
    if (_cachedSurahs.isEmpty) {
      final responses = await remoteDataSource.fetchSurahs();
      _cachedSurahs = responses
          .asMap()
          .entries
          .map((entry) => entry.value.toEntity(entry.key + 1))
          .toList();
    }
    // Always get fresh download status from DownloadService
    return _cachedSurahs
        .map(
          (s) => s.copyWith(
            isFavorite: _favoriteSurahIds.contains(s.id),
            isDownloaded: _downloadService.isDownloaded(s.id),
          ),
        )
        .toList();
  }

  @override
  Future<List<Surah>> getRecommendedSurahs() async {
    final allSurahs = await getAllSurahs();
    final recommended = allSurahs.where((s) => s.isRecommend).toList();
    // Sort by surah name alphabetically
    recommended.sort((a, b) => a.name.compareTo(b.name));
    return recommended;
  }

  @override
  Future<List<Surah>> getFavoriteSurahs() async {
    final allSurahs = await getAllSurahs();
    return allSurahs.where((s) => s.isFavorite).toList();
  }

  @override
  Future<List<Surah>> getDownloadedSurahs() async {
    // Get fresh data - don't rely on cached isDownloaded
    final allSurahs = await getAllSurahs();
    final downloadedIds = _downloadService.downloadedSurahIds;
    return allSurahs.where((s) => downloadedIds.contains(s.id)).toList();
  }

  @override
  Future<void> toggleFavorite(int surahId) async {
    if (_favoriteSurahIds.contains(surahId)) {
      _favoriteSurahIds.remove(surahId);
    } else {
      _favoriteSurahIds.add(surahId);
    }
    await _saveFavorites();
  }

  @override
  Future<Surah?> getSurahById(int id) async {
    final allSurahs = await getAllSurahs();
    try {
      return allSurahs.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  String getAudioUrl(Surah surah) {
    return EnvConfig.getAudioUrl(surah.filePath);
  }
}
