import 'package:flutter/material.dart';

/// Grayscale theme matching the proposal wireframes (Appendix A).
///
/// Text and control outlines keep at least 4.5:1 and 3:1 contrast on white.
/// Red is used only for validation and failure messages, as in the wireframes.
ThemeData buildFocusQuestTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF333333),
    onPrimary: Colors.white,
    secondary: Color(0xFF5F5F5F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE4E4E4),
    onSecondaryContainer: Color(0xFF1A1A1A),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFFBE4E4),
    onErrorContainer: Color(0xFF8C1D18),
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    onSurfaceVariant: Color(0xFF5F5F5F),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF8F8F8),
    surfaceContainer: Color(0xFFF4F4F4),
    surfaceContainerHigh: Color(0xFFEFEFEF),
    surfaceContainerHighest: Color(0xFFEAEAEA),
    outline: Color(0xFF8C8C8C),
    outlineVariant: Color(0xFFD6D6D6),
  );

  const radius = BorderRadius.all(Radius.circular(6));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Color(0xFFD6D6D6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.outline),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0xFF8C8C8C)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Color(0xFFE4E4E4),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFD6D6D6)),
  );
}
