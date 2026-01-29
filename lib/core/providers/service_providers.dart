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

// Reactive provider for PRO status
// This provider can be invalidated to force refresh
final isProProvider = StateProvider<bool>((ref) {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.isPro;
});

// Stream provider that listens to subscription changes and updates isProProvider
final proStatusListenerProvider = StreamProvider<bool>((ref) async* {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  await for (final isPro in subscriptionService.proStatusStream) {
    // Update the state provider when stream emits
    ref.read(isProProvider.notifier).state = isPro;
    yield isPro;
  }
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
