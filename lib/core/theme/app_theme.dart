import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

enum AppThemeVariant {
  cinematic,
  romantic,
  cinematicDeep,
}

abstract final class AppTheme {
  static ThemeData get dark => theme(AppThemeVariant.cinematic);

  static ThemeData theme(AppThemeVariant variant) {
    final primary = _primaryFor(variant);
    final secondary = _secondaryFor(variant);
    final tertiary = _tertiaryFor(variant);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: AppColors.textHigh,
      secondary: secondary,
      onSecondary: AppColors.background,
      tertiary: tertiary,
      onTertiary: AppColors.textHigh,
      error: AppColors.error,
      onError: AppColors.textHigh,
      surface: AppColors.surface,
      onSurface: AppColors.textHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: primary,
      colorScheme: colorScheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(color: AppColors.textHigh),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textHigh,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textHigh,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textHigh,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textMedium,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.textMedium,
          height: 1.3,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.textMedium,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMedium.withValues(alpha: 0.25);
            }
            if (states.contains(WidgetState.pressed)) {
              return primary.withValues(alpha: 0.85);
            }
            return primary;
          }),
          foregroundColor:
              const WidgetStatePropertyAll<Color>(AppColors.textHigh),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.textHigh.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: AppColors.textMedium.withValues(alpha: 0.35),
              );
            }
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: secondary.withValues(alpha: 0.9));
            }
            return BorderSide(color: secondary);
          }),
          foregroundColor:
              const WidgetStatePropertyAll<Color>(AppColors.textHigh),
        ),
      ),
    );
  }

  static Color _primaryFor(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.romantic:
        return AppColors.primaryRomantic;
      case AppThemeVariant.cinematicDeep:
        return AppColors.primaryCinematic;
      case AppThemeVariant.cinematic:
        return AppColors.primary;
    }
  }

  static Color _secondaryFor(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.romantic:
        return AppColors.secondaryRomantic;
      case AppThemeVariant.cinematicDeep:
        return AppColors.secondaryCinematic;
      case AppThemeVariant.cinematic:
        return AppColors.secondary;
    }
  }

  static Color _tertiaryFor(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.romantic:
        return AppColors.tertiaryRomantic;
      case AppThemeVariant.cinematicDeep:
        return AppColors.tertiaryCinematic;
      case AppThemeVariant.cinematic:
        return AppColors.tertiary;
    }
  }
}
