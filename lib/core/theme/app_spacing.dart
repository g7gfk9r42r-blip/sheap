/// Grocify 2.0 Spacing System
/// Konsistente Abstände für großzügiges Layout
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 48.0;

  // Common Padding Values
  static const double paddingXS = xs;
  static const double paddingSM = sm;
  static const double paddingMD = md;
  static const double paddingLG = lg;
  static const double paddingXL = xl;
  static const double paddingXXL = xxl;
  static const double paddingXXXL = xxxl;

  // Screen Padding (großzügig)
  static const double screenPadding = xl; // 20px
  static const double screenPaddingLarge = xxl; // 24px
  static const double screenPaddingXL = xxxl; // 32px

  // Card Padding
  static const double cardPadding = lg; // 16px
  static const double cardPaddingLarge = xl; // 20px

  // Component Spacing
  static const double componentSpacing = md; // 12px
  static const double componentSpacingLarge = lg; // 16px
  static const double sectionSpacing = xxl; // 24px
  static const double sectionSpacingLarge = xxxl; // 32px
}

/// Border Radius System
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Common Border Radius
  static const double button = md;
  static const double card = xl;
  static const double chip = lg;
  static const double input = md;
  static const double image = xl;
}

