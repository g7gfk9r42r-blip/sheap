/// Home Screen Color Palette
/// Warm, playful colors inspired by modern wellness apps
import 'package:flutter/material.dart';

class HomeColors {
  HomeColors._();

  // === Primary Colors - Warm Apricot/Peach ===
  static const Color primary = Color(0xFFFF8A65); // Warm Apricot
  static const Color primaryLight = Color(0xFFFFAB91);
  static const Color primaryDark = Color(0xFFFF6F43);
  
  // === Secondary - Soft Mint ===
  static const Color secondary = Color(0xFF80CBC4); // Soft Mint
  static const Color secondaryLight = Color(0xFFB2DFDB);
  static const Color secondaryDark = Color(0xFF4DB6AC);
  
  // === Accent - Warm Coral ===
  static const Color accent = Color(0xFFFF7043);
  static const Color accentLight = Color(0xFFFFAB91);
  
  // === Success - Fresh Green ===
  static const Color success = Color(0xFF66BB6A);
  static const Color successLight = Color(0xFF81C784);
  
  // === Backgrounds - Creamy Whites ===
  static const Color background = Color(0xFFFFFBF7); // Warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFFFF8F3);
  static const Color surfaceElevated = Color(0xFFFFFEFB);
  
  // === Text ===
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9E9E9E);
  
  // === Borders ===
  static const Color border = Color(0xFFE8E8E8);
  static const Color divider = Color(0xFFF5F5F5);
  
  // === Gradients ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFE0B2), Color(0xFFFFCCBC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

