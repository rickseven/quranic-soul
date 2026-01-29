import 'dart:io';

/// AdMob Configuration
class AdConfig {
  // Test Ad Unit IDs (untuk development)
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  // Production Ad Unit IDs
  static const String _prodInterstitialAndroid =
      'ca-app-pub-4676628252612395/7527510222';
  static const String _prodInterstitialIos =
      'ca-app-pub-4676628252612395/7527510222';

  // Set to false for production
  static const bool useTestAds = false; // ← Set true untuk testing dulu

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return useTestAds ? _testInterstitialAndroid : _prodInterstitialAndroid;
    } else if (Platform.isIOS) {
      return useTestAds ? _testInterstitialIos : _prodInterstitialIos;
    }
    return _testInterstitialAndroid;
  }

  // Interstitial frequency: show ad every X plays (random between min and max)
  static const int minPlaysBeforeAd = 2;
  static const int maxPlaysBeforeAd = 4;
}
