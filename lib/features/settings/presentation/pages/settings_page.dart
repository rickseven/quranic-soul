import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPro = ref.watch(subscriptionServiceProvider).isPro;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildSection('Appearance', [
                    _buildSwitchTile(
                      context: context,
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark theme',
                      value: isDark,
                      onChanged: widget.onThemeChanged,
                      isDark: isDark,
                    ),
                  ], isDark),
                  const SizedBox(height: 24),
                  _buildSection('Subscription', [
                    _buildTile(
                      context: context,
                      icon: Icons.workspace_premium_rounded,
                      title: 'Quranic Soul PRO',
                      subtitle: isPro
                          ? 'You are a PRO member'
                          : 'Unlock all features',
                      trailing: isPro
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionPage(),
                        ),
                      ),
                      isDark: isDark,
                    ),
                  ], isDark),
                  const SizedBox(height: 24),
                  _buildSection('About', [
                    _buildTile(
                      context: context,
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      subtitle: _appVersion.isNotEmpty ? _appVersion : '...',
                      isDark: isDark,
                    ),
                    _buildTile(
                      context: context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'View our privacy policy',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () => _openPrivacyPolicy(context),
                      isDark: isDark,
                    ),
                    _buildTile(
                      context: context,
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      subtitle: 'View our terms of service',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () => _openTermsOfService(context),
                      isDark: isDark,
                    ),
                  ], isDark),
                  const SizedBox(height: 24),
                  _buildSection('More', [
                    _buildTile(
                      context: context,
                      icon: Icons.share_rounded,
                      title: 'Share App',
                      subtitle: 'Share Quranic Soul with friends',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () => _shareApp(),
                      isDark: isDark,
                    ),
                    _buildTile(
                      context: context,
                      icon: Icons.star_rounded,
                      title: 'Rate App',
                      subtitle: 'Rate us on the store',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () => _rateApp(context),
                      isDark: isDark,
                    ),
                    _buildTile(
                      context: context,
                      icon: Icons.apps_rounded,
                      title: 'Other Apps',
                      subtitle: 'Check out our other apps',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () => _openOtherApps(context),
                      isDark: isDark,
                    ),
                  ], isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Theme.of(context).colorScheme.primary,
        activeThumbColor: Colors.white,
      ),
    );
  }

  void _shareApp() {
    const String appUrl =
        'https://play.google.com/store/apps/details?id=com.rickseven.quranicsoul';
    const String shareText =
        'Check out Quranic Soul - Soothing Quran recitations for inner peace and relaxation.\n\n$appUrl';

    Share.share(
      shareText,
      subject: 'Quranic Soul - Inner Peace Through Recitation',
    );
  }

  Future<void> _rateApp(BuildContext context) async {
    const url =
        'https://play.google.com/store/apps/details?id=com.rickseven.quranicsoul';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store')),
        );
      }
    }
  }

  Future<void> _openOtherApps(BuildContext context) async {
    const url =
        'https://play.google.com/store/apps/developer?id=Rickseven+Studio';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store')),
        );
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
