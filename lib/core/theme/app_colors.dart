/// Grocify 2.0 Color System
/// Minimalistisch, modern, beruhigend
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF6366F1); // Indigo - modern, vertrauenswürdig
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color onPrimary = Colors.white;

  // Secondary Colors
  static const Color secondary = Color(0xFF10B981); // Emerald - sparen, gesund
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryContainer = Color(0xFFECFDF5);
  static const Color onSecondary = Colors.white;

  // Accent Colors
  static const Color accent = Color(0xFFF59E0B); // Amber - Highlights, CTA
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentDark = Color(0xFFD97706);
  
  // Container Colors
  static const Color primaryContainer = Color(0xFFEEF2FF);

  // Background & Surface
  static const Color background = Color(0xFFFAFAFA); // Warmes Weiß
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color onBackground = Color(0xFF1F2937); // Dunkelgrau
  static const Color onSurface = Color(0xFF1F2937);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280); // Mittelgrau
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Border & Divider
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);

  // Overlay
  static const Color overlay = Color(0x80000000); // 50% black overlay

  // Saving Highlight (Gamification)
  static const Color savingHighlight = Color(0xFF10B981);
  static const Color savingBackground = Color(0xFFECFDF5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient savingGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceVariant],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

