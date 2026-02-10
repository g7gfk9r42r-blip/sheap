# 📸 App Store & Google Play Store Screenshots Guide

**Status**: Screenshot strategy & automation guide  
**Target**: iOS App Store + Google Play Store listings  
**Audience**: Marketing team / app launch

---

## Screenshot Requirements by Store

### iOS App Store

| Requirement | Specification |
|---|---|
| **Resolution** | **1284 × 2778 px** (iPhone 6,5" - 14/15 Pro Max) oder 2778 × 1284 px (Querformat) |
| **Alternative** | 1242 × 2688 px oder 2688 × 1242 px (Querformat) |
| **Format** | PNG oder JPEG |
| **Count** | bis zu 10 Screenshots (empfohlen 5–10) |
| **Device** | iPhone mit 6,5" Display (Pro Max Modelle) |
| **Content** | Echte App-Bildschirme (keine Mockups) |
| **Text** | Klar lesbar, App-Features hervorgehoben |
| **Sprache** | German |

### Google Play Store

| Requirement | Specification |
|---|---|
| **Resolution** | 1080 × 1920 px (Pixel / standard Android) |
| **Format** | PNG or JPEG |
| **Count** | 2–8 screenshots (recommended 5–8) |
| **Device** | Android phone (Pixel preferred) |
| **Content** | Real app screens |
| **Text** | Feature descriptions with simple graphics |
| **Language** | German |

---

## Screenshot Sequence (Recommended)

### Screen 1: App Welcome / Onboarding
**Purpose**: First impression, hook the user  
**Content**: 
- Onboarding popup visible
- Show app name "sheap" or "Grocify"
- Brief feature: "Wöchentlich neue Rezepte"

**Headline**: "Wöchentlich neue Rezepte & Angebote"

---

### Screen 2: Discover Page (Hero Shot)
**Purpose**: Main feature - recipe discovery  
**Content**:
- Recipe cards visible
- Mix of different recipes (pasta, salad, meat)
- Images loaded correctly
- Price tags visible

**Headline**: "Rezepte basierend auf Wochenangeboten"

---

### Screen 3: Recipe Detail
**Purpose**: Show recipe interaction & details  
**Content**:
- Recipe title visible
- Ingredients list
- Instructions visible
- Store offers (LIDL/EDEKA)
- Price comparison

**Headline**: "Schritt-für-Schritt Anleitungen"

---

### Screen 4: Grocery Offers
**Purpose**: Show the offer/discount feature  
**Content**:
- List of current offers
- Prices from different stores
- Store logos (LIDL, EDEKA, etc.)

**Headline**: "Aktuelle Angebote vergleichen"

---

### Screen 5: Shopping / Favorites
**Purpose**: Utility feature - organize shopping  
**Content**:
- Saved recipes
- Shopping list
- Checkboxes marked

**Headline**: "Einkaufsliste zum Abhaken"

---

## How to Take Screenshots

### Option 1: iOS Simulator (Recommended for iOS)

```bash
# 1. Open simulator
xcrun simctl list devices

# 2. Launch app
flutter run -d <DEVICE_ID>

# 3. Navigate to desired screen
# (manually tap through the app)

# 4. Screenshot via Xcode
# Menu: Simulator → Device → Screenshot
# OR: Keyboard: Cmd + S

# 5. Screenshots saved to Desktop automatically
ls ~/Desktop/Simulator* | head -20
```

**Best Simulator for Screenshots**: iPhone 15 Pro (2532x1170)
```bash
xcrun simctl create "iPhone 15 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro com.apple.CoreSimulator.SimRuntime.iOS-17-4
```

### Option 2: Android Emulator (For Google Play)

```bash
# 1. Launch emulator
emulator -avd Pixel_7_Pro

# 2. Run app
flutter run -d emulator-5554

# 3. Screenshot via adb
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png ~/Desktop/

# 4. Crop to 1080x1920 if needed
```

### Option 3: Real Device

```bash
# iOS (real iPhone)
# Press: Side button + Volume Up simultaneously
# Or: Control Center → Screenshot

# Android (real phone)
# Press: Power + Volume Down
# Or: Pull down notification shade → Screenshot
```

---

## Screenshot Automation Script

Create a Dart script to automate navigation & screenshot:

**File**: `tools/take_screenshots.dart`

```dart
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('Take screenshots for App Store', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Screenshot 1: Onboarding
      await tester.takeScreenshot('01_onboarding');
      
      // Tap "Loslegen"
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Screenshot 2: Discover
      await tester.takeScreenshot('02_discover_page');

      // Scroll down
      await tester.scroll(
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.takeScreenshot('02b_discover_page_scrolled');

      // Tap first recipe
      await tester.tap(find.byType(RecipeCard).first);
      await tester.pumpAndSettle();

      // Screenshot 3: Recipe Detail
      await tester.takeScreenshot('03_recipe_detail');

      // Scroll ingredients
      await tester.scroll(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.takeScreenshot('03b_recipe_ingredients');

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate to Offers tab
      await tester.tap(find.byIcon(Icons.local_offer));
      await tester.pumpAndSettle();

      // Screenshot 4: Offers
      await tester.takeScreenshot('04_offers_page');

      // Navigate to Favorites
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      // Screenshot 5: Favorites
      await tester.takeScreenshot('05_favorites_page');
    });
  });
}
```

**Run it**:
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=tools/take_screenshots.dart
```

Screenshots saved to: `build/integration_test_screenshots/`

---

## Manual Screenshot Workflow (Quick)

### For iOS (Fastest)

```bash
# 1. Launch simulator
flutter run -d "iPhone 15 Pro"

# 2. Wait for app to boot
# 3. Manually tap through screens
# 4. Take screenshot: Cmd + S for each screen
# 5. Screenshots auto-save to ~/Desktop
# 6. Crop if needed (shouldn't be)
# 7. Rename: 01_onboarding.png, 02_discover.png, etc.
```

### For Android (Fastest)

```bash
# 1. Launch emulator
emulator -avd Pixel_7_Pro &
flutter run

# 2. Tap through screens manually
# 3. Screenshot: adb shell screencap -p /sdcard/shot$i.png
#    OR: Use emulator UI button (camera icon)
# 4. Pull files: adb pull /sdcard/shot*.png ~/Desktop/
```

---

## Screenshot Content Checklist

### Screen 1: Onboarding/Welcome
- [ ] App logo or name visible
- [ ] Main feature headline: "Wöchentlich neue Rezepte"
- [ ] Onboarding popup showing
- [ ] "Loslegen" button visible
- [ ] Clean background

### Screen 2: Discover Page (Main Content)
- [ ] At least 2-3 recipe cards visible
- [ ] Images loaded correctly (no placeholder)
- [ ] Recipe titles readable
- [ ] Price/offer badge visible
- [ ] Clean layout, no overlays

### Screen 3: Recipe Detail
- [ ] Recipe title clear
- [ ] Hero image prominent
- [ ] Ingredients list visible
- [ ] At least 1 instruction step visible
- [ ] Store offer/price visible

### Screen 4: Offers / Grocery Deals
- [ ] Store logos (LIDL, EDEKA, etc.) visible
- [ ] Product images visible
- [ ] Prices prominent
- [ ] Clean layout

### Screen 5: Favorites / Shopping List
- [ ] Saved items showing
- [ ] Checkboxes available
- [ ] Clear list structure
- [ ] Empty state message if no items

---

## Text Overlay for App Stores

### iOS App Store - Recommended Text

```
Screenshot 1 (Onboarding):
"Wöchentlich neue Rezepte basierend auf Angeboten"

Screenshot 2 (Discover):
"Entdecke 50+ Rezepte pro Woche"

Screenshot 3 (Recipe):
"Schritt-für-Schritt Anleitung mit Zutaten"

Screenshot 4 (Offers):
"Angebote von LIDL, EDEKA & Co. vergleichen"

Screenshot 5 (Favorites):
"Einkaufsliste zum Abhaken"
```

### Google Play - Recommended Text

```
Screenshot 1:
"Kostenlos: 50+ neue Rezepte wöchentlich"

Screenshot 2:
"Nach Supermarkt-Angeboten dieser Woche"

Screenshot 3:
"Mit gekoppelten Rezeptanleitungen"

Screenshot 4:
"Aktuelle Angebote von LIDL, EDEKA & Co."

Screenshot 5:
"Intelligente Einkaufsliste"
```

**Note**: You can add text overlays in:
- **iOS**: Use App Store Connect UI (add text per screenshot)
- **Android**: Use Google Play Console UI (add text per screenshot)
- **Post-production**: Use Photoshop, Figma, or online tool

---

## Tools for Screenshot Editing

### Quick Online Tools (No Installation)
- **Figma** (free tier)
- **Photoshop Express** (web)
- **Pixlr** (web editor)
- **Canva Pro** (templates + text)

### Mac Software
- **Pixelmator Pro** (Mac App Store)
- **Affinity Photo** (low cost)
- **Adobe Photoshop** (expensive)
- **Preview.app** (built-in, limited)

### Free Command Line
```bash
# Using ImageMagick (brew install imagemagick)

# Add text to screenshot
convert screenshot.png \
  -gravity south -pointsize 48 \
  -fill white -annotate +0+50 "Wöchentlich neue Rezepte" \
  screenshot_with_text.png

# Batch resize
for img in *.png; do
  convert "$img" -resize 1170x2532 "resized_$img"
done
```

---

## Screenshots Size & Export Checklist

### iOS App Store

```bash
# 1170 × 2532 px (iPhone 15 Pro size)

# Verify size
identify screenshot.png
# Output: screenshot.png PNG 1170x2532 ...

# Export as JPEG (smaller file)
convert screenshot.png -quality 85 screenshot.jpg
ls -lh screenshot.jpg  # Should be ~300-500KB each
```

### Google Play Store

```bash
# 1080 × 1920 px (Pixel size)

# Verify size
identify screenshot.png
# Output: screenshot.png PNG 1080x1920 ...

# Export
convert screenshot.png -quality 85 screenshot.jpg
```

---

## Final Submission Checklist

### iOS App Store Connect

- [ ] 5-10 screenshots uploaded
- [ ] All 1170 × 2532 px
- [ ] All PNG or JPEG format
- [ ] Text overlays applied (or use App Store UI)
- [ ] No profanity or trademarks
- [ ] Consistent branding across screenshots
- [ ] Screenshots match app version
- [ ] German language selected

**Upload in**: App Store Connect → Your App → Version Release → Screenshots

### Google Play Store

- [ ] 5-8 screenshots uploaded
- [ ] All 1080 × 1920 px
- [ ] All PNG or JPEG format
- [ ] Text overlays applied
- [ ] Store logos visible (LIDL, EDEKA, etc.)
- [ ] Consistent style
- [ ] German language selected

**Upload in**: Google Play Console → Your App → Store Listing → Screenshots

---

## Quick Start Script (Mac)

Save as `scripts/prepare_screenshots.sh`:

```bash
#!/bin/bash

# Create screenshots directory
mkdir -p screenshots/ios screenshots/android

# Launch simulator
echo "🍎 Launching iOS simulator..."
xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
open -a Simulator

# Wait for simulator to boot
sleep 3

# Launch app
echo "📱 Running app on simulator..."
flutter run -d "iPhone 15 Pro" &
sleep 8

# Instructions for user
echo "
📸 Screenshot Time!
==================

Navigate through the app:
1. Tap 'Loslegen' for onboarding
2. Take screenshot (Cmd+S)
3. Name it: 01_onboarding.png
4. Navigate to Discover page
5. Screenshot again: 02_discover.png
6. Tap recipe → 03_recipe_detail.png
7. Go back → Offers tab → 04_offers.png
8. Favorites tab → 05_favorites.png

Screenshots auto-save to ~/Desktop/

Move them to:
  - iOS: screenshots/ios/
  - Android: screenshots/android/

Then run:
  bash scripts/optimize_screenshots.sh
"

# Keep app running
wait
```

**Run it**:
```bash
bash scripts/prepare_screenshots.sh
```

---

## Summary: Next Steps

1. **Take screenshots manually**:
   - iOS: `Cmd+S` on simulator
   - Android: adb or emulator button

2. **Resize/optimize**:
   - iOS: 1170 × 2532 px
   - Android: 1080 × 1920 px

3. **Add text overlays** (optional):
   - Use App Store Connect UI
   - Or: Photoshop/Figma/Canva

4. **Upload to stores**:
   - iOS: App Store Connect → Screenshots
   - Android: Google Play Console → Screenshots

5. **Submit for review**

---

**Estimated Time**: 30 minutes (screenshot capture) + 30 minutes (editing) = 1 hour total

**Recommended**: Have 5-10 high-quality screenshots ready before submitting to App Store / Play Store.
