/// Grocify 2.0 Typography System
/// Inter Font Family, klare Hierarchie
import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Font Family
  static const String fontFamily = 'Inter';

  // Display (Hero Text)
  static TextStyle displayLarge(BuildContext context) {
    return Theme.of(context).textTheme.displayLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -0.5,
          height: 1.2,
        ) ??
        const TextStyle();
  }

  // Headline (Screen Titles)
  static TextStyle headlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 24,
          letterSpacing: -0.25,
          height: 1.3,
        ) ??
        const TextStyle();
  }

  static TextStyle headlineMedium(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0,
          height: 1.4,
        ) ??
        const TextStyle();
  }

  // Title (Card Titles, Section Headers)
  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: 0,
          height: 1.4,
        ) ??
        const TextStyle();
  }

  static TextStyle titleMedium(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.15,
          height: 1.5,
        ) ??
        const TextStyle();
  }

  static TextStyle titleSmall(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
          height: 1.5,
        ) ??
        const TextStyle();
  }

  // Body (Main Text)
  static TextStyle bodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          letterSpacing: 0.15,
          height: 1.5,
        ) ??
        const TextStyle();
  }

  static TextStyle bodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          letterSpacing: 0.25,
          height: 1.5,
        ) ??
        const TextStyle();
  }

  static TextStyle bodySmall(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          letterSpacing: 0.4,
          height: 1.5,
        ) ??
        const TextStyle();
  }

  // Label (Buttons, Labels)
  static TextStyle labelLarge(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
          height: 1.4,
        ) ??
        const TextStyle();
  }

  static TextStyle labelMedium(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.5,
          height: 1.4,
        ) ??
        const TextStyle();
  }

  static TextStyle labelSmall(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.5,
          height: 1.4,
        ) ??
        const TextStyle();
  }
}

