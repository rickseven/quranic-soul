import 'package:flutter/material.dart';

/// App Theme Configuration
/// Modern Dark/Light Theme - Spotify/Apple Music inspired
class AppTheme {
  AppTheme._();

  // ============================================================================
  // COLOR PALETTE - DARK THEME
  // ============================================================================
  static const Color primaryDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF282828);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFB3B3B3);
  static const Color textDimmed = Color(0xFF727272);

  // ============================================================================
  // COLOR PALETTE - LIGHT THEME
  // ============================================================================
  static const Color primaryLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF191414);
  static const Color textGreyLight = Color(0xFF535353);

  // ============================================================================
  // ACCENT COLORS
  // ============================================================================
  static const Color accent = Color(0xFFE8B931); // Warm gold/amber
  static const Color accentLight = Color(0xFFF5D76E);

  // ============================================================================
  // DARK THEME
  // ============================================================================
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: primaryDark,
    primaryColor: accent,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentLight,
      surface: surfaceDark,
      onPrimary: primaryDark,
      onSecondary: primaryDark,
      onSurface: textWhite,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textWhite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: textWhite),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: primaryDark,
      selectedItemColor: accent,
      unselectedItemColor: textDimmed,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: textDimmed,
      thumbColor: textWhite,
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return textGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent.withValues(alpha: 0.5);
        }
        return textDimmed;
      }),
    ),
    iconTheme: const IconThemeData(color: textWhite),
    dividerTheme: const DividerThemeData(color: cardDark, thickness: 1),
  );

  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: primaryLight,
    primaryColor: accent,
    colorScheme: const ColorScheme.light(
      primary: accent,
      secondary: accentLight,
      surface: surfaceLight,
      onPrimary: textDark,
      onSecondary: textDark,
      onSurface: textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: textDark),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: accent,
      unselectedItemColor: textGreyLight,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: textGreyLight.withValues(alpha: 0.3),
      thumbColor: accent,
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return textGreyLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent.withValues(alpha: 0.5);
        }
        return textGreyLight.withValues(alpha: 0.3);
      }),
    ),
    iconTheme: const IconThemeData(color: textDark),
    dividerTheme: const DividerThemeData(color: cardLight, thickness: 1),
  );
}
