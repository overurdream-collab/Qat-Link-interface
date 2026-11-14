import 'package:flutter/material.dart';

/// Exact palette extracted from the user-supplied Telecom Dashboard HTML.
/// Do not change the hex values without approving a new design reference.
abstract final class AppColors {
  // Source CSS variables.
  static const Color blue = Color(0xFF3A70D2);
  static const Color blueLight = Color(0xFF497CD7);
  static const Color blueMid = Color(0xFF5A94DD);
  static const Color sky = Color(0xFF7FBDEC);
  static const Color cyan = Color(0xFFA4E6F2);
  static const Color mint = Color(0xFFB0E9DA);
  static const Color green = Color(0xFFCDEABE);
  static const Color lime = Color(0xFFD5ECA6);
  static const Color iconGreen = Color(0xFFA5E8A1);
  static const Color button = Color(0xFF3868C8);
  static const Color navy = Color(0xFF0A0D3B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color section = Color(0xFFF6F6F6);
  static const Color background = Color(0xFFE5E8ED);
  static const Color muted = Color(0xFF9DA5B8);
  static const Color redBackground = Color(0xFFF8D9DD);

  // Additional gradient stops appearing verbatim in the supplied HTML.
  static const Color gradientSky = Color(0xFF76B7E7);
  static const Color gradientMint = Color(0xFFA4DCCE);
  static const Color middleBlue = Color(0xFF5189DD);
  static const Color middleSky = Color(0xFF89D0EC);
  static const Color ringLime = Color(0xFFDAEC9B);
  static const Color ringMint = Color(0xFFB8EDA8);
  static const Color ringTeal = Color(0xFF8FE0D4);
  static const Color ringSky = Color(0xFF7EBDEA);
  static const Color ringBlue = Color(0xFF6B9FE4);

  // Semantic colors are deliberately separate from the decorative palette.
  // Financial meaning must never be conveyed by color alone.
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFC04444);
  static const Color ink = navy;
  static const Color inkSoft = Color(0xFF53617C); // contrast-safe secondary text
  static const Color canvas = section;
  static const Color outline = background;
  static const Color info = blue;

  // Existing dark theme remains supported, with blue brand accents.
  static const Color darkCanvas = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF182235);
  static const Color darkSurfaceElevated = Color(0xFF223047);
  static const Color darkOutline = Color(0xFF3A4A60);
  static const Color darkText = Color(0xFFEAF1F5);
  static const Color darkMuted = Color(0xFFA4B3C2);
}

/// Source-matched gradients shared across the app.
abstract final class AppGradients {
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.03, 0.45, 0.80, 1.0],
    colors: [
      AppColors.blueLight,
      AppColors.gradientSky,
      AppColors.gradientMint,
      AppColors.green,
    ],
  );

  static const LinearGradient balance = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.52, 1.0],
    colors: [
      AppColors.blue,
      AppColors.middleBlue,
      AppColors.middleSky,
    ],
  );
}
