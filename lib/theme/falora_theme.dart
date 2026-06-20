import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';



const faloraBg = Color(0xFF0A0612);

const faloraSurface = Color(0xFF141022);

const faloraCard = Color(0xFF1C1430);

const faloraAccent = Color(0xFF9B6DFF);

const faloraGold = Color(0xFFD4AF37);

const faloraNightBlue = Color(0xFF1A2A4A);

const faloraTextPrimary = Color(0xFFF3EBFF);

const faloraTextSecondary = Color(0xFFB8A8D0);



ThemeData faloraTheme() {

  return ThemeData(

    useMaterial3: true,

    brightness: Brightness.dark,

    scaffoldBackgroundColor: faloraBg,

    colorScheme: const ColorScheme.dark(

      primary: faloraAccent,

      secondary: faloraGold,

      surface: faloraSurface,

      onPrimary: Colors.white,

      onSurface: faloraTextPrimary,

    ),

    appBarTheme: AppBarTheme(

      backgroundColor: faloraBg.withValues(alpha: 0.92),

      foregroundColor: faloraTextPrimary,

      elevation: 0,

      centerTitle: true,

      scrolledUnderElevation: 0,

      titleTextStyle: const TextStyle(

        fontSize: 18,

        fontWeight: FontWeight.w600,

        color: faloraTextPrimary,

        letterSpacing: 0.3,

      ),

    ),

    cardTheme: CardThemeData(

      color: faloraCard.withValues(alpha: 0.85),

      elevation: 0,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),

    ),

    dividerTheme: DividerThemeData(

      color: Colors.white.withValues(alpha: 0.06),

      thickness: 1,

    ),

    inputDecorationTheme: InputDecorationTheme(

      filled: true,

      fillColor: faloraCard.withValues(alpha: 0.7),

      labelStyle: const TextStyle(color: faloraTextSecondary),

      hintStyle: const TextStyle(color: faloraTextSecondary),

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide.none,

      ),

      enabledBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),

      ),

      focusedBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: faloraAccent, width: 1.5),

      ),

    ),

    elevatedButtonTheme: ElevatedButtonThemeData(

      style: ElevatedButton.styleFrom(

        backgroundColor: faloraAccent,

        foregroundColor: Colors.white,

        elevation: 0,

        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

        textStyle: const TextStyle(fontWeight: FontWeight.w700),

      ),

    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(

      backgroundColor: faloraSurface.withValues(alpha: 0.95),

      selectedItemColor: faloraGold,

      unselectedItemColor: faloraTextSecondary,

      type: BottomNavigationBarType.fixed,

      elevation: 0,

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

      begin: Alignment.topLeft,

      end: Alignment.bottomRight,

      colors: [

        faloraBg,

        Color(0xFF15102A),

        Color(0xFF1A1035),

        faloraBg,

      ],

    ),

  );

}


