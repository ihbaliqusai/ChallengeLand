import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData darkArabicTheme() {
    const baseTextStyle = TextStyle(
      fontFamilyFallback: ['Cairo', 'Tajawal', 'Noto Kufi Arabic', 'Arial'],
      letterSpacing: 0,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.challengeDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.challengeBlue,
        brightness: Brightness.dark,
        primary: AppColors.challengeBlue,
        secondary: AppColors.challengeGold,
        error: AppColors.challengeRed,
        surface: AppColors.challengeCard,
      ),
      fontFamilyFallback: const [
        'Cairo',
        'Tajawal',
        'Noto Kufi Arabic',
        'Arial',
      ],
      textTheme:
          const TextTheme(
            displaySmall: baseTextStyle,
            headlineLarge: baseTextStyle,
            headlineMedium: baseTextStyle,
            headlineSmall: baseTextStyle,
            titleLarge: baseTextStyle,
            titleMedium: baseTextStyle,
            titleSmall: baseTextStyle,
            bodyLarge: baseTextStyle,
            bodyMedium: baseTextStyle,
            bodySmall: baseTextStyle,
            labelLarge: baseTextStyle,
            labelMedium: baseTextStyle,
            labelSmall: baseTextStyle,
          ).apply(
            bodyColor: AppColors.challengeLight,
            displayColor: AppColors.challengeLight,
          ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.challengeNavy,
        foregroundColor: AppColors.challengeLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.challengeCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.challengeCyan,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
