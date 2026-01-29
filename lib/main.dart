import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/service_providers.dart';
import 'core/services/audio_player_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Audio Service early for media notification
  await AudioPlayerService.initializeService();

  // Pass all uncaught errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: QuranicSoulApp()));
}

/// Root Application Widget
class QuranicSoulApp extends ConsumerStatefulWidget {
  const QuranicSoulApp({super.key});

  @override
  ConsumerState<QuranicSoulApp> createState() => _QuranicSoulAppState();
}

class _QuranicSoulAppState extends ConsumerState<QuranicSoulApp>
    with WidgetsBindingObserver {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
    _initializeServices();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode') ?? true;
      if (mounted) {
        setState(() {
          _isDarkMode = isDark;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDark);
    } catch (_) {}
  }

  Future<void> _initializeServices() async {
    // Initialize services via providers
    final downloadService = ref.read(downloadServiceProvider);
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final adService = ref.read(adServiceProvider);
    final soundEffectService = ref.read(soundEffectServiceProvider);

    await downloadService.initialize();
    await subscriptionService.initialize();
    await adService.initialize();
    soundEffectService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final audioService = ref.read(audioPlayerServiceProvider);
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final soundEffectService = ref.read(soundEffectServiceProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (!subscriptionService.isPro && audioService.isPlaying) {
          audioService.pause();
        }
        break;

      case AppLifecycleState.resumed:
        // When app comes back to foreground, ensure sound effects are synced
        // with main audio player state
        if (audioService.isPlaying) {
          // Main audio is playing, ensure sound effects are resumed
          soundEffectService.onAppResumed();
        }
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
    _saveThemePreference(isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quranic Soul',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SplashPage(onThemeChanged: _toggleTheme),
    );
  }
}
