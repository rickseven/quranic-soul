import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import 'subscription_service.dart';

/// AdMob Interstitial Ad Service
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  int _playCount = 0;
  int _nextAdThreshold = 0;
  bool _isInitialized = false;

  final Random _random = Random();

  /// Initialize AdMob SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _setNextAdThreshold();
      await _loadInterstitialAd();
      _isInitialized = true;
    } catch (_) {}
  }

  void _setNextAdThreshold() {
    _nextAdThreshold =
        AdConfig.minPlaysBeforeAd +
        _random.nextInt(
          AdConfig.maxPlaysBeforeAd - AdConfig.minPlaysBeforeAd + 1,
        );
  }

  Future<void> _loadInterstitialAd() async {
    if (SubscriptionService().isPro) return;

    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoaded = false;
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isAdLoaded = false;
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isAdLoaded = false;
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Call this when a surah starts playing
  Future<bool> onSurahPlayed() async {
    if (SubscriptionService().isPro) return false;

    _playCount++;

    if (_playCount >= _nextAdThreshold) {
      final shown = await showInterstitialAd();
      if (shown) {
        _playCount = 0;
        _setNextAdThreshold();
      }
      return shown;
    }

    return false;
  }

  /// Show interstitial ad if loaded
  Future<bool> showInterstitialAd() async {
    if (SubscriptionService().isPro) return false;

    if (_isAdLoaded && _interstitialAd != null) {
      await _interstitialAd!.show();
      return true;
    } else {
      _loadInterstitialAd();
      return false;
    }
  }

  /// Reset play count
  void resetPlayCount() {
    _playCount = 0;
    _setNextAdThreshold();
  }

  /// Dispose ads
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
