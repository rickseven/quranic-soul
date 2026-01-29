/// Pro/Premium Configuration
class ProConfig {
  // ============================================
  // DEVELOPMENT FLAG - Set to true to test PRO features locally
  // Set to false for production builds
  // ============================================
  static bool forceProEnabled = false;

  // In-App Purchase Product IDs
  // These must match exactly with Google Play Console product IDs
  static const String monthlySubscriptionId = 'quranic_soul_pro_monthly';
  static const String annualSubscriptionId = 'quranic_soul_pro_annual';
  static const String lifetimeSubscriptionId = 'quranic_soul_pro_lifetime';

  // Fallback prices (shown only when store data is unavailable)
  // Actual prices are fetched from Google Play/App Store
  // and automatically localized to user's currency
  static const String monthlyPriceFallback = '\$0.89';
  static const String annualPriceFallback = '\$8.99';
  static const String lifetimePriceFallback = '\$26.99';

  // Fallback savings text (used when store prices unavailable)
  static const String annualSavingsFallback = 'Save 16%';
  static const String lifetimeSavingsFallback = 'Best Value';
}
