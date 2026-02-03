/// Grocify Premium Theme System
/// Inspired by Revolut, TooGoodToGo, Flink, Notion, Duolingo
/// Clean, minimal, young, friendly with warm accents

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GrocifyTheme {
  GrocifyTheme._();

  // === Color Palette ===
  // Nike/Yazio-inspired: Fresh, healthy, modern food app aesthetic
  // Primary: Warm green (Figma Design - accent color)
  static const Color primary = Color(0xFF2F7C67); // Warm green (accent)
  static const Color primaryLight = Color(0xFF4A9B82);
  static const Color primaryDark = Color(0xFF1F5A4A);
  
  // Accent primary (for compatibility)
  static const Color accentPrimary = Color(0xFF2F7C67);
  
  // Success/Savings: Soft emerald (complementary to primary)
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  
  // Secondary accent: Soft yellow/orange (YAZIO-style)
  static const Color accent = Color(0xFFFFC857); // Soft yellow/orange (YAZIO-style)
  static const Color accentLight = Color(0xFFFFAB91);
  
  // Backgrounds: Off-White / Beige (Figma Design)
  static const Color background = Color(0xFFF5F3EE); // Off-White / Beige
  static const Color surface = Colors.white; // Card background
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF3F3F1); // Very light beige/gray for badges
  
  // Text: High contrast, readable
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  
  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  
  // Error & Warning
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFF9800);
  
  // Special colors for icons
  static const Color streakOrange = Color(0xFFFF7043); // Orange for streak/flame
  static const Color savingsPink = Color(0xFFFF6FA5); // Pink for savings/piggy bank
  
  // === DARK MODE COLORS ===
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceElevated = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFE5E5E5);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkBorder = Color(0xFF2C2C2C);
  static const Color darkDivider = Color(0xFF1E1E1E);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceSubtle],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // === Spacing System ===
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 20.0;
  static const double spaceXXL = 24.0;
  static const double spaceXXXL = 32.0;
  static const double spaceXXXXL = 48.0;
  
  // Screen padding
  static const double screenPadding = 20.0;
  static const double screenPaddingLarge = 24.0;
  
  // === Border Radius ===
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusRound = 999.0;
  
  // === Shadows ===
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  // === Animation Durations ===
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // === Curves ===
  static const Curve animationCurve = Curves.easeOutCubic;

  // === Dark Theme ===
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: success,
      onSecondary: Colors.white,
      tertiary: accent,
      onTertiary: textPrimary,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceElevated,
      error: error,
      onError: Colors.white,
      outline: darkBorder,
      outlineVariant: darkDivider,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
      
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: darkTextPrimary,
          size: 24,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLG),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
          color: darkTextSecondary,
          fontSize: 15,
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceElevated,
        selectedColor: primary.withOpacity(0.2),
        side: BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        labelStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      dividerTheme: DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      
      iconTheme: IconThemeData(
        color: darkTextPrimary,
        size: 24,
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: success,
      onSecondary: Colors.white,
      tertiary: accent,
      onTertiary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      error: error,
      onError: Colors.white,
      outline: border,
      outlineVariant: divider,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      brightness: Brightness.light,
    );

    return base.copyWith(
      // Typography: Modern, readable, friendly
      textTheme: _buildTextTheme(base.textTheme),
      
      // AppBar: Clean, minimal
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // Cards: Soft shadows, rounded corners
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          side: BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Buttons: Premium, rounded, with gradients
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLG),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLG),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Fields: Clean, rounded
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: 15,
        ),
      ),
      
      // Bottom Navigation: Modern, clean
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: surfaceSubtle,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              height: 1.2,
            );
          }
          return TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11.5,
            height: 1.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
        height: 76,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      
      // Chips: Rounded, soft
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSubtle,
        selectedColor: primary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusRound),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
      ),
      
      // Dividers: Subtle
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      
      // Splash: Subtle
      splashFactory: InkRipple.splashFactory,
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.2,
        color: textPrimary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: textPrimary,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.3,
        color: textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.3,
        color: textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.4,
        color: textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
        color: textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.5,
        color: textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: textPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
        color: textSecondary,
      ),
    );
  }
}

