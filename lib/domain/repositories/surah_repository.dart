import '../entities/surah.dart';

abstract class SurahRepository {
  Future<List<Surah>> getAllSurahs();
  Future<List<Surah>> getRecommendedSurahs();
  Future<List<Surah>> getFavoriteSurahs();
  Future<List<Surah>> getDownloadedSurahs();
  Future<void> toggleFavorite(int surahId);
  Future<Surah?> getSurahById(int id);
  String getAudioUrl(Surah surah);
}
