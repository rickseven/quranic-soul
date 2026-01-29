import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get quranAudioBaseUrl =>
      dotenv.env['QURAN_AUDIO_BASE_URL'] ??
      'https://rickseven.github.io/quran-audio';

  static String get quranDataUrl => '$quranAudioBaseUrl/quran-data.json';

  static String getAudioUrl(String filePath) {
    // filePath format: /mohmed-hesham/Al-Baqarah.opus
    return '$quranAudioBaseUrl$filePath';
  }
}
