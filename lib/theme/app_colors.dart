import 'package:flutter/material.dart';

/// Semantic color tokens for the Qat-Link visual system.
///
/// Components should consume these tokens through [ColorScheme] or
/// [AppColors], rather than hard-coding colors in individual screens.
abstract final class AppColors {
  static const Color ink = Color(0xFF17232D);
  static const Color inkSoft = Color(0xFF334653);
  static const Color emerald = Color(0xFF087E70);
  static const Color emeraldBright = Color(0xFF16A58F);
  static const Color mint = Color(0xFFDDF4EC);
  static const Color canvas = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFE1E8E5);
  static const Color muted = Color(0xFF71817B);
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFC04444);
  static const Color info = Color(0xFF3478A5);

  static const Color darkCanvas = Color(0xFF101A20);
  static const Color darkSurface = Color(0xFF19262E);
  static const Color darkSurfaceElevated = Color(0xFF22323B);
  static const Color darkOutline = Color(0xFF34464F);
  static const Color darkText = Color(0xFFEAF1EE);
  static const Color darkMuted = Color(0xFFA4B3AD);
}
