import 'package:flutter/material.dart';

/// Semantic color tokens aligned with the approved Qat-Link specification.
abstract final class AppColors {
  static const Color ink = Color(0xFF172B30);
  static const Color inkSoft = Color(0xFF35545A);

  // Approved brand palette.
  static const Color emerald = Color(0xFF176B70); // Petrol
  static const Color emeraldBright = Color(0xFF64C0AB); // Mint
  static const Color mint = Color(0xFFDDF3ED);
  static const Color info = Color(0xFF55AFC4); // Cyan

  static const Color canvas = Color(0xFFF1F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFDCE8E9);
  static const Color muted = Color(0xFF64777B);
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFC04444);

  static const Color darkCanvas = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF182235);
  static const Color darkSurfaceElevated = Color(0xFF223047);
  static const Color darkOutline = Color(0xFF3A4A60);
  static const Color darkText = Color(0xFFEAF1F5);
  static const Color darkMuted = Color(0xFFA4B3C2);
}
