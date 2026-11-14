import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const String display = 'Fraunces';
  static const String body = 'Poppins';
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.mustard,
      tertiary: AppColors.sage,
      surface: AppColors.cream,
      error: AppColors.coral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: AppFonts.body,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
          height: 1.05,
        ),
        headlineLarge: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          color: AppColors.ink,
          height: 1.1,
        ),
        headlineSmall: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          color: AppColors.teal,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.slate,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.slate,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.teal,
        selectionColor: AppColors.butter,
        selectionHandleColor: AppColors.teal,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
