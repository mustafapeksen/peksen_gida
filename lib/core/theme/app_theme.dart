import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const forest = Color(0xFF173F35);
  const cream = Color(0xFFF6F7F2);
  const lime = Color(0xFFD8EB9C);

  final colors =
      ColorScheme.fromSeed(
        seedColor: forest,
        brightness: Brightness.light,
      ).copyWith(
        primary: forest,
        onPrimary: Colors.white,
        secondary: forest,
        onSecondary: Colors.white,
        secondaryContainer: lime,
        onSecondaryContainer: forest,
        surface: cream,
        onSurface: const Color(0xFF1F322C),
        onSurfaceVariant: const Color(0xFF5C6C62),
        outline: const Color(0xFF7B8980),
        outlineVariant: const Color(0xFFDCE2D8),
      );

  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final roundedBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: BorderSide(color: colors.outlineVariant),
  );

  return base.copyWith(
    scaffoldBackgroundColor: cream,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.16,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: cream,
      foregroundColor: forest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: forest,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: roundedBorder,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: forest, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 32),
  );
}
