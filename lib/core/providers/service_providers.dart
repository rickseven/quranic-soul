import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/surah_remote_datasource.dart';
import '../../data/repositories/surah_repository_impl.dart';
import '../../domain/repositories/surah_repository.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/subscription_service.dart';
import '../services/ad_service.dart';
import '../services/sound_effect_service.dart';
import '../services/app_update_service.dart';

// =============================================================================
// HTTP CLIENT
// =============================================================================
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

// =============================================================================
// DATA SOURCES
// =============================================================================
final surahRemoteDataSourceProvider = Provider<SurahRemoteDataSource>((ref) {
  return SurahRemoteDataSourceImpl(client: ref.watch(httpClientProvider));
});

// =============================================================================
// REPOSITORIES
// =============================================================================
final surahRepositoryProvider = Provider<SurahRepository>((ref) {
  return SurahRepositoryImpl(
    remoteDataSource: ref.watch(surahRemoteDataSourceProvider),
  );
});

// =============================================================================
// SERVICES (Singletons)
// =============================================================================
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService();
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) {
  return SoundEffectService();
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});
