import 'package:flutter/material.dart';

/// Movder Cinematic Date renk tokenları.
abstract final class AppColors {
  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF1A1A1A);

  static const Color primary = Color(0xFFFF4D6D);
  static const Color secondary = Color(0xFF5CE1E6);
  static const Color tertiary = Color(0xFF9B8CFF);

  static const Color success = Color(0xFF2EE59D);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFFF6B6B);

  static const Color textHigh = Color(0xFFF5F5F5);
  static const Color textMedium = Color(0xFFB3B3B3);

  static const Color divider = Color(0x33F5F5F5);
  static const Color overlay = Color(0x99000000);

  // Mikro varyant: romantik
  static const Color primaryRomantic = Color(0xFFFF6F87);
  static const Color secondaryRomantic = Color(0xFF7CE7EB);
  static const Color tertiaryRomantic = Color(0xFFB39CFF);

  // Mikro varyant: daha sinematik
  static const Color primaryCinematic = Color(0xFFFF3B61);
  static const Color secondaryCinematic = Color(0xFF4FD3D9);
  static const Color tertiaryCinematic = Color(0xFF7D6CFF);
}
