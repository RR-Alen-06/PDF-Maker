import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Brand Accents (Neon Kinetic Design System)
  static const Color primary = Color(0xFFFF2E97); // Electric Pink / Neon Magenta
  static const Color primaryLight = Color(0xFFFF65B2);
  static const Color primaryDark = Color(0xFFC70068);
  static const Color primaryContainer = Color(0xFF3D0823);

  static const Color secondary = Color(0xFF00F3FF); // Neon Cyan
  static const Color secondaryLight = Color(0xFF6EFAFF);
  static const Color secondaryDark = Color(0xFF00A2AA);
  static const Color secondaryContainer = Color(0xFF002B2E);

  static const Color tertiary = Color(0xFFFFB800); // Neon Amber
  static const Color tertiaryLight = Color(0xFFFFD56B);
  static const Color tertiaryDark = Color(0xFFC48B00);
  static const Color tertiaryContainer = Color(0xFF382800);

  static const Color neonEmerald = Color(0xFF00F5D4);
  static const Color neonViolet = Color(0xFF8C52FF);
  static const Color neonCobalt = Color(0xFF3B82F6);
  static const Color neonRose = Color(0xFFFF4D94);
  static const Color neonOrange = Color(0xFFFF7A00);

  static const Color error = Color(0xFFFF4D6D);
  static const Color success = Color(0xFF00F5D4);
  static const Color warning = Color(0xFFFFB800);

  // Neutral - Dark Theme (Deep Cyberpunk Violet)
  static const Color backgroundDark = Color(0xFF0E0720);
  static const Color surfaceDark = Color(0xFF160C30);
  static const Color surfaceContainerDark = Color(0xFF1E1240);
  static const Color surfaceElevatedDark = Color(0xFF281954);
  static const Color textPrimaryDark = Color(0xFFF6F3FF);
  static const Color textSecondaryDark = Color(0xFFA59BC2);
  static const Color textMutedDark = Color(0xFF736792);
  static const Color borderDark = Color(0xFF352562);
  static const Color borderGlowDark = Color(0xFF5A419C);

  // Neutral - Light Theme (Vibrant Crisp Lavender Surface)
  static const Color backgroundLight = Color(0xFFF7F5FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFF0ECFA);
  static const Color surfaceElevatedLight = Color(0xFFE6DEFA);
  static const Color textPrimaryLight = Color(0xFF14082E);
  static const Color textSecondaryLight = Color(0xFF5C5278);
  static const Color textMutedLight = Color(0xFF8F85AC);
  static const Color borderLight = Color(0xFFE4DCF5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2E97), Color(0xFF8C52FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF7928CA), Color(0xFFFF0080), Color(0xFFFF6584)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanVioletGradient = LinearGradient(
    colors: [Color(0xFF00F3FF), Color(0xFF8C52FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkOrangeGradient = LinearGradient(
    colors: [Color(0xFFFF2E97), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberOrangeGradient = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF5400)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldCyanGradient = LinearGradient(
    colors: [Color(0xFF00F5D4), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetIndigoGradient = LinearGradient(
    colors: [Color(0xFF8C52FF), Color(0xFF4C1D95)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardBorderGradient = LinearGradient(
    colors: [Color(0x8000F3FF), Color(0x80FF2E97), Color(0x308C52FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Neon Shadows
  static List<BoxShadow> neonGlow(Color color, {double opacity = 0.35, double blur = 16, double spread = 0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: spread,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
