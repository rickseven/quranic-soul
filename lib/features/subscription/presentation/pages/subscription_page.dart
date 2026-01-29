import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/pro_config.dart';
import '../../../../core/services/subscription_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  late String _selectedPlan;
  bool _isLoading = false;
  StreamSubscription<bool>? _proStatusSubscription;

  @override
  void initState() {
    super.initState();
    // Set selected plan based on current subscription
    _selectedPlan = _getSelectedPlanFromSubscription();

    // Listen to pro status changes for real-time UI updates
    _proStatusSubscription = _subscriptionService.proStatusStream.listen((_) {
      if (mounted) {
        setState(() {
          _selectedPlan = _getSelectedPlanFromSubscription();
        });
      }
    });
  }

  @override
  void dispose() {
    _proStatusSubscription?.cancel();
    super.dispose();
  }

  String _getSelectedPlanFromSubscription() {
    switch (_subscriptionService.currentSubscription) {
      case SubscriptionType.monthly:
        return ProConfig.monthlySubscriptionId;
      case SubscriptionType.annual:
        return ProConfig.annualSubscriptionId;
      case SubscriptionType.lifetime:
        return ProConfig.lifetimeSubscriptionId;
      case SubscriptionType.none:
        return ProConfig.annualSubscriptionId; // Default for non-subscribers
    }
  }

  String _getSubscriptionName(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.monthly:
        return 'Monthly';
      case SubscriptionType.annual:
        return 'Annual';
      case SubscriptionType.lifetime:
        return 'Lifetime';
      case SubscriptionType.none:
        return 'None';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isPro = _subscriptionService.isPro;
    final isDevMode = ProConfig.forceProEnabled;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPro ? 'Your Subscription' : 'Go PRO',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dev mode banner (show at top if enabled)
              if (isDevMode) ...[
                _buildDevModeBanner(isDark),
                const SizedBox(height: 24),
              ],

              // Show UI based on subscription status
              if (isPro)
                _buildActiveSubscriptionUI(isDark, primaryColor)
              else
                _buildSubscribeUI(isDark, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Dev mode banner
  Widget _buildDevModeBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.developer_mode, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEV MODE: PRO enabled for testing',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// UI for active subscribers
  Widget _buildActiveSubscriptionUI(bool isDark, Color primaryColor) {
    final subscriptionType = _subscriptionService.currentSubscription;
    final isDevMode = ProConfig.forceProEnabled;

    // Di dev mode dengan none subscription, tampilkan sebagai "Dev Mode Active"
    final displayType = (isDevMode && subscriptionType == SubscriptionType.none)
        ? null // null means dev mode without real subscription
        : subscriptionType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active subscription badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.black,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                displayType != null
                    ? '${_getSubscriptionName(displayType)} Subscription'
                    : 'Development Mode',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
              if (displayType != null &&
                  displayType != SubscriptionType.lifetime) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Auto-renews ${displayType == SubscriptionType.monthly ? 'monthly' : 'annually'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Features unlocked
        Text(
          'Features Unlocked',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),

        _buildFeatureItem(
          icon: Icons.headphones_rounded,
          title: 'Background playing',
          subtitle: 'Listen in background mode',
          isDark: isDark,
          primaryColor: primaryColor,
          isUnlocked: true,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.money_off_rounded,
          title: 'Ad free',
          subtitle: 'Enjoy an ad-free experience',
          isDark: isDark,
          primaryColor: primaryColor,
          isUnlocked: true,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.download_rounded,
          title: 'Offline access',
          subtitle: 'Listen downloaded surahs without internet',
          isDark: isDark,
          primaryColor: primaryColor,
          isUnlocked: true,
        ),

        const SizedBox(height: 32),

        // Manage subscription info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: isDark ? Colors.white54 : Colors.black54,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Manage Subscription',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'To cancel or change your subscription, go to your device\'s subscription settings in the App Store or Google Play Store.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Footer Links
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink(
              'Terms & Conditions',
              isDark,
              onTap: () => _openTermsOfService(context),
            ),
            const SizedBox(width: 24),
            _buildFooterLink(
              'Privacy Policy',
              isDark,
              onTap: () => _openPrivacyPolicy(context),
            ),
          ],
        ),
      ],
    );
  }

  /// UI for non-subscribers
  Widget _buildSubscribeUI(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Unlock all premium\nfeatures',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 32),

        // Features
        _buildFeatureItem(
          icon: Icons.headphones_rounded,
          title: 'Background playing',
          subtitle: 'Listen in background mode',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 20),
        _buildFeatureItem(
          icon: Icons.money_off_rounded,
          title: 'Ad free',
          subtitle: 'Enjoy an ad-free experience',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 20),
        _buildFeatureItem(
          icon: Icons.download_rounded,
          title: 'Offline access',
          subtitle: 'Listen downloaded surahs without internet',
          isDark: isDark,
          primaryColor: primaryColor,
        ),

        const SizedBox(height: 40),

        // Subscription Options
        _buildSubscriptionOption(
          productId: ProConfig.monthlySubscriptionId,
          title: 'Monthly',
          price: _subscriptionService.getPrice(ProConfig.monthlySubscriptionId),
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 12),
        _buildSubscriptionOption(
          productId: ProConfig.annualSubscriptionId,
          title: 'Annual',
          price: _subscriptionService.getPrice(ProConfig.annualSubscriptionId),
          subtitle: _subscriptionService.getAnnualSavings(),
          isDark: isDark,
          primaryColor: primaryColor,
          isPopular: true,
        ),
        const SizedBox(height: 12),
        _buildSubscriptionOption(
          productId: ProConfig.lifetimeSubscriptionId,
          title: 'Lifetime',
          price: _subscriptionService.getPrice(
            ProConfig.lifetimeSubscriptionId,
          ),
          subtitle: _subscriptionService.getLifetimeSavings(),
          isDark: isDark,
          primaryColor: primaryColor,
        ),

        const SizedBox(height: 32),

        // Continue Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Subscribe Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 24),

        // Footer Links
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFooterLink(
              'Terms &\nConditions',
              isDark,
              onTap: () => _openTermsOfService(context),
            ),
            _buildFooterLink(
              'Restore\nPurchase',
              isDark,
              onTap: _handleRestore,
            ),
            _buildFooterLink(
              'Privacy\nPolicy',
              isDark,
              onTap: () => _openPrivacyPolicy(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color primaryColor,
    bool isUnlocked = false,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isUnlocked
                ? primaryColor.withValues(alpha: 0.2)
                : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isUnlocked
                ? primaryColor
                : (isDark ? Colors.white54 : Colors.black54),
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        if (isUnlocked)
          Icon(Icons.check_circle_rounded, color: primaryColor, size: 24),
      ],
    );
  }

  Widget _buildSubscriptionOption({
    required String productId,
    required String title,
    required String price,
    String? subtitle,
    required bool isDark,
    required Color primaryColor,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlan == productId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = productId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price
            Text(
              price,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
          decoration: onTap != null ? TextDecoration.underline : null,
          decorationColor: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);

    try {
      await _subscriptionService.purchase(_selectedPlan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);

    try {
      await _subscriptionService.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checking for previous purchases...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const url = 'https://rickseven.com/privacy';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Privacy Policy')),
        );
      }
    }
  }

  Future<void> _openTermsOfService(BuildContext context) async {
    const url = 'https://rickseven.com/terms';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Terms of Service')),
        );
      }
    }
  }
}
