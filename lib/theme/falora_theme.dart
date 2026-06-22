import 'package:falora/theme/falora_design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

export 'falora_design_tokens.dart';

ThemeData faloraTheme() {
  const colorScheme = ColorScheme.light(
    primary: faloraBronze,
    onPrimary: faloraParchmentRaised,
    secondary: faloraGold,
    onSecondary: faloraInk,
    surface: faloraParchmentCard,
    onSurface: faloraInk,
    error: Color(0xFF8B3A3A),
    onError: faloraParchmentRaised,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: faloraParchmentMid,
    colorScheme: colorScheme,
    fontFamily: FaloraTypography.bodyFamily,
    textTheme: const TextTheme(
      displayLarge: FaloraTypography.displayLarge,
      displayMedium: FaloraTypography.displayMedium,
      titleLarge: FaloraTypography.titleLarge,
      titleMedium: FaloraTypography.titleMedium,
      bodyLarge: FaloraTypography.bodyLarge,
      bodyMedium: FaloraTypography.bodyMedium,
      labelLarge: FaloraTypography.labelLarge,
      labelSmall: FaloraTypography.labelSmall,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: faloraParchmentMid.withValues(alpha: 0.94),
      foregroundColor: faloraInk,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: FaloraTypography.titleLarge.copyWith(fontSize: 17),
      iconTheme: const IconThemeData(color: faloraBronzeDark),
    ),
    cardTheme: CardThemeData(
      color: faloraParchmentCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FaloraRadius.lg),
        side: const BorderSide(color: faloraGoldMuted, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: faloraBronze,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: faloraParchmentRaised,
      labelStyle: FaloraTypography.labelLarge,
      hintStyle: FaloraTypography.bodyMedium.copyWith(color: faloraInkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        borderSide: BorderSide(color: faloraBronze.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        borderSide: BorderSide(color: faloraBronze.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        borderSide: const BorderSide(color: faloraGoldDark, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: faloraBronzeDark,
        foregroundColor: faloraParchmentRaised,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FaloraRadius.md),
          side: const BorderSide(color: faloraGold, width: 1),
        ),
        textStyle: FaloraTypography.labelLarge.copyWith(
          color: faloraParchmentRaised,
          letterSpacing: 0.4,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: faloraBronzeDark,
        side: BorderSide(color: faloraBronze.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FaloraRadius.md),
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: faloraParchmentCard,
      selectedItemColor: faloraGoldDark,
      unselectedItemColor: faloraInkMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: faloraBronzeDark,
      contentTextStyle: FaloraTypography.bodyMedium.copyWith(
        color: faloraParchmentRaised,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FaloraRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

BoxDecoration faloraAuthBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        faloraParchmentLight,
        faloraParchmentMid,
        faloraParchmentDeep,
      ],
    ),
  );
}
