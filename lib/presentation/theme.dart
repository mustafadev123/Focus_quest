import 'package:flutter/material.dart';

/// Grayscale light scheme matching the proposal wireframes (Appendix A).
///
/// Text and control outlines keep at least 4.5:1 and 3:1 contrast against
/// the background. Red is used only for validation and failure messages.
const lightScheme = ColorScheme(
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
  inverseSurface: Color(0xFF2E2E2E),
  onInverseSurface: Color(0xFFF2F2F2),
);

/// The same grayscale design with light text on near-black surfaces, with
/// the same contrast targets.
const darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFE6E6E6),
  onPrimary: Color(0xFF121212),
  secondary: Color(0xFFB0B0B0),
  onSecondary: Color(0xFF121212),
  secondaryContainer: Color(0xFF3A3A3A),
  onSecondaryContainer: Color(0xFFF0F0F0),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
  surface: Color(0xFF121212),
  onSurface: Color(0xFFEDEDED),
  onSurfaceVariant: Color(0xFFB3B3B3),
  surfaceContainerLowest: Color(0xFF0E0E0E),
  surfaceContainerLow: Color(0xFF1A1A1A),
  surfaceContainer: Color(0xFF1E1E1E),
  surfaceContainerHigh: Color(0xFF282828),
  surfaceContainerHighest: Color(0xFF323232),
  outline: Color(0xFF8C8C8C),
  outlineVariant: Color(0xFF3D3D3D),
  inverseSurface: Color(0xFFEDEDED),
  onInverseSurface: Color(0xFF1A1A1A),
);

ThemeData buildFocusQuestTheme([Brightness brightness = Brightness.light]) {
  final scheme = brightness == Brightness.dark ? darkScheme : lightScheme;
  const radius = BorderRadius.all(Radius.circular(6));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
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
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
