import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/pro_config.dart';

enum SubscriptionType { none, monthly, annual, lifetime }

/// Subscription/In-App Purchase Service
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  SubscriptionType _currentSubscription = SubscriptionType.none;
  bool _isInitialized = false;
  bool _restoredFromStore = false;

  final _proStatusController = StreamController<bool>.broadcast();
  Stream<bool> get proStatusStream => _proStatusController.stream;

  // Getters
  bool get isPro =>
      ProConfig.forceProEnabled ||
      _currentSubscription != SubscriptionType.none;
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  SubscriptionType get currentSubscription => _currentSubscription;

  /// Initialize IAP
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isAvailable = await _iap.isAvailable();

      if (!_isAvailable) {
        // If store not available, load from local cache
        await _loadSubscriptionStatus();
        _isInitialized = true;
        return;
      }

      // Listen to purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (_) {},
      );

      // Load products
      await _loadProducts();

      // Restore previous purchases from store (this is the source of truth)
      await restorePurchases();

      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  Future<void> _loadProducts() async {
    const productIds = <String>{
      ProConfig.monthlySubscriptionId,
      ProConfig.annualSubscriptionId,
      ProConfig.lifetimeSubscriptionId,
    };

    try {
      final response = await _iap.queryProductDetails(productIds);
      _products = response.productDetails;
    } catch (_) {}
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    // If we receive any purchase updates (even empty), mark as restored
    if (purchases.isEmpty) {
      // Empty list means no active subscriptions
      return;
    }

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Mark as restored from store - we have valid purchase
          _restoredFromStore = true;
          _verifyAndDeliverPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _iap.completePurchase(purchase);
          break;

        case PurchaseStatus.canceled:
          _iap.completePurchase(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    if (productId == ProConfig.monthlySubscriptionId) {
      _currentSubscription = SubscriptionType.monthly;
    } else if (productId == ProConfig.annualSubscriptionId) {
      _currentSubscription = SubscriptionType.annual;
    } else if (productId == ProConfig.lifetimeSubscriptionId) {
      _currentSubscription = SubscriptionType.lifetime;
    }

    await _saveSubscriptionStatus();
    _proStatusController.add(isPro);

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> _saveSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subscription_type', _currentSubscription.index);
  }

  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('subscription_type') ?? 0;
    _currentSubscription = SubscriptionType.values[index];
    _proStatusController.add(isPro);
  }

  /// Purchase a subscription
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) return false;

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      return false;
    }
  }

  /// Restore previous purchases from Google Play/App Store
  /// This is the source of truth for subscription status
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      await _loadSubscriptionStatus();
      return;
    }

    try {
      // Reset flag before restore
      _restoredFromStore = false;

      // Temporarily clear subscription - will be restored if valid purchase exists
      // Don't clear lifetime as it's a one-time purchase
      final wasLifetime = _currentSubscription == SubscriptionType.lifetime;
      if (!wasLifetime) {
        _currentSubscription = SubscriptionType.none;
      }

      // This triggers _onPurchaseUpdate with restored purchases
      await _iap.restorePurchases();

      // Wait for restore callbacks to complete
      // Google Play needs time to send purchase updates
      await Future.delayed(const Duration(milliseconds: 2000));

      // After waiting, if _restoredFromStore is still false and we had a subscription,
      // it means the subscription is no longer valid
      if (!_restoredFromStore && !wasLifetime) {
        // No active subscription found from store
        _currentSubscription = SubscriptionType.none;
        await _saveSubscriptionStatus();
      }

      // Always emit current status to update UI
      _proStatusController.add(isPro);
    } catch (_) {
      // On error, fall back to local cache
      await _loadSubscriptionStatus();
    }
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Get price string for product
  String getPrice(String productId) {
    final product = getProduct(productId);
    if (product != null) {
      return product.price;
    }

    switch (productId) {
      case ProConfig.monthlySubscriptionId:
        return ProConfig.monthlyPriceFallback;
      case ProConfig.annualSubscriptionId:
        return ProConfig.annualPriceFallback;
      case ProConfig.lifetimeSubscriptionId:
        return ProConfig.lifetimePriceFallback;
      default:
        return '-';
    }
  }

  /// Get savings text for annual subscription
  String getAnnualSavings() {
    final monthlyProduct = getProduct(ProConfig.monthlySubscriptionId);
    final annualProduct = getProduct(ProConfig.annualSubscriptionId);

    if (monthlyProduct != null && annualProduct != null) {
      final monthlyYearCost = monthlyProduct.rawPrice * 12;
      final annualCost = annualProduct.rawPrice;

      if (monthlyYearCost > annualCost) {
        final savings = ((monthlyYearCost - annualCost) / monthlyYearCost * 100)
            .round();
        return 'Save $savings%';
      }
    }

    return ProConfig.annualSavingsFallback;
  }

  /// Get savings text for lifetime subscription
  String getLifetimeSavings() {
    return ProConfig.lifetimeSavingsFallback;
  }

  void dispose() {
    _subscription?.cancel();
    _proStatusController.close();
  }
}
