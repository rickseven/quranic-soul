import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service untuk mengelola In-App Update dari Google Play
/// Best practice: Gunakan Immediate Update untuk UX yang lebih baik
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  AppUpdateInfo? _updateInfo;
  bool _isUpdateAvailable = false;

  bool get isUpdateAvailable => _isUpdateAvailable;
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Check apakah ada update tersedia
  Future<bool> checkForUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      _isUpdateAvailable =
          _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;
      return _isUpdateAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Tampilkan dialog update
  Future<void> showUpdateDialog(BuildContext context) async {
    if (!_isUpdateAvailable || _updateInfo == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priority = _updateInfo!.updatePriority;
    final isUrgent = priority >= 4;

    showModalBottomSheet(
      context: context,
      isDismissible: !isUrgent,
      enableDrag: !isUrgent,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _UpdateBottomSheet(
        isDark: isDark,
        isUrgent: isUrgent,
        onUpdate: () {
          Navigator.pop(bottomSheetContext);
          _performUpdate(context);
        },
        onLater: isUrgent ? null : () => Navigator.pop(bottomSheetContext),
      ),
    );
  }

  /// Perform update - prioritas Immediate, fallback ke Flexible
  Future<void> _performUpdate(BuildContext context) async {
    if (_updateInfo == null) return;

    // Capture navigator and scaffold messenger before async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading overlay
    _showLoadingOverlay(context);

    try {
      // Prioritas 1: Immediate Update (recommended - full screen, handled by Play)
      if (_updateInfo!.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        _hideLoadingOverlay(navigator);

        if (result != AppUpdateResult.success) {
          _showErrorSnackbar(scaffoldMessenger, 'Update was cancelled');
        }
        return;
      }

      // Prioritas 2: Flexible Update (background download)
      if (_updateInfo!.flexibleUpdateAllowed) {
        _hideLoadingOverlay(navigator);
        _showDownloadingSnackbar(scaffoldMessenger);

        final result = await InAppUpdate.startFlexibleUpdate();

        scaffoldMessenger.hideCurrentSnackBar();

        if (result == AppUpdateResult.success) {
          _showInstallSnackbar(scaffoldMessenger);
        } else {
          _showErrorSnackbar(scaffoldMessenger, 'Update was cancelled');
        }
        return;
      }

      // Tidak ada update method yang tersedia
      _hideLoadingOverlay(navigator);
      _showErrorSnackbar(scaffoldMessenger, 'Update not available');
    } catch (e) {
      _hideLoadingOverlay(navigator);
      _showErrorSnackbar(scaffoldMessenger, 'Update failed. Please try again.');
    }
  }

  void _showLoadingOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Preparing Update',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please wait...',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingOverlay(NavigatorState navigator) {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _showDownloadingSnackbar(ScaffoldMessengerState scaffoldMessenger) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Downloading update...')),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(minutes: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInstallSnackbar(ScaffoldMessengerState scaffoldMessenger) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Update ready to install')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 30),
        action: SnackBarAction(
          label: 'INSTALL',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (_) {
              // Silently handle update errors
            }
          },
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(
    ScaffoldMessengerState scaffoldMessenger,
    String message,
  ) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Bottom sheet widget untuk update dialog
class _UpdateBottomSheet extends StatelessWidget {
  final bool isDark;
  final bool isUrgent;
  final VoidCallback onUpdate;
  final VoidCallback? onLater;

  const _UpdateBottomSheet({
    required this.isDark,
    required this.isUrgent,
    required this.onUpdate,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          if (!isUrgent)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.orange.withValues(alpha: 0.15)
                  : primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUrgent ? Icons.system_update : Icons.update_rounded,
              size: 48,
              color: isUrgent ? Colors.orange : primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            isUrgent ? 'Important Update Required' : 'Update Available',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            isUrgent
                ? 'This update contains important fixes and improvements. Please update now to continue using the app.'
                : 'A new version of Quranic Soul is available with improvements and new features.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Update button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.download_rounded),
              label: const Text(
                'Update Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUrgent ? Colors.orange : primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),

          // Later button (only for non-urgent)
          if (onLater != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onLater,
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: isUrgent ? 16 : 8),
        ],
      ),
    );
  }
}
