import 'package:flutter/material.dart';

import 'semantic_colors.dart';

/// Builds the app theme from a city's brand colour.
///
/// The palette is seeded from the city colour but the surfaces stay neutral so
/// route colours (which are semantically meaningful) never clash with chrome.
ThemeData buildTheme(Color seed, Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  // `fidelity` keeps the neutral tones faithful to the brand colour — which in dark
  // mode paints every surface with a tint of the seed, so Bogotá's red reads as a
  // dark "vinotinto". Keep the branded accents (primary/containers), but swap the
  // whole neutral family for true greys so the chrome is actually dark grey. This is
  // what the comment above always intended; `fidelity` was quietly overriding it.
  final scheme = brightness == Brightness.dark
      ? seeded.copyWith(
          surface: const Color(0xFF121212),
          onSurface: const Color(0xFFE7E7E7),
          surfaceDim: const Color(0xFF0C0C0C),
          surfaceBright: const Color(0xFF363636),
          surfaceContainerLowest: const Color(0xFF0C0C0C),
          surfaceContainerLow: const Color(0xFF191919),
          surfaceContainer: const Color(0xFF1E1E1E),
          surfaceContainerHigh: const Color(0xFF282828),
          surfaceContainerHighest: const Color(0xFF333333),
          onSurfaceVariant: const Color(0xFFC6C6C6),
          outline: const Color(0xFF8C8C8C),
          outlineVariant: const Color(0xFF3A3A3A),
          inverseSurface: const Color(0xFFE7E7E7),
          onInverseSurface: const Color(0xFF1A1A1A),
          surfaceTint: const Color(0xFF2A2A2A),
        )
      : seeded;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final radius = BorderRadius.circular(18);
  return base.copyWith(
    extensions: [SemanticColors.of(brightness)],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      labelStyle: base.textTheme.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
