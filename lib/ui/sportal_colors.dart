import 'package:flutter/material.dart';

class SportalColors {
  const SportalColors._();

  // Brand
  static const Color primaryBlue = Color(0xFF1A8CF3);
  static const Color accentCyan = Color(0xFF35B6FF);
  static const Color deepBlue = Color(0xFF0F1A43);

  // Surfaces (refined navy palette — modern, less saturated than old deep navy).
  static const Color surface = Color(0xFF1A2349); // Card bodies
  static const Color surfaceMuted = Color(0xFF252F58); // Inputs / muted rows
  static const Color surfaceElevated = Color(0xFF2C3B6E); // Hover / elevated

  // Bottom nav and chrome background (one shade darker than surface).
  static const Color navBackground = Color(0xFF0F1838);

  // Dialog background — deep navy that blends with the surface palette.
  static const Color dialogBackground = Color(0xFF152352);

  // Legacy alias (kept for backwards compat).
  static const Color fieldBackground = surface;

  // Text
  static const Color textPrimary = Color(0xFFF8F9FF);
  static const Color textSecondary = Color(0xFF9EA4BA);

  // States
  static const Color disabledButton = Color(0xFF939AB3);
  static const Color errorRed = Color(0xFFD92D3A);
  static const Color likeRed = Color(0xFFFF5B7E);
  static const Color liveRed = Color(0xFFDC2626);

  // Mode badge accents
  static const Color obsAmber = Color(0xFFFF9F1A);
}
