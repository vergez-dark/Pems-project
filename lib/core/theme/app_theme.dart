import 'package:flutter/material.dart';

/// Couleurs de la direction artistique « Soft Luxury Commerce » de PeMS Store.
/// Les alias historiques sont conservés pour les écrans métier existants.
abstract final class AppColors {
  static const rose = Color(0xFFE8B4C0);
  static const roseDark = Color(0xFF7C535D);
  static const roseLight = Color(0xFFF9E9ED);
  static const blush = Color(0xFFFFF0F3);
  static const canvas = Color(0xFFFFF8F8);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF332A2D);
  static const muted = Color(0xFF8B8385);
  static const border = Color(0xFFF0E3E6);
  static const gold = Color(0xFFD4AF72);
  static const profit = Color(0xFF34A853);
  static const loss = Color(0xFFEA4335);
  static const warning = Color(0xFFFBBC04);

  static const forest = roseDark;
  static const emerald = rose;
  static const lime = gold;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFFE7B2BE),
          onPrimary: Color(0xFF47252E),
          primaryContainer: Color(0xFF623C46),
          onPrimaryContainer: Color(0xFFFFD9E1),
          secondary: Color(0xFFE7C182),
          onSecondary: Color(0xFF402D00),
          secondaryContainer: Color(0xFF5C420F),
          onSecondaryContainer: Color(0xFFFFDEAA),
          tertiary: Color(0xFFB1CEAF),
          onTertiary: Color(0xFF1D361F),
          surface: Color(0xFF21191C),
          onSurface: Color(0xFFF3E3E7),
          surfaceContainerHighest: Color(0xFF504446),
          outline: Color(0xFFA79598),
          outlineVariant: Color(0xFF504446),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
        )
      : const ColorScheme.light(
          primary: AppColors.roseDark,
          onPrimary: Colors.white,
          primaryContainer: AppColors.rose,
          onPrimaryContainer: AppColors.ink,
          secondary: Color(0xFF765A25),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFFD797),
          onSecondaryContainer: Color(0xFF332500),
          tertiary: Color(0xFF4B654B),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFCEEACA),
          onTertiaryContainer: Color(0xFF153618),
          surface: AppColors.canvas,
          onSurface: Color(0xFF21191C),
          surfaceContainerHighest: Color(0xFFEEDEE2),
          outline: Color(0xFF827476),
          outlineVariant: Color(0xFFD4C2C5),
          error: Color(0xFFBA1A1A),
          onError: Colors.white,
        );

  final baseText = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: 'Inter',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Inter',
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF2A2124) : AppColors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.rose.withValues(alpha: .18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: dark ? const Color(0xFF504446) : AppColors.border,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2124) : Colors.white,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? scheme.primary : AppColors.rose,
        foregroundColor: dark ? scheme.onPrimary : AppColors.ink,
        minimumSize: const Size(48, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 1,
      backgroundColor: dark ? scheme.primary : AppColors.rose,
      foregroundColor: dark ? scheme.onPrimary : AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: dark ? const Color(0xFF2A2124) : Colors.white,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : AppColors.roseDark)
              : scheme.onSurfaceVariant,
          size: 23,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : AppColors.roseDark)
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          fontSize: 11,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      selectedColor: scheme.primaryContainer,
      backgroundColor: dark ? const Color(0xFF2A2124) : Colors.white,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF2A2124) : AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF2A2124) : AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    visualDensity: VisualDensity.standard,
  );
}
